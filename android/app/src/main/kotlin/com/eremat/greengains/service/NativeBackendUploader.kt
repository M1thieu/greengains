package com.eremat.greengains.service

import com.eremat.greengains.models.AccelData
import com.eremat.greengains.models.GyroData
import com.eremat.greengains.models.LocationData
import com.eremat.greengains.models.MagneticData
import com.eremat.greengains.models.MotionState
import com.eremat.greengains.models.NativeUploadEventType
import com.eremat.greengains.models.NativeUploadStatusEvent
import com.eremat.greengains.models.NativeUploadStatusListener
import com.eremat.greengains.models.OrientationState
import com.eremat.greengains.models.PocketState
import com.eremat.greengains.models.QualityMetadata
import com.eremat.greengains.models.SensorReading
import com.eremat.greengains.util.AppPrefs
import com.eremat.greengains.util.AppLogger
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.net.wifi.WifiManager
import android.os.SystemClock
import android.util.Log
import ch.hsr.geohash.GeoHash
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.GZIPOutputStream

/**
 * Native Backend Uploader — runs independently of Flutter.
 *
 * Reliability guarantees (aligned with Telegraf/Safecast patterns):
 *
 *  1. Idempotent batches — each batch carries a stable UUID ([PendingBatch.batchId])
 *     frozen at creation. Retries reuse the same ID + timestamp so the server's
 *     ON CONFLICT deduplication works correctly (no duplicate rows on retry).
 *
 *  2. Exponential backoff — failures schedule retry at 30s → 1m → 2m → 4m → 8m,
 *     capped at 30m. Prevents hammering a temporarily unavailable server.
 *
 *  3. Store and forward (as owntracks keeps its outgoing queue): a batch the server
 *     has not accepted stays queued, on disk, through any outage. Only a batch the
 *     server rejects as invalid (400/413/422) is dropped; transient failures (network,
 *     5xx, a missing deployment's 404) are retried with capped backoff, never counted out.
 *
 *  4. Batch age limit — [MAX_BATCH_AGE_MS] is the server's own limit (30 days, the
 *     upload schema's "Timestamp too old" rule): an older batch can never be accepted.
 *
 *  5. Gzip compression — payloads are compressed before transmission, typically
 *     saving 60–70% of bandwidth. The server's decompressPayload() handles this.
 *
 *  6. Battery context — battery level + charging state are included in every upload
 *     so the backend can weight data quality (low-battery devices often move less).
 */
