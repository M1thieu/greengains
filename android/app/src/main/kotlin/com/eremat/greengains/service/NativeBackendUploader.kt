package com.eremat.greengains.service

import com.eremat.greengains.models.AccelData
import com.eremat.greengains.models.GyroData
import com.eremat.greengains.models.LocationData
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
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * Native Backend Uploader - Runs independently of Flutter.
 *
 * Responsibilities:
 * - Collect batched sensor samples
 * - Upload every couple of minutes via OkHttp
 * - Retry on failure while keeping the buffer bounded
 * - Report status events back to the service/Flutter
 */
class NativeBackendUploader(
    private val context: Context,
    private val uploadIntervalMs: Long = 300_000L, // 5 min - reduces backend costs by 60%
    private val batteryMonitor: BatteryStateMonitor? = null,
    private val networkMonitor: NetworkStateMonitor? = null,
    private val statusListener: NativeUploadStatusListener? = null
) {
    private val gson = Gson()
    private val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var uploadJob: Job? = null

    // Buffer for sensor readings (max 1000 entries ~ 166 minutes of data at 10s sampling)
    private val sensorBuffer = mutableListOf<SensorReading>()
    private val maxBufferSize = 1000

    // Backend configuration (loaded from SharedPreferences, set by Flutter)
    private val baseUrl: String
    private val apiKey: String

    init {
        // Load API key from SharedPreferences (Flutter writes it on startup)
        // NOTE: apiKey might be empty on first launch - uploads will be skipped until Flutter initializes
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        baseUrl = prefs.getString(AppPrefs.BACKEND_URL, null)
            ?: "https://greengains.onrender.com"
        apiKey = prefs.getString(AppPrefs.BACKEND_API_KEY, null) ?: run {
            Log.w(TAG, "Backend API key not yet available - uploads will be skipped until Flutter initializes")
            "" // Empty string - uploads will be skipped
        }
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

        Log.i(TAG, "********************************************")
        Log.i(TAG, "* Native backend uploader starting")
        Log.i(TAG, "* Interval: ${uploadIntervalMs / 1000}s")
        Log.i(TAG, "* Endpoint: $baseUrl/upload")
        Log.i(TAG, "* Buffer cap: $maxBufferSize readings")
        Log.i(TAG, "********************************************")

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

            // Track last known location for contribution geohash
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
        // Skip if API key not yet loaded
        if (apiKey.isEmpty()) {
            Log.d(TAG, "Upload skipped: API key not yet available (Flutter still initializing)")
            return@withContext
        }

        // Check battery state before attempting upload
        if (batteryMonitor?.shouldPauseForBattery() == true) {
            Log.i(TAG, "Upload skipped: battery low and not charging")
            return@withContext
        }

        // Check network state before attempting upload
        if (networkMonitor?.isUploadAllowed() == false) {
            Log.i(TAG, "Upload skipped: network unavailable or WiFi-only mode enabled")
            return@withContext
        }

        val readings: List<SensorReading>

        synchronized(sensorBuffer) {
            if (sensorBuffer.isEmpty()) {
                Log.d(TAG, "No sensor readings collected yet, skipping upload cycle")
                return@withContext
            }

            readings = sensorBuffer.toList()
            sensorBuffer.clear()
        }

        statusListener?.onStatus(
            NativeUploadStatusEvent(
                type = NativeUploadEventType.STARTED,
                batchSize = readings.size,
                bufferSize = getBufferSize()
            )
        )

        val now = System.currentTimeMillis()
        val timeSinceLast = if (lastUploadTime == 0L) {
            "n/a"
        } else {
            "${(now - lastUploadTime) / 1000}s"
        }

        Log.i(TAG, "--------------------------------------------")
        Log.i(TAG, "Uploading ${readings.size} readings to backend")
        Log.i(TAG, "Time since last upload: $timeSinceLast")

        try {
            val deviceId = getOrCreateDeviceId()
            val shareLocation = context
                .getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
                .getBoolean(AppPrefs.SHARE_LOCATION, true) // default true: mapping is the app's purpose

            val payload = buildPayload(deviceId, readings, shareLocation)
            val jsonPayload = gson.toJson(payload)

            val request = Request.Builder()
                .url("$baseUrl/upload")
                .addHeader("Content-Type", "application/json")
                .addHeader("X-API-Key", apiKey)

            // Add Firebase Auth Token if available (The "Honeygain" Link)
            val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            val token = prefs.getString(AppPrefs.FIREBASE_AUTH_TOKEN, null)
            
            // Add Device Secret (Long-lived Auth)
            val deviceSecret = prefs.getString(AppPrefs.DEVICE_SECRET, null)
            if (deviceSecret != null) {
                Log.d(TAG, "Found Device Secret: ${deviceSecret.take(5)}...")
                request.addHeader("x-device-secret", deviceSecret)
            } else {
                Log.w(TAG, "Device Secret NOT found in SharedPreferences")
            }

            if (token != null) {
                Log.d(TAG, "Found Auth Token: ${token.take(10)}...")
                // ... (existing token decoding logic if needed, or just add header)
                request.addHeader("Authorization", "Bearer $token")
            } else {
                Log.w(TAG, "Auth Token NOT found in SharedPreferences")
            }

            val builtRequest = request.post(jsonPayload.toRequestBody("application/json".toMediaType())).build()

            totalUploadsAttempted++
            val attemptLog = "Attempt #$totalUploadsAttempted: Uploading ${readings.size} readings"
            Log.i(TAG, attemptLog)
            AppLogger.i("NativeUploader", attemptLog)

            val response = httpClient.newCall(builtRequest).execute()
            response.use {
                if (it.isSuccessful) {
                    handleSuccess(readings.size, it.code)
                } else {
                    val errorBody = it.body?.string()
                    val errorMsg = "HTTP ${it.code}: ${errorBody ?: "empty body"}"
                    Log.e(TAG, "Upload #$totalUploadsAttempted FAILED: $errorMsg")
                    AppLogger.e("NativeUploader", "Upload #$totalUploadsAttempted FAILED: $errorMsg")
                    handleFailure(
                        readings,
                        errorMsg
                    )
                }
            }
        } catch (ioe: IOException) {
            val msg = "Network error: ${ioe.message}"
            Log.e(TAG, "Upload #$totalUploadsAttempted FAILED: $msg", ioe)
            AppLogger.e("NativeUploader", "Upload #$totalUploadsAttempted FAILED: $msg", ioe)
            handleFailure(readings, msg)
        } catch (t: Throwable) {
            val msg = "Unexpected error: ${t.message}"
            Log.e(TAG, "Upload #$totalUploadsAttempted FAILED: $msg", t)
            AppLogger.e("NativeUploader", "Upload #$totalUploadsAttempted FAILED: $msg", t)
            handleFailure(readings, msg)
        }
    }

    private fun handleSuccess(batchSize: Int, statusCode: Int) {
        totalUploadsSucceeded++
        lastUploadTime = System.currentTimeMillis()
        val logMsg = "Upload succeeded. batch=$batchSize status=$statusCode total=$totalUploadsSucceeded"
        Log.i(TAG, logMsg)
        AppLogger.i("NativeUploader", logMsg)

        // Save upload timestamp to SharedPreferences so Flutter can read it on resume
        // Format as ISO8601 string to match Flutter's expectation
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val iso8601Timestamp = java.time.Instant
            .ofEpochMilli(lastUploadTime)
            .toString()
        prefs.edit()
            .putString(AppPrefs.LAST_UPLOAD_AT, iso8601Timestamp)
            .apply()

        // Save contribution to local SQLite database (independent of Flutter)
        saveContributionToDatabase(batchSize, lastUploadTime)

        statusListener?.onStatus(
            NativeUploadStatusEvent(
                type = NativeUploadEventType.SUCCESS,
                timestamp = lastUploadTime,
                batchSize = batchSize,
                bufferSize = getBufferSize()
            )
        )
    }

    private fun handleFailure(readings: List<SensorReading>, reason: String) {
        totalUploadsFailed++
        Log.e(TAG, "Upload failed (${readings.size} readings). $reason")
        requeueReadings(readings)

        statusListener?.onStatus(
            NativeUploadStatusEvent(
                type = NativeUploadEventType.FAILURE,
                batchSize = readings.size,
                bufferSize = getBufferSize(),
                errorMessage = reason
            )
        )
    }

    private fun requeueReadings(readings: List<SensorReading>) {
        if (readings.isEmpty()) return

        synchronized(sensorBuffer) {
            val toRestore = if (readings.size > maxBufferSize) {
                readings.takeLast(maxBufferSize)
            } else {
                readings
            }
            sensorBuffer.addAll(0, toRestore)

            while (sensorBuffer.size > maxBufferSize) {
                sensorBuffer.removeAt(0)
            }
        }
    }

    private fun buildPayload(
        deviceId: String,
        readings: List<SensorReading>,
        shareLocation: Boolean
    ): Map<String, Any?> {
        var avgLat: Double? = null
        var avgLon: Double? = null
        var avgAccuracy: Double? = null

        if (shareLocation) {
            val locations = readings.mapNotNull { it.location }
            if (locations.isNotEmpty()) {
                avgLat = locations.mapNotNull { it.latitude }.average()
                avgLon = locations.mapNotNull { it.longitude }.average()
                avgAccuracy = locations.mapNotNull { it.accuracy }.average()
            }
        }

        val batch = readings.mapIndexed { index, reading ->
            // Debug: Log first 3 readings to see pressure values
            if (index < 3) {
                Log.d(TAG, "Building payload for reading #$index: pressure=${reading.pressure}, light=${reading.light}")
            }

            mapOf(
                "t" to reading.timestamp,
                "light" to reading.light,
                "accel" to reading.accelerometer?.let { listOf(it.x, it.y, it.z) },
                "gyro" to reading.gyroscope?.let { listOf(it.x, it.y, it.z) },
                "pressure" to reading.pressure,
                "quality" to reading.quality?.toPayloadMap()?.takeIf { it.isNotEmpty() }
            ).filterValues { it != null }
        }

        val locationMap = if (avgLat != null && avgLon != null) {
            mapOf(
                "lat" to avgLat,
                "lon" to avgLon,
                "accuracy_m" to avgAccuracy
            ).filterValues { it != null }
        } else {
            null
        }

        val geohash = if (shareLocation) computeGeohash() else null

        return mapOf(
            "device_id" to deviceId,
            "timestamp" to System.currentTimeMillis(),
            "batch" to batch,
            "location" to locationMap,
            "geohash" to geohash
        ).filterValues { it != null }
    }

    private fun QualityMetadata.toPayloadMap(): Map<String, Any?> {
        return mapOf(
            "orientation" to orientation.name.lowercase(),
            "tilt_deg" to tiltDegrees,
            "motion_state" to motionState.name.lowercase(),
            "motion_confidence" to motionConfidence.toDouble(),
            "pocket" to pocketState.name.lowercase(),
            "location_quality" to locationQuality.name.lowercase()
        ).filterValues { it != null }
    }

    private fun getOrCreateDeviceId(): String {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        var deviceId = prefs.getString(AppPrefs.DEVICE_ID, null)

        if (deviceId == null) {
            deviceId = UUID.randomUUID().toString()
            prefs.edit().putString(AppPrefs.DEVICE_ID, deviceId).apply()
            Log.i(TAG, "Generated new device ID: $deviceId")
        }

        return deviceId
    }

    /**
     * Save contribution directly to SQLite database (same database Flutter uses).
     * This ensures stats are updated even when Flutter is disconnected.
     */
    private fun saveContributionToDatabase(samplesCount: Int, timestamp: Long) {
        if (samplesCount <= 0) {
            return
        }

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
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING
            )

            db.use {
                val geohash = computeGeohash()
                val contributionId = UUID.randomUUID().toString()
                val now = System.currentTimeMillis()

                // Use transaction for atomicity
                db.beginTransaction()
                try {
                    val values = ContentValues().apply {
                        put("id", contributionId)
                        put("timestamp", timestamp)
                        put("samples_count", samplesCount)
                        put("geohash", geohash)
                        put("success", 1)
                        put("created_at", now)
                    }

                    val rowId = db.insert("contributions", null, values)
                    if (rowId != -1L) {
                        db.setTransactionSuccessful()
                        Log.d(TAG, "Contribution saved to database: id=$contributionId samples=$samplesCount geohash=$geohash")
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
     * Compute geohash from last known location (precision 6 for ~1.2km tiles).
     */
    private fun computeGeohash(): String? {
        val location = lastLocation ?: return null

        return try {
            // Check if user enabled location sharing
            val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            val shareLocation = prefs.getBoolean(AppPrefs.SHARE_LOCATION, true)

            if (!shareLocation) {
                null
            } else {
                GeoHash.withCharacterPrecision(
                    location.latitude,
                    location.longitude,
                    6
                ).toBase32()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error computing geohash: ${e.message}", e)
            null
        }
    }

    companion object {
        private const val TAG = "NativeBackendUploader"
    }
}

// Models moved to com.eremat.greengains.models.SensorModels
