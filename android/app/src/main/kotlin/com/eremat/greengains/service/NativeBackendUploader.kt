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
 *  3. Max retry limit — after [MAX_RETRIES] attempts the batch is dropped. Prevents
 *     unbounded in-memory queue growth during prolonged outages.
 *
 *  4. Batch age limit — batches older than [MAX_BATCH_AGE_MS] (4h) are silently
 *     dropped. Stale environmental data has diminishing value and merging very old
 *     readings with current tiles would skew time-series accuracy.
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

    private val MAX_RETRIES = 5
    private val MAX_BATCH_AGE_MS = 4L * 60 * 60_000L  // 4 hours

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
        Log.i(TAG, "* Interval: ${uploadIntervalMs / 1000}s | Max retries: $MAX_RETRIES")
        Log.i(TAG, "* Backoff: 30s → 1m → 2m → 4m → 8m → 30m (cap)")
        Log.i(TAG, "* Endpoint: $baseUrl/upload | Gzip: enabled")
        Log.i(TAG, "************************************************************")

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
        uploadJob?.cancel()
        coroutineScope.coroutineContext.cancelChildren()
    }

    fun addReading(reading: SensorReading) {
        synchronized(sensorBuffer) {
            sensorBuffer.add(reading)
            reading.location?.let { lastLocation = it }

            // Circular buffer: drop oldest entries beyond maxBufferSize
            while (sensorBuffer.size > maxBufferSize) {
                val removed = sensorBuffer.removeAt(0)
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

        // 1. Check if a pending retry is due
        val retryBatch: PendingBatch? = synchronized(retryQueue) {
            val head = retryQueue.firstOrNull() ?: return@synchronized null
            when {
                now - head.capturedAt >= MAX_BATCH_AGE_MS -> {
                    // Stale — drop silently
                    retryQueue.removeFirst()
                    val ageHours = (now - head.capturedAt) / 3_600_000L
                    Log.w(TAG, "Dropped stale batch id=${head.batchId} age=${ageHours}h (limit=4h)")
                    null
                }
                now >= head.nextRetryAfter -> {
                    retryQueue.removeFirst()
                    head  // backoff expired — ready to retry
                }
                else -> null  // still in backoff window — fall through to live buffer
            }
        }

        val batch: PendingBatch = if (retryBatch != null) {
            Log.i(TAG, "Retrying batch id=${retryBatch.batchId} attempt=${retryBatch.retryCount + 1}/$MAX_RETRIES")
            retryBatch
        } else {
            // 2. Drain the live sensor buffer into a fresh batch
            val readings: List<SensorReading> = synchronized(sensorBuffer) {
                if (sensorBuffer.isEmpty()) {
                    Log.d(TAG, "No sensor readings collected yet, skipping upload cycle")
                    return@withContext
                }
                sensorBuffer.toList().also { sensorBuffer.clear() }
            }
            PendingBatch(
                batchId    = UUID.randomUUID().toString(),
                readings   = readings,
                capturedAt = now,
            )
        }

        uploadPendingBatch(batch, apiKey)
        } finally {
            if (uploadWakeLock?.isHeld == true) uploadWakeLock.release()
        }
    }

    private suspend fun uploadPendingBatch(batch: PendingBatch, apiKey: String) = withContext(Dispatchers.IO) {
        statusListener?.onStatus(
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

        try {
            val deviceId = getOrCreateDeviceId()
            val shareLocation = context
                .getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
                .getBoolean(AppPrefs.SHARE_LOCATION, true)

            val payload     = buildPayload(deviceId, batch, shareLocation)
            val jsonBytes   = gson.toJson(payload).toByteArray(Charsets.UTF_8)
            val compressed  = gzip(jsonBytes)
            Log.d(TAG, "Payload: ${jsonBytes.size}B → ${compressed.size}B gzip (${100 - compressed.size * 100 / jsonBytes.size}% saved)")

            val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            val reqBuilder = Request.Builder()
                .url("$baseUrl/upload")
                .addHeader("Content-Type", "application/json")
                .addHeader("Content-Encoding", "gzip")
                .addHeader("X-API-Key", apiKey)

            prefs.getString(AppPrefs.DEVICE_SECRET, null)?.let {
                reqBuilder.addHeader("x-device-secret", it)
                Log.d(TAG, "Auth: device secret ${it.take(5)}…")
            } ?: Log.w(TAG, "Device Secret NOT found in SharedPreferences")

            prefs.getString(AppPrefs.FIREBASE_AUTH_TOKEN, null)?.let {
                reqBuilder.addHeader("Authorization", "Bearer $it")
                Log.d(TAG, "Auth: Firebase token ${it.take(10)}…")
            }

            totalUploadsAttempted++
            val attemptLog = "Attempt #$totalUploadsAttempted: uploading ${batch.readings.size} readings"
            Log.i(TAG, attemptLog)
            AppLogger.i(TAG, attemptLog)

            val request = reqBuilder
                .post(compressed.toRequestBody("application/json".toMediaType()))
                .build()

            httpClient.newCall(request).execute().use { resp ->
                if (resp.isSuccessful) {
                    handleSuccess(batch.readings.size, resp.code)
                } else {
                    val errorBody = resp.body?.string() ?: "empty body"
                    handleFailure(batch, "HTTP ${resp.code}: $errorBody")
                }
            }
        } catch (ioe: IOException) {
            handleFailure(batch, "Network error: ${ioe.message}")
        } catch (t: Throwable) {
            handleFailure(batch, "Unexpected error: ${t.message}")
        }
    }

    private fun handleSuccess(batchSize: Int, statusCode: Int) {
        totalUploadsSucceeded++
        lastUploadTime = System.currentTimeMillis()
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

        statusListener?.onStatus(
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
        Log.e(TAG, "Upload FAILED id=${batch.batchId} retry=${batch.retryCount}: $reason")
        AppLogger.e(TAG, "Upload FAILED id=${batch.batchId} retry=${batch.retryCount}: $reason")

        if (batch.retryCount >= MAX_RETRIES) {
            Log.w(TAG, "Dropping batch ${batch.batchId} — exhausted $MAX_RETRIES retries")
        } else {
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
        }

        statusListener?.onStatus(
            NativeUploadStatusEvent(
                type         = NativeUploadEventType.FAILURE,
                batchSize    = batch.readings.size,
                bufferSize   = getBufferSize(),
                errorMessage = reason,
            )
        )
    }

    private fun buildPayload(
        deviceId: String,
        batch: PendingBatch,
        shareLocation: Boolean,
    ): Map<String, Any?> {
        var avgLat: Double? = null
        var avgLon: Double? = null
        var avgAccuracy: Double? = null

        if (shareLocation) {
            val locations = batch.readings.mapNotNull { it.location }
            if (locations.isNotEmpty()) {
                avgLat      = locations.mapNotNull { it.latitude  }.average()
                avgLon      = locations.mapNotNull { it.longitude }.average()
                avgAccuracy = locations.mapNotNull { it.accuracy  }.average()
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
                "quality"  to reading.quality?.toPayloadMap()?.takeIf { it.isNotEmpty() },
            ).filterValues { it != null }
        }

        val locationMap = if (avgLat != null && avgLon != null) {
            mapOf(
                "lat"        to avgLat,
                "lon"        to avgLon,
                "accuracy_m" to avgAccuracy,
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
            "geohash"       to geohash,
            "battery_level" to (batteryMonitor?.getBatteryLevel() ?: -1),
            "is_charging"   to (batteryMonitor?.isCharging() ?: false),
            "sensor_flags"  to sensorFlags,
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
            if (rssi == WifiManager.RSSI_UNKNOWN || rssi <= -127) null else rssi
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val TAG = "NativeBackendUploader"
    }
}

// Models moved to com.eremat.greengains.models.SensorModels