class NativeBackendUploader(
    private val context: Context,
    private val uploadIntervalMs: Long = 300_000L, // 5 min — reduces backend costs by 60%
    private val batteryMonitor: BatteryStateMonitor? = null,
    private val networkMonitor: NetworkStateMonitor? = null,
    private val statusListener: NativeUploadStatusListener? = null,
    // Held for the duration of each upload attempt so aggressive OEMs (Xiaomi, Samsung, Huawei)
    // don't suspend the CPU mid-batch. Null-safe: if not provided the upload still works, just
    // with a small risk of silent drop on very aggressive battery management profiles.
    // TODO(lucky-pot): also pass this lock when the daily reward eligibility check fires.
    private val uploadWakeLock: android.os.PowerManager.WakeLock? = null,
) {

    // ── PendingBatch ──────────────────────────────────────────────────────────

    /**
     * An immutable snapshot of sensor readings ready to upload.
     *
     * [batchId] and [capturedAt] are frozen at creation and NEVER changed on retry.
     * This is the key correctness property: if the same batch is sent twice (timeout,
     * network hiccup) the server can detect the duplicate via (device_hash, timestamp_utc).
     */
    private data class PendingBatch(
        val batchId: String,
        val readings: List<SensorReading>,
        val capturedAt: Long,          // epoch ms — frozen, reused on every retry attempt
        val retryCount: Int = 0,
        val nextRetryAfter: Long = 0L, // epoch ms — 0 = upload immediately
    )

    private val gson = Gson()
    private val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var uploadJob: Job? = null

    // Live sensor data — readings collected between upload cycles
    private val sensorBuffer = mutableListOf<SensorReading>()
    private val maxBufferSize = 1000

    // Retry queue — failed PendingBatches waiting for their backoff window to expire.
    // Kept separate from sensorBuffer so retries don't mix with fresh live data.
    private val retryQueue = ArrayDeque<PendingBatch>()

    // No retry cap: a transient failure never retires a batch (see class doc, point 3).
    private val MAX_BATCH_AGE_MS = 30L * 24 * 60 * 60_000L  // server rejects older (upload schema)

    // The server rejects batches over 500 readings (UploadBatchSchema); stay well under it.
    private val MAX_BATCH_READINGS = 400
    // A batch is stored as ONE averaged position. After a long deferral (offline, WiFi-only
    // walk) the buffer can span hours of travel; capping the span bounds how far that one
    // point can be from where any reading was actually taken. 10 min sits just above the
    // normal 5-min cycle, so ordinary batches are never split.
    private val MAX_BATCH_SPAN_MS = 10L * 60_000L

    /** What happened to one attempted batch — decides whether the rest of the flush continues. */
    private enum class UploadResult { SUCCESS, DROPPED, RETRY_LATER }

    // Weights for the batch centroid. A reported accuracy below the floor is not trusted
    // (fixes claiming 0-2 m are usually a stale or synthetic value); a missing one is treated
    // pessimistically rather than as perfect.
    private val MIN_FIX_ACCURACY_M = 3.0
    private val UNKNOWN_FIX_ACCURACY_M = 100.0
    private val METRES_PER_DEG_LAT = 111_320.0
    private fun sq(v: Double) = v * v

    // ── Connectivity telemetry ────────────────────────────────────────────────
    // Cumulative counters. Each upload reports the DELTA since the last SUCCESSFUL upload
    // (see TelemetryMark), so failures that happen while offline are reported by the first
    // batch that gets through instead of being lost with the failed attempt.
    private val droppedReadings = AtomicInteger(0)   // also touched by the sampler thread
    private var droppedBatches = 0
    private var interruptedAttempts = 0
    private var lastUploadMs = 0L                    // round trip of the last successful upload
    private var lastUploadBytes = 0                  // compressed size of that upload

    private data class TelemetryMark(
        val transitions: Long = 0,
        val unusableMs: Long = 0,
        val interrupted: Int = 0,
        val failed: Int = 0,
        val droppedReadings: Int = 0,
        val droppedBatches: Int = 0,
    )
    private var lastSentMark = TelemetryMark()

    // ── Sync health (developer tooling, debug builds only) ─────────────────────
    // A failing uploader used to be completely silent: the last successful upload was months
    // old and nothing on the phone said so. Persisted once per cycle for a debug-only panel.
    private var lastAttemptAtMs = 0L
    private var lastSuccessAtMs = 0L
    private var consecutiveFailures = 0
    private var lastErrorClass: String? = null

    /** Short, body-free label for a failure reason: never leaks a response body or token. */
    private fun errorClass(reason: String): String = when {
        reason.startsWith("HTTP ") -> reason.substringBefore(":").take(12)
        reason.startsWith("Network error") -> "Network error"
        else -> "Unexpected error"
    }

    /** Keep "last success" across service restarts, so a restart does not read as "never". */
    private fun loadPreviousHealth() {
        try {
            val raw = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
                .getString(AppPrefs.UPLOAD_HEALTH, null) ?: return
            @Suppress("UNCHECKED_CAST")
            val previous = gson.fromJson(raw, Map::class.java) as? Map<String, Any?> ?: return
            lastSuccessAtMs = (previous["last_success_at"] as? Double)?.toLong() ?: 0L
        } catch (e: Exception) {
            Log.w(TAG, "Could not read previous upload health: ${e.message}")
        }
    }

    // Developer tooling only: the snapshot is read by a debug-build panel and nothing else, so
    // release builds never write it at all.
    private val isDebuggable =
        (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Batches not yet accepted by the server, kept across process death. */
    private val queueFile by lazy { java.io.File(context.filesDir, "upload_queue.json") }

    /**
     * Publishes the number of batches still waiting, then notifies the listener, so
     * the service's notification is refreshed with an up-to-date count (the queue
     * file itself is written once per cycle).
     */
    private fun emitStatus(event: NativeUploadStatusEvent) {
        val pending = synchronized(retryQueue) { retryQueue.size }
        context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE).edit()
            .putInt(AppPrefs.UPLOAD_PENDING_BATCHES, pending)
            .apply()
        statusListener?.onStatus(event)
    }

    /** Writes the retry queue atomically (temp file, then rename). */
    private fun persistQueue() {
        try {
            val snapshot = synchronized(retryQueue) { retryQueue.toList() }
            context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE).edit()
                .putInt(AppPrefs.UPLOAD_PENDING_BATCHES, snapshot.size)
                .apply()
            if (snapshot.isEmpty()) {
                queueFile.delete()
                return
            }
            val tmp = java.io.File(queueFile.parentFile, queueFile.name + ".tmp")
            tmp.writeText(gson.toJson(snapshot))
            if (!tmp.renameTo(queueFile)) {
                queueFile.delete()
                tmp.renameTo(queueFile)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not persist upload queue: ${e.message}")
        }
    }

    /** Restores batches left by a previous run; each is due immediately. */
    private fun loadQueue() {
        if (!queueFile.exists()) return
        try {
            val type = object : com.google.gson.reflect.TypeToken<List<PendingBatch>>() {}.type
            val restored: List<PendingBatch> = gson.fromJson(queueFile.readText(), type) ?: emptyList()
            synchronized(retryQueue) {
                val known = retryQueue.map { it.batchId }.toSet()
                restored.filter { it.batchId !in known }
                    .forEach { retryQueue.addLast(it.copy(nextRetryAfter = 0L)) }
            }
            Log.i(TAG, "Restored ${restored.size} queued batches from disk")
        } catch (e: Exception) {
            // A file from an incompatible build: unreadable, so it cannot be sent anyway.
            Log.w(TAG, "Discarding unreadable upload queue: ${e.message}")
            queueFile.delete()
        }
    }

    private fun persistHealth() {
        if (!isDebuggable) return
        try {
            val s = networkMonitor?.snapshot()
            val health = mutableMapOf<String, Any?>(
                "at"                   to System.currentTimeMillis(),
                "last_success_at"      to lastSuccessAtMs.takeIf { it > 0 },
                "last_attempt_at"      to lastAttemptAtMs.takeIf { it > 0 },
                "consecutive_failures" to consecutiveFailures,
                "last_error"           to lastErrorClass,
                "buffer"               to getBufferSize(),
                "retry_queue"          to synchronized(retryQueue) { retryQueue.size },
                "dropped_batches"      to droppedBatches,
                "dropped_readings"     to droppedReadings.get(),
                "interrupted"          to interruptedAttempts,
                "transitions"          to (networkMonitor?.transitionCount() ?: 0L),
                "unusable_s"           to ((networkMonitor?.unusableMs() ?: 0L) / 1000),
                "transport"            to s?.transport?.wire,
                "validated"            to s?.validated,
                "metered"              to s?.metered,
            )
            context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE).edit()
                .putString(AppPrefs.UPLOAD_HEALTH, gson.toJson(health.filterValues { it != null }))
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "Could not persist upload health: ${e.message}")
        }
    }

    private fun currentMark() = TelemetryMark(
        transitions = networkMonitor?.transitionCount() ?: 0,
        unusableMs = networkMonitor?.unusableMs() ?: 0,
        interrupted = interruptedAttempts,
        failed = totalUploadsFailed,
        droppedReadings = droppedReadings.get(),
        droppedBatches = droppedBatches,
    )

    /** 30s → 1m → 2m → 4m → 8m → capped at 30m */
    private fun backoffMs(retryCount: Int): Long = minOf(30_000L shl retryCount, 30 * 60_000L)

    // baseUrl is stable so cached at init; apiKey is read fresh each upload to handle
    // the case where the service starts before Flutter has written the key (e.g. fresh install).
    private val baseUrl: String

    init {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        baseUrl = prefs.getString(AppPrefs.BACKEND_URL, null)
            ?: "https://greengains.onrender.com"
    }

    /** Reads the API key fresh from SharedPreferences on every call. */
    private fun resolveApiKey(): String {
        val key = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            .getString(AppPrefs.BACKEND_API_KEY, null)
        if (key.isNullOrEmpty()) {
            Log.w(TAG, "Backend API key not yet available — build with --dart-define-from-file=dart_defines.json")
        }
        return key ?: ""
    }

    // HTTP client with generous timeouts for Render.com cold starts (free tier)
    // Free tier spins down after 15min inactivity, takes 30-60s to wake up
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    // Stats for diagnostics
    private var totalUploadsAttempted = 0
    private var totalUploadsSucceeded = 0
    private var totalUploadsFailed = 0
    private var lastUploadTime: Long = 0

    // Track last location for geohash computation
    private var lastLocation: LocationData? = null

    fun start() {
        if (uploadJob?.isActive == true) {
            Log.d(TAG, "Uploader already running, ignoring start()")
            return
        }

        Log.i(TAG, "************************************************************")
        Log.i(TAG, "* Native backend uploader starting")
        Log.i(TAG, "* Interval: ${uploadIntervalMs / 1000}s | Queue kept on disk until accepted")
        Log.i(TAG, "* Backoff: 30s → 1m → 2m → 4m → 8m → 30m (cap)")
        Log.i(TAG, "* Endpoint: $baseUrl/upload | Gzip: enabled")
        Log.i(TAG, "************************************************************")

        // Pooled keep-alive sockets stay bound to the network they were opened on. After a
        // Wi-Fi <-> cellular handoff they are dead, so drop them and let the next call open a
        // fresh connection. (Sourced only from a public OkHttp issue, square/okhttp#4789 —
        // there is no maintainer-endorsed fix — so this is a defensive measure, not a guarantee.)
        networkMonitor?.transitionListener = { _, _ ->
            coroutineScope.launch { httpClient.connectionPool.evictAll() }
        }

        loadPreviousHealth()
        persistHealth()
        loadQueue()

        uploadJob = coroutineScope.launch {
            while (isActive) {
                try {
                    kotlinx.coroutines.delay(uploadIntervalMs)
                    uploadBatch()
                } catch (t: Throwable) {
                    Log.e(TAG, "Upload timer loop crashed: ${t.message}", t)
                }
            }
        }
    }

    fun stop() {
        Log.i(TAG, "Native backend uploader stopping. success=$totalUploadsSucceeded failure=$totalUploadsFailed")
        networkMonitor?.transitionListener = null
        uploadJob?.cancel()
        coroutineScope.coroutineContext.cancelChildren()
        // Readings of the unfinished window would otherwise die with the service:
        // queue them as batches and write the queue, to be sent on the next start.
        val pending = synchronized(sensorBuffer) { sensorBuffer.toList().also { sensorBuffer.clear() } }
        if (pending.isNotEmpty()) {
            synchronized(retryQueue) { chunkReadings(pending).forEach { retryQueue.addLast(it) } }
        }
        persistQueue()
    }

    fun addReading(reading: SensorReading) {
        synchronized(sensorBuffer) {
            sensorBuffer.add(reading)
            reading.location?.let { lastLocation = it }

            // Circular buffer: drop oldest entries beyond maxBufferSize
            while (sensorBuffer.size > maxBufferSize) {
                val removed = sensorBuffer.removeAt(0)
                droppedReadings.incrementAndGet()
                Log.w(TAG, "Buffer overflow. Dropping reading timestamp=${removed.timestamp}")
            }

            if (sensorBuffer.size % 50 == 0) {
                Log.d(TAG, "Buffered ${sensorBuffer.size} readings")
            }
        }
    }

    fun getBufferSize(): Int = synchronized(sensorBuffer) { sensorBuffer.size }

    private suspend fun uploadBatch() = withContext(Dispatchers.IO) {
        uploadWakeLock?.acquire(60_000L) // 60s ceiling — upload never takes longer; auto-releases if we crash
        try {
        val apiKey = resolveApiKey()
        if (apiKey.isEmpty()) {
            Log.w(TAG, "Upload skipped: API key missing")
            return@withContext
        }
        if (batteryMonitor?.shouldPauseForBattery() == true) {
            Log.i(TAG, "Upload skipped: battery low and not charging")
            return@withContext
        }
        if (networkMonitor?.isUploadAllowed() == false) {
            Log.i(TAG, "Upload skipped: network unavailable or WiFi-only mode enabled")
            return@withContext
        }

        val now = System.currentTimeMillis()

        // 1. Every retry whose backoff has expired, oldest first. Stale batches are dropped.
        //    All of them go out in this cycle: once one upload gets through the network is
        //    evidently fine, and after a long outage a one-batch-per-cycle drain would take
        //    an hour to clear a two-hour backlog.
        val toSend = ArrayDeque<PendingBatch>()
        synchronized(retryQueue) {
            while (true) {
                val head = retryQueue.firstOrNull() ?: break
                if (now - head.capturedAt >= MAX_BATCH_AGE_MS) {
                    retryQueue.removeFirst()
                    val ageHours = (now - head.capturedAt) / 3_600_000L
                    Log.w(TAG, "Dropped stale batch id=${head.batchId} age=${ageHours}h (server limit: 30 days)")
                    countDropped(head)
                } else if (now >= head.nextRetryAfter) {
                    retryQueue.removeFirst()
                    Log.i(TAG, "Retrying batch id=${head.batchId} attempt=${head.retryCount + 1}")
                    toSend.addLast(head)
                } else {
                    break // still in its backoff window
                }
            }
        }

        // 2. Then the live buffer, split into bounded batches (a long deferral must not
        //    become one giant, mislocated batch).
        val readings: List<SensorReading> = synchronized(sensorBuffer) {
            sensorBuffer.toList().also { sensorBuffer.clear() }
        }
        if (readings.isNotEmpty()) {
            val chunks = chunkReadings(readings)
            if (chunks.size > 1) {
                Log.i(TAG, "Flushing ${readings.size} readings as ${chunks.size} batches")
            }
            toSend.addAll(chunks)
        }

        if (toSend.isEmpty()) {
            Log.d(TAG, "Nothing to upload this cycle")
            return@withContext
        }

        // 3. Send in order. Stop at the first batch that must be retried and park the rest
        //    behind it, so a network that dies mid-flush never loses the unsent chunks.
        var first = true
        while (toSend.isNotEmpty()) {
            val next = toSend.removeFirst()
            if (!first) uploadWakeLock?.acquire(60_000L) // auto-releases by timeout if interrupted
            first = false

            if (uploadPendingBatch(next, apiKey) == UploadResult.RETRY_LATER) {
                val retryAt = System.currentTimeMillis() + backoffMs(1)
                synchronized(retryQueue) {
                    toSend.forEach { retryQueue.addLast(it.copy(nextRetryAfter = retryAt)) }
                }
                break
            }
        }
        } finally {
            persistHealth() // every path, including "skipped: no validated network"
            persistQueue()
            if (uploadWakeLock?.isHeld == true) uploadWakeLock.release()
        }
    }

    private suspend fun uploadPendingBatch(batch: PendingBatch, apiKey: String): UploadResult = withContext(Dispatchers.IO) {
        emitStatus(
            NativeUploadStatusEvent(
                type       = NativeUploadEventType.STARTED,
                batchSize  = batch.readings.size,
                bufferSize = getBufferSize(),
            )
        )

        val sinceLastStr = if (lastUploadTime == 0L) "n/a"
                           else "${(System.currentTimeMillis() - lastUploadTime) / 1000}s"
        Log.i(TAG, "------------------------------------------------------------")
        Log.i(TAG, "Uploading id=${batch.batchId} readings=${batch.readings.size} retry=${batch.retryCount} sinceLastUpload=$sinceLastStr")

        // Captured before the request so the catch block can tell whether the network moved.
        val netBefore = networkMonitor?.snapshot()

        try {
            val deviceId = getOrCreateDeviceId()
            val shareLocation = context
                .getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
                .getBoolean(AppPrefs.SHARE_LOCATION, true)

            val mark        = currentMark()
            val payload     = buildPayload(deviceId, batch, shareLocation, mark)
            val jsonBytes   = gson.toJson(payload).toByteArray(Charsets.UTF_8)
            val compressed  = gzip(jsonBytes)
            Log.d(TAG, "Payload: ${jsonBytes.size}B → ${compressed.size}B gzip (${100 - compressed.size * 100 / jsonBytes.size}% saved)")

            val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            val reqBuilder = Request.Builder()
                .url("$baseUrl/upload")
                .addHeader("Content-Type", "application/json")
                .addHeader("Content-Encoding", "gzip")
                .addHeader("X-API-Key", apiKey)

            // Log presence only — never any part of a secret or token.
            prefs.getString(AppPrefs.DEVICE_SECRET, null)?.let {
                reqBuilder.addHeader("x-device-secret", it)
                Log.d(TAG, "Auth: device secret present")
            } ?: Log.w(TAG, "Device Secret NOT found in SharedPreferences")

            prefs.getString(AppPrefs.FIREBASE_AUTH_TOKEN, null)?.let {
                reqBuilder.addHeader("Authorization", "Bearer $it")
                Log.d(TAG, "Auth: Firebase token present")
            }

            totalUploadsAttempted++
            lastAttemptAtMs = System.currentTimeMillis()
            val attemptLog ="Attempt #$totalUploadsAttempted: uploading ${batch.readings.size} readings"
            Log.i(TAG, attemptLog)
            AppLogger.i(TAG, attemptLog)

            val request = reqBuilder
                .post(compressed.toRequestBody("application/json".toMediaType()))
                .build()

            val startedAt = SystemClock.elapsedRealtime()
            httpClient.newCall(request).execute().use { resp ->
                if (resp.isSuccessful) {
                    lastUploadMs = SystemClock.elapsedRealtime() - startedAt
                    lastUploadBytes = compressed.size
                    lastSentMark = mark
                    handleSuccess(batch.readings.size, resp.code)
                    UploadResult.SUCCESS
                } else {
                    val errorBody = resp.body?.string() ?: "empty body"
                    handleHttpFailure(batch, resp.code, "HTTP ${resp.code}: $errorBody")
                }
            }
        } catch (ioe: IOException) {
            // If the network changed or dropped while this request was in flight, the batch is
            // not at fault: keep its retry budget instead of burning one of five on a handoff.
            val netAfter = networkMonitor?.snapshot()
            val networkMoved = netBefore != null && netAfter != null &&
                (netAfter.epoch != netBefore.epoch || !netAfter.usable)
            if (networkMoved) {
                deferInterrupted(batch, "Network error: ${ioe.message}")
            } else {
                handleFailure(batch, "Network error: ${ioe.message}")
                UploadResult.RETRY_LATER
            }
        } catch (t: Throwable) {
            handleFailure(batch, "Unexpected error: ${t.message}")
            UploadResult.RETRY_LATER
        }
    }

    private fun handleSuccess(batchSize: Int, statusCode: Int) {
        totalUploadsSucceeded++
        lastUploadTime = System.currentTimeMillis()
        lastSuccessAtMs = lastUploadTime
        consecutiveFailures = 0
        lastErrorClass = null
        val logMsg = "Upload succeeded. batch=$batchSize status=$statusCode total=$totalUploadsSucceeded"
        Log.i(TAG, logMsg)
        AppLogger.i(TAG, logMsg)

        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(
                AppPrefs.LAST_UPLOAD_AT,
                java.time.Instant.ofEpochMilli(lastUploadTime).toString()
            )
            .apply()

        saveContributionToDatabase(batchSize, lastUploadTime)

        emitStatus(
            NativeUploadStatusEvent(
                type       = NativeUploadEventType.SUCCESS,
                timestamp  = lastUploadTime,
                batchSize  = batchSize,
                bufferSize = getBufferSize(),
            )
        )
    }

    private fun handleFailure(batch: PendingBatch, reason: String) {
        totalUploadsFailed++
        consecutiveFailures++
        lastErrorClass = errorClass(reason)
        Log.e(TAG, "Upload FAILED id=${batch.batchId} retry=${batch.retryCount}: $reason")
        AppLogger.e(TAG, "Upload FAILED id=${batch.batchId} retry=${batch.retryCount}: $reason")

        // Transient by construction (permanent rejections never reach here): keep the
        // batch however long the outage lasts; only its age can retire it.
        val delay = backoffMs(batch.retryCount + 1)
        Log.i(TAG, "Scheduling retry #${batch.retryCount + 1} in ${delay / 1000}s")
        synchronized(retryQueue) {
            retryQueue.addLast(
                batch.copy(
                    retryCount     = batch.retryCount + 1,
                    nextRetryAfter = System.currentTimeMillis() + delay,
                )
            )
        }

        emitStatus(
            NativeUploadStatusEvent(
                type         = NativeUploadEventType.FAILURE,
                batchSize    = batch.readings.size,
                bufferSize   = getBufferSize(),
                errorMessage = reason,
            )
        )
    }

    /**
     * 400 / 413 / 422 mean the server understood the request and rejected THIS payload —
     * resending the identical bytes can never succeed, so drop instead of burning five
     * retries. Everything else (5xx, 401/403 while a token refreshes, 408, 429) can heal.
     */
    private fun handleHttpFailure(batch: PendingBatch, code: Int, reason: String): UploadResult {
        if (code == 400 || code == 413 || code == 422) {
            totalUploadsFailed++
            consecutiveFailures++
            lastErrorClass = errorClass(reason)
            Log.e(TAG, "Upload REJECTED permanently id=${batch.batchId}: $reason")
            AppLogger.e(TAG, "Upload REJECTED permanently id=${batch.batchId}: $reason")
            countDropped(batch)
            emitStatus(
                NativeUploadStatusEvent(
                    type         = NativeUploadEventType.FAILURE,
                    batchSize    = batch.readings.size,
                    bufferSize   = getBufferSize(),
                    errorMessage = reason,
                )
            )
            return UploadResult.DROPPED
        }
        handleFailure(batch, reason)
        return UploadResult.RETRY_LATER
    }

    /**
     * The network changed or dropped while a request was in flight. That says nothing about
     * the batch, so it goes back with its retry budget intact and is eligible next cycle.
     * Bounded by MAX_BATCH_AGE_MS, so it cannot loop forever.
     */
    private fun deferInterrupted(batch: PendingBatch, reason: String): UploadResult {
        interruptedAttempts++
        lastErrorClass = "Network changed"
        Log.w(TAG, "Upload interrupted by network change id=${batch.batchId}: $reason — retry budget kept")
        AppLogger.w(TAG, "Upload interrupted by network change id=${batch.batchId}")
        synchronized(retryQueue) {
            retryQueue.addLast(batch.copy(nextRetryAfter = System.currentTimeMillis()))
        }
        emitStatus(
            NativeUploadStatusEvent(
                type         = NativeUploadEventType.FAILURE,
                batchSize    = batch.readings.size,
                bufferSize   = getBufferSize(),
                errorMessage = reason,
            )
        )
        return UploadResult.RETRY_LATER
    }

    private fun countDropped(batch: PendingBatch) {
        droppedBatches++
        droppedReadings.addAndGet(batch.readings.size)
    }

    /**
     * Splits drained readings into batches that stay under the server's per-batch cap AND
     * never cover more than [MAX_BATCH_SPAN_MS]. Each batch's capturedAt is its newest reading
     * (not "now"): it stays unique per batch for the server's (device, timestamp) dedupe key,
     * and it is when the data was actually collected.
     */
    private fun chunkReadings(readings: List<SensorReading>): List<PendingBatch> {
        val chunks = mutableListOf<MutableList<SensorReading>>()
        var current = mutableListOf<SensorReading>()
        for (reading in readings) {
            val full = current.size >= MAX_BATCH_READINGS ||
                (current.isNotEmpty() && reading.timestamp - current.first().timestamp > MAX_BATCH_SPAN_MS)
            if (full) {
                chunks.add(current)
                current = mutableListOf()
            }
            current.add(reading)
        }
        if (current.isNotEmpty()) chunks.add(current)

        return chunks.map { chunk ->
            PendingBatch(
                batchId    = UUID.randomUUID().toString(),
                readings   = chunk,
                capturedAt = chunk.maxOf { it.timestamp },
            )
        }
    }

    /** Connectivity context for the backend. Deltas cover everything since the last SUCCESSFUL upload. */
    private fun buildNetworkTelemetry(batch: PendingBatch, mark: TelemetryMark): Map<String, Any>? {
        val s = networkMonitor?.snapshot() ?: return null
        val since = lastSentMark
        val oldest = batch.readings.minOfOrNull { it.timestamp }

        val out = mutableMapOf<String, Any>(
            "transport"        to s.transport.wire,
            "validated"        to s.validated,
            "metered"          to s.metered,
            "roaming"          to s.roaming,
            "down_kbps"        to s.downKbps,
            "up_kbps"          to s.upKbps,
            "attempt"          to (batch.retryCount + 1),
            "transitions"      to (mark.transitions - since.transitions).coerceAtLeast(0),
            "unusable_s"       to ((mark.unusableMs - since.unusableMs) / 1000).coerceAtLeast(0),
            "interrupted"      to (mark.interrupted - since.interrupted).coerceAtLeast(0),
            "failed"           to (mark.failed - since.failed).coerceAtLeast(0),
            "dropped_readings" to (mark.droppedReadings - since.droppedReadings).coerceAtLeast(0),
            "dropped_batches"  to (mark.droppedBatches - since.droppedBatches).coerceAtLeast(0),
        )
        if (oldest != null) out["queued_s"] = ((System.currentTimeMillis() - oldest) / 1000).coerceAtLeast(0)
        if (lastUploadMs > 0) {
            out["last_upload_ms"] = lastUploadMs
            out["last_upload_bytes"] = lastUploadBytes
        }
        return out
    }

    private fun buildPayload(
        deviceId: String,
        batch: PendingBatch,
        shareLocation: Boolean,
        mark: TelemetryMark,
    ): Map<String, Any?> {
        var avgLat: Double? = null
        var avgLon: Double? = null
        var avgAccuracy: Double? = null
        var spreadM: Double? = null

        if (shareLocation) {
            val locations = batch.readings.mapNotNull { it.location }
            if (locations.isNotEmpty()) {
                // Inverse-variance weighted centroid: accuracy is the 68 % radius (~1 sigma), so
                // a 5 m fix counts 400x a 100 m one instead of the two averaging as equals.
                val weights = locations.map { 1.0 / sq((it.accuracy ?: UNKNOWN_FIX_ACCURACY_M).coerceAtLeast(MIN_FIX_ACCURACY_M)) }
                val wSum = weights.sum()
                val centroidLat = locations.indices.sumOf { locations[it].latitude  * weights[it] } / wSum
                val centroidLon = locations.indices.sumOf { locations[it].longitude * weights[it] } / wSum
                avgLat = centroidLat
                avgLon = centroidLon
                // Kept as the plain mean of reported accuracies: downstream thresholds
                // (personal-tile filter, quality bands) were tuned against this meaning.
                avgAccuracy = locations.mapNotNull { it.accuracy  }.average()

                // A batch is stored as ONE point. This says how much travel that point hides:
                // RMS distance of the batch's positions from the centroid. Deliberately
                // UNweighted: weighting by accuracy would down-weight exactly the coarse fixes
                // and understate the movement. Without it a 5-minute walk and a 5-minute
                // stand-still look equally precise.
                val mPerDegLon = METRES_PER_DEG_LAT * kotlin.math.cos(Math.toRadians(centroidLat))
                val meanSq = locations.sumOf { p ->
                    val dy = (p.latitude  - centroidLat) * METRES_PER_DEG_LAT
                    val dx = (p.longitude - centroidLon) * mPerDegLon
                    dx * dx + dy * dy
                } / locations.size
                spreadM = kotlin.math.sqrt(meanSq)
            }
        }

        val batchPayload = batch.readings.mapIndexed { index, reading ->
            if (index < 3) {
                Log.d(TAG, "Building payload reading #$index: pressure=${reading.pressure}, light=${reading.light}")
            }
            mapOf(
                "t"        to reading.timestamp,
                "light"    to reading.light,
                "accel"    to reading.accelerometer?.let { listOf(it.x, it.y, it.z) },
                "gyro"     to reading.gyroscope?.let { listOf(it.x, it.y, it.z) },
                "pressure" to reading.pressure,
                "magnetic" to reading.magneticField?.toPayloadList(),
                "aux"      to reading.aux?.takeIf { it.isNotEmpty() },
                "quality"  to reading.quality?.toPayloadMap()?.takeIf { it.isNotEmpty() },
            ).filterValues { it != null }
        }

        val locationMap = if (avgLat != null && avgLon != null) {
            // Coordinates leave the phone rounded to 1e-4° (~11 m), the precision
            // Hivemapper's open dashcam keeps (H3 res 12, ~9 m edge). That is finer
            // than every cell the server builds (res 9, 174 m) and than phone GPS
            // error, so mapping loses nothing while the exact position stays local.
            mapOf(
                "lat"        to Math.round(avgLat * 1e4) / 1e4,
                "lon"        to Math.round(avgLon * 1e4) / 1e4,
                "accuracy_m" to avgAccuracy,
                "spread_m"   to spreadM?.let { Math.round(it * 10) / 10.0 },
            ).filterValues { it != null }
        } else null

        val geohash = if (shareLocation) computeGeohash() else null

        // Bitmask: which sensor types actually provided data in this batch.
        // LIGHT=1, MOTION=2, PRESSURE=4, GYRO=8, MAGNETIC=16
        // Lets backend weight quality and lets B2B buyers know data coverage.
        var sensorFlags = 0
        for (r in batch.readings) {
            if (r.light    != null) sensorFlags = sensorFlags or 1
            if (r.accelerometer != null) sensorFlags = sensorFlags or 2
            if (r.pressure != null) sensorFlags = sensorFlags or 4
            if (r.gyroscope != null) sensorFlags = sensorFlags or 8
            if (r.magneticField != null) sensorFlags = sensorFlags or 16
        }

        return mapOf(
            "device_id"     to deviceId,
            "batch_id"      to batch.batchId,
            "timestamp"     to batch.capturedAt,
            "batch"         to batchPayload,
            "location"      to locationMap,
            "wifi_rssi_avg" to readWifiRssi(),
            "wifi_ap_count" to readWifiApCount(),
            "geohash"       to geohash,
            "battery_level" to (batteryMonitor?.getBatteryLevel() ?: -1),
            "is_charging"   to (batteryMonitor?.isCharging() ?: false),
            "sensor_flags"  to sensorFlags,
            "network"       to buildNetworkTelemetry(batch, mark),
            // Phone model with every batch, as NoiseCapture and WeatherXM keep it:
            // sensors differ by model, so per-model corrections need it.
            "device"        to mapOf(
                "manufacturer" to android.os.Build.MANUFACTURER,
                "model"        to android.os.Build.MODEL,
                "sdk"          to android.os.Build.VERSION.SDK_INT,
            ),
        ).filterValues { it != null }
    }

    /** Compress bytes with gzip. Server's decompressPayload() handles Content-Encoding: gzip. */
    private fun gzip(data: ByteArray): ByteArray {
        val bos = ByteArrayOutputStream(data.size)
        GZIPOutputStream(bos).use { it.write(data) }
        return bos.toByteArray()
    }

    private fun QualityMetadata.toPayloadMap(): Map<String, Any?> {
        return mapOf(
            "orientation"       to orientation.name.lowercase(),
            "tilt_deg"          to tiltDegrees,
            "motion_state"      to motionState.name.lowercase(),
            "motion_confidence" to motionConfidence.toDouble(),
            "pocket"            to pocketState.name.lowercase(),
            "location_quality"  to locationQuality.name.lowercase(),
            "sample_count"      to sampleCount,
            "proximity_near"    to proximityNear,
            "precision_score"   to precisionScore?.toDouble(),
        ).filterValues { it != null }
    }

    /**
     * Serialises magnetic field as [x, y, z, magnitude] (µT).
     * Compact list format keeps batch payload small; magnitude is redundant but avoids
     * recomputation on the backend for common queries (e.g. indoor/outdoor detection).
     */
    private fun MagneticData.toPayloadList(): List<Float> = listOf(x, y, z, magnitude)

    private fun getOrCreateDeviceId(): String {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        return prefs.getString(AppPrefs.DEVICE_ID, null)
            ?: UUID.randomUUID().toString().also { id ->
                prefs.edit().putString(AppPrefs.DEVICE_ID, id).apply()
                Log.i(TAG, "Generated new device ID: $id")
            }
    }

    /**
     * Save contribution directly to SQLite database (same database Flutter uses).
     * This ensures stats are updated even when Flutter is disconnected.
     */
    private fun saveContributionToDatabase(samplesCount: Int, timestamp: Long) {
        if (samplesCount <= 0) return
        try {
            val dbPath = context.getDatabasePath("greengains.db")
            if (!dbPath.exists()) {
                Log.w(TAG, "Database not found, Flutter hasn't initialized it yet. Skipping contribution save.")
                return
            }

            // Open with WAL mode to match Flutter's sqflite (prevents corruption)
            val db = SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING,
            )

            db.use {
                val geohash = computeGeohash()
                db.beginTransaction()
                try {
                    val values = ContentValues().apply {
                        put("id",            UUID.randomUUID().toString())
                        put("timestamp",     timestamp)
                        put("samples_count", samplesCount)
                        put("geohash",       geohash)
                        put("success",       1)
                        put("created_at",    System.currentTimeMillis())
                    }
                    val rowId = db.insert("contributions", null, values)
                    if (rowId != -1L) {
                        db.setTransactionSuccessful()
                        Log.d(TAG, "Contribution saved: samples=$samplesCount geohash=$geohash")
                    } else {
                        Log.e(TAG, "Failed to insert contribution to database")
                    }
                } finally {
                    db.endTransaction()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving contribution to database: ${e.message}", e)
        }
    }

    /**
     * Compute geohash from last known location.
     * Precision adapts to GPS accuracy so coarse-location users map to appropriately sized cells:
     *   ≤50m accuracy  → precision 6 (~1.2km cells)
     *   ≤200m accuracy → precision 5 (~5km cells)
     *   >200m / no accuracy (network/WiFi) → precision 4 (~40km cells)
     */
    private fun computeGeohash(): String? {
        val location = lastLocation ?: return null
        return try {
            val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(AppPrefs.SHARE_LOCATION, true)) return null
            val acc = location.accuracy
            val precision = when {
                acc != null && acc <= 50.0  -> 6
                acc != null && acc <= 200.0 -> 5
                else                        -> 4
            }
            GeoHash.withCharacterPrecision(location.latitude, location.longitude, precision).toBase32()
        } catch (e: Exception) {
            Log.e(TAG, "Error computing geohash: ${e.message}", e)
            null
        }
    }

    /**
     * Returns current WiFi signal strength in dBm, or null if not on WiFi / unavailable.
     * Typical range: -30 (excellent) to -90 (unusable). RSSI_UNKNOWN (-127) is filtered out.
     * No SSID or MAC is read — only signal level.
     */
    @Suppress("DEPRECATION")
    private fun readWifiRssi(): Int? {
        return try {
            val wifi = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return null
            val info = wifi.connectionInfo ?: return null
            val rssi = info.rssi
            if (rssi <= -127) null else rssi
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Count of visible WiFi access points from the last OS scan.
     * Uses cached scan results — no active scan triggered, no SSIDs or MACs read.
     * Requires ACCESS_WIFI_STATE + ACCESS_FINE_LOCATION (both already declared).
     * Urban density proxy: more APs = denser built environment.
     */
    @Suppress("DEPRECATION")
    private fun readWifiApCount(): Int? {
        return try {
            val wifi = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return null
            val results = wifi.scanResults ?: return null
            results.size
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val TAG = "NativeBackendUploader"
    }
}

// Models moved to com.eremat.greengains.models.SensorModels
