package com.eremat.greengains.service

import android.Manifest.permission.ACCESS_COARSE_LOCATION
import android.Manifest.permission.ACCESS_FINE_LOCATION
import android.annotation.SuppressLint
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.SensorManager
import android.location.Location
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.PermissionChecker
import com.eremat.greengains.models.AccelData
import com.eremat.greengains.models.GyroData
import com.eremat.greengains.models.LocationData
import com.eremat.greengains.models.MotionState
import com.eremat.greengains.models.NativeUploadEventType
import com.eremat.greengains.models.NativeUploadStatusEvent
import com.eremat.greengains.models.SensorReading
import com.eremat.greengains.notification.NotificationsHelper
import com.eremat.greengains.util.AppPrefs
import com.eremat.greengains.service.sensors.Barometer
import com.eremat.greengains.service.sensors.LightSensor
import com.eremat.greengains.service.sensors.MotionSensors
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.time.Duration.Companion.seconds

/**
 * Simple foreground service that shows a notification to the user and provides sensor data.
 * Based on: https://github.com/landomen/ForegroundServiceSample
 *
 * Sensors:
 * - Location (GPS/Network via FusedLocationProviderClient)
 * - Light (ambient light in lux via SensorManager)
 * - Barometer (pressure in hPa via SensorManager)
 * - Motion sensors (accelerometer, gyroscope via SensorManager)
 */
class ForegroundService : Service() {

    inner class LocalBinder : Binder() {
        fun getService(): ForegroundService = this@ForegroundService
    }

    private val binder = LocalBinder()
    private val coroutineScope = CoroutineScope(Job())

    // Location
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    // Sensors
    private lateinit var sensorManager: SensorManager
    private lateinit var lightSensor: LightSensor
    private lateinit var barometer: Barometer
    private lateinit var motionSensors: MotionSensors

    // Monitors
    private lateinit var batteryMonitor: BatteryStateMonitor
    private lateinit var networkMonitor: NetworkStateMonitor
    private lateinit var notificationManager: NotificationManager

    // Analysis
    private val qualityAnalyzer = SensorQualityAnalyzer()

    // Native Uploader
    private var nativeUploader: NativeBackendUploader? = null
    private var nativeSamplerJob: Job? = null
    private var trackingPausedState: Boolean = false

    // Data Flows
    private val _lightFlow = MutableStateFlow<Float?>(null)
    private val _pressureFlow = MutableStateFlow<Float?>(null)
    private val _accelerometerFlow = MutableStateFlow<FloatArray?>(null)
    private val _gyroscopeFlow = MutableStateFlow<FloatArray?>(null)
    private val _locationFlow = MutableStateFlow<Location?>(null)

    // Adaptive GPS optimization with interval-based battery savings:
    // - Always uses PRIORITY_HIGH_ACCURACY for fresh GPS/network locations
    // - Stationary: 60s interval (~50% battery savings, still fresh data)
    // - Moving: 10s interval (better tracking)
    // - FusedLocationProvider automatically falls back to network/WiFi when GPS unavailable
    // - Dart side uses LocationData.recommendedH3Resolution to assign appropriate tile sizes
    // - This approach prevents "stale" locations while maintaining battery efficiency
    private var currentMotionState = MotionState.UNKNOWN
    private var currentGpsPriority = LocationRequest.PRIORITY_HIGH_ACCURACY

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        // Initialize Monitors
        batteryMonitor = BatteryStateMonitor(this) {
            // Flush FIFO buffers when battery drops low to avoid data loss
            Log.i(TAG, "Battery low - flushing FIFO buffers before pausing")
            flushSensorBuffers()
        }
        networkMonitor = NetworkStateMonitor(this)

        // Initialize Sensors
        lightSensor = LightSensor(sensorManager)
        barometer = Barometer(sensorManager)
        motionSensors = MotionSensors(sensorManager)

        // Create Notification Channel (Required for Android O+)
        NotificationsHelper.createNotificationChannel(this)

        trackingPausedState = readTrackingPausedPref()
        trackingPaused = trackingPausedState
        setupLocationCallback()
        setupSensorCollectors()
    }

    private fun setupLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "Location received: lat=${location.latitude}, lon=${location.longitude}, accuracy=${location.accuracy}m, provider=${location.provider}")
                    _locationFlow.value = location
                }
            }
        }
    }

    private fun setupSensorCollectors() {
        // Collect from sensor classes and update flows / send to Flutter
        coroutineScope.launch {
            lightSensor.dataFlow.collect { lux ->
                _lightFlow.value = lux
                lux?.let {
                    qualityAnalyzer.onLight(it)
                    sendLightToFlutter(it)
                }
            }
        }

        coroutineScope.launch {
            barometer.dataFlow.collect { hPa ->
                _pressureFlow.value = hPa
                hPa?.let { sendPressureToFlutter(it) }
            }
        }

        coroutineScope.launch {
            motionSensors.accelerometerFlow.collect { values ->
                _accelerometerFlow.value = values
                values?.let {
                    qualityAnalyzer.onAccelerometer(it)
                    sendAccelerometerToFlutter(it)
                }
            }
        }

        coroutineScope.launch {
            motionSensors.gyroscopeFlow.collect { values ->
                _gyroscopeFlow.value = values
                values?.let {
                    qualityAnalyzer.onGyroscope(it)
                    sendGyroscopeToFlutter(it)
                }
            }
        }

        coroutineScope.launch {
            _locationFlow.collect { location ->
                location?.let {
                    sendLocationToFlutter(it)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // CRITICAL FIX: Must call startForeground() within 5 seconds to avoid crash
        // Android 8+ requirement - call IMMEDIATELY before any other logic
        if (!running) {
            val lastUpload = NotificationsHelper.readLastUploadFromPrefs(this)
            val notification = NotificationsHelper.buildNotification(this, lastUpload, trackingPausedState)
            ServiceCompat.startForeground(
                this,
                NotificationsHelper.NOTIFICATION_ID_SERVICE,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                } else {
                    0
                }
            )
            Log.d(TAG, "startForeground() called immediately in onStartCommand to prevent crash")
        }

        // Handle explicit stop action
        if (intent?.action == ACTION_STOP_SERVICE) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        // Handle pause/resume actions
        if (intent?.action == ACTION_PAUSE_TRACKING) {
            pauseTracking()
            return START_STICKY
        }
        if (intent?.action == ACTION_RESUME_TRACKING) {
            resumeTracking()
            return START_STICKY
        }

        // Handle FIFO flush request
        if (intent?.action == ACTION_FLUSH_FIFO) {
            Log.i(TAG, "Received FIFO flush request from MainActivity")
            flushSensorBuffers()
            return START_STICKY
        }

        // Handle null intent (service restarted by system after being killed)
        if (intent == null) {
            Log.i(TAG, "Service restarted by system (null intent). Recreating state...")
            // Service was restarted by Android due to START_STICKY
            // All state is preserved in the Service object, just need to ensure it starts
        }

        startForegroundService()
        return START_STICKY
    }

    private fun startForegroundService() {
        if (running) return
        running = true
        setServiceEnabledPref(true)

        // Start Notification
        val lastUpload = NotificationsHelper.readLastUploadFromPrefs(this)
        val notification = NotificationsHelper.buildNotification(this, lastUpload, trackingPausedState)
        ServiceCompat.startForeground(
            this,
            NotificationsHelper.NOTIFICATION_ID_SERVICE,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else {
                0
            }
        )

        if (!trackingPausedState) {
            startTracking()
        } else {
            Log.i(TAG, "Tracking paused - sensors will remain stopped")
        }
    }

    private fun startTracking() {
        lightSensor.start()
        barometer.start()
        motionSensors.start()
        startLocationUpdates()

        Log.i(TAG, "Sensors started with FIFO batching (60s intervals)")

        // Start Native Uploader
        startNativeUploader()

        // Start Monitors
        batteryMonitor.startMonitoring()
        networkMonitor.startMonitoring()
    }

    private fun stopTracking() {
        flushSensorBuffers()
        lightSensor.stop()
        barometer.stop()
        motionSensors.stop()
        stopLocationUpdates()
        stopNativeUploader()
        batteryMonitor.stopMonitoring()
        networkMonitor.stopMonitoring()
    }

    private fun pauseTracking() {
        if (!running || trackingPausedState) return
        trackingPausedState = true
        trackingPaused = true
        setTrackingPausedPref(true)
        stopTracking()
        notifyTrackingState()
        sendTrackingPausedToFlutter(true)
        Log.i(TAG, "Tracking paused via notification")
    }

    private fun resumeTracking() {
        if (!running || !trackingPausedState) return
        trackingPausedState = false
        trackingPaused = false
        setTrackingPausedPref(false)
        startTracking()
        notifyTrackingState()
        sendTrackingPausedToFlutter(false)
        Log.i(TAG, "Tracking resumed via notification")
    }

    /**
     * Flush sensor FIFO buffers to get immediate data delivery.
     * Called when user opens app or before pausing due to low battery.
     */
    fun flushSensorBuffers() {
        lightSensor.flush()
        barometer.flush()
        motionSensors.flush()
        Log.d(TAG, "FIFO buffers flushed")
    }

    private fun stopForegroundService() {
        running = false
        trackingPausedState = false
        trackingPaused = false
        setServiceEnabledPref(false)
        setTrackingPausedPref(false)

        // Flush FIFO buffers before stopping to avoid losing last 60s of data
        stopTracking()

        stopForeground(true)
        stopSelf()
    }

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates(
        priority: Int = LocationRequest.PRIORITY_HIGH_ACCURACY,
        intervalMs: Long = LOCATION_UPDATES_INTERVAL_MS
    ) {
        val hasFine = PermissionChecker.checkSelfPermission(this, ACCESS_FINE_LOCATION) == PermissionChecker.PERMISSION_GRANTED
        val hasCoarse = PermissionChecker.checkSelfPermission(this, ACCESS_COARSE_LOCATION) == PermissionChecker.PERMISSION_GRANTED

        if (!hasFine && !hasCoarse) {
            Log.w(TAG, "No location permission")
            return
        }

        currentGpsPriority = priority

        val request = LocationRequest.create().apply {
            interval = intervalMs
            fastestInterval = intervalMs
            this.priority = priority
        }

        fusedLocationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
        Log.d(TAG, "GPS location updates started: priority=${getPriorityName(priority)}, interval=${intervalMs}ms")
    }

    /**
     * Update GPS interval based on motion state for battery optimization.
     * Always uses HIGH_ACCURACY to ensure fresh locations (not stale).
     * - STATIONARY: 60s interval (~50% battery savings, still fresh data)
     * - LIGHT/ACTIVE: 10s interval (better tracking when moving)
     *
     * Using intervals instead of priority changes ensures GPS gets fresh fixes
     * and network fallback works properly. Prevents "stale" location quality.
     */
    private fun intervalFor(state: MotionState): Long = when (state) {
        MotionState.STATIONARY -> 60_000L
        MotionState.LIGHT, MotionState.ACTIVE -> 10_000L
        MotionState.UNKNOWN -> LOCATION_UPDATES_INTERVAL_MS
    }

    @SuppressLint("MissingPermission")
    private fun updateGpsPriority(motionState: MotionState) {
        if (motionState == currentMotionState) return

        val newInterval = intervalFor(motionState)
        val currentInterval = intervalFor(currentMotionState)

        if (newInterval != currentInterval) {
            Log.i(TAG, "Motion state changed: ${currentMotionState.name} -> ${motionState.name}")
            Log.i(TAG, "Updating GPS interval: ${currentInterval}ms -> ${newInterval}ms (always HIGH_ACCURACY)")
            currentMotionState = motionState
            stopLocationUpdates()
            startLocationUpdates(LocationRequest.PRIORITY_HIGH_ACCURACY, newInterval)
        } else {
            currentMotionState = motionState
        }
    }

    private fun getCurrentLocationInterval(): Long = intervalFor(currentMotionState)

    private fun getPriorityName(priority: Int): String = when (priority) {
        LocationRequest.PRIORITY_HIGH_ACCURACY -> "HIGH_ACCURACY"
        LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY -> "BALANCED_POWER_ACCURACY"
        LocationRequest.PRIORITY_LOW_POWER -> "LOW_POWER"
        LocationRequest.PRIORITY_NO_POWER -> "NO_POWER"
        else -> "UNKNOWN($priority)"
    }

    private fun stopLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    private fun startNativeUploader() {
        if (nativeUploader == null) {
            nativeUploader = NativeBackendUploader(
                context = applicationContext,
                batteryMonitor = batteryMonitor,
                networkMonitor = networkMonitor,
                statusListener = ::handleNativeUploadStatus
            )
        }
        nativeUploader?.start()

        if (nativeSamplerJob?.isActive == true) return

        // Snapshot loop: captures sensor readings every 10 seconds
        //
        // How FIFO batching works with this loop:
        // - Sensors sample at ~200ms rate (hardware continues independently)
        // - Samples stored in hardware FIFO buffer
        // - CPU wakes every ~60s to receive batch of samples
        // - onSensorChanged() fires rapidly when batch arrives, updating flows
        // - This loop reads the LATEST value from flows every 10s
        //
        // Result: Same data quality, 6x fewer CPU wakeups = better battery
        nativeSamplerJob = coroutineScope.launch(Dispatchers.Default) {
            while (isActive) {
                delay(NATIVE_SAMPLE_INTERVAL_MS) // Wait first, then snapshot
                val snapshot = captureSensorSnapshot()
                if (snapshot != null) {
                    nativeUploader?.addReading(snapshot)
                }
            }
        }
    }

    private fun stopNativeUploader() {
        nativeSamplerJob?.cancel()
        nativeSamplerJob = null
        nativeUploader?.stop()
        nativeUploader = null
    }

    private fun captureSensorSnapshot(): SensorReading? {
        val light = _lightFlow.value
        val accelValues = _accelerometerFlow.value
        val gyroValues = _gyroscopeFlow.value
        val pressure = _pressureFlow.value
        val location = _locationFlow.value

        // Debug: Log what we're capturing
        Log.d(TAG, "Snapshot captured: light=$light, pressure=$pressure, accel=${accelValues != null}, gyro=${gyroValues != null}, location=${location != null}")

        val accel = accelValues?.takeIf { it.size >= 3 }?.let {
            AccelData(it[0], it[1], it[2])
        }
        val gyro = gyroValues?.takeIf { it.size >= 3 }?.let {
            GyroData(it[0], it[1], it[2])
        }
        val locationData = location?.let {
            LocationData(
                latitude = it.latitude,
                longitude = it.longitude,
                accuracy = if (it.hasAccuracy()) it.accuracy.toDouble() else null
            )
        }
        val quality = qualityAnalyzer.buildMetadata(location)

        // Adaptive GPS optimization: update GPS priority based on motion state
        quality?.motionState?.let { motionState ->
            updateGpsPriority(motionState)
        }

        if (light == null && accel == null && gyro == null && locationData == null) {
            return null
        }

        val reading = SensorReading(
            timestamp = System.currentTimeMillis(),
            light = light,
            accelerometer = accel,
            gyroscope = gyro,
            pressure = pressure,
            location = locationData,
            quality = quality
        )

        // Debug: Verify SensorReading was created with pressure
        Log.d(TAG, "SensorReading created: pressure=${reading.pressure}, light=${reading.light}")

        return reading
    }

    private fun handleNativeUploadStatus(event: NativeUploadStatusEvent) {
        Log.d(TAG, "Native upload: ${event.type}")
        sendNativeUploadStatusToFlutter(event)
        if (event.type == NativeUploadEventType.SUCCESS && ::notificationManager.isInitialized) {
            NotificationsHelper.notifyUpdate(this, notificationManager, event.timestamp, trackingPausedState)
        }
    }

    private fun sendNativeUploadStatusToFlutter(event: NativeUploadStatusEvent) {
        val status = when (event.type) {
            NativeUploadEventType.STARTED -> "started"
            NativeUploadEventType.SUCCESS -> "success"
            NativeUploadEventType.FAILURE -> "failure"
        }
        val payload = mutableMapOf<String, Any>(
            "status" to status,
            "timestamp" to event.timestamp,
            "batchSize" to event.batchSize,
            "bufferSize" to event.bufferSize
        )
        event.errorMessage?.let { payload["error"] = it }
        
        postToFlutter("native upload status") { it.invokeMethod("onNativeUploadStatus", payload) }
    }

    private fun sendLightToFlutter(lux: Float) {
        postToFlutter("light") { it.invokeMethod("onLightUpdate", mapOf("lux" to lux, "timestamp" to System.currentTimeMillis())) }
    }

    private fun sendAccelerometerToFlutter(values: FloatArray) {
        postToFlutter("accelerometer") { 
            it.invokeMethod("onAccelerometerUpdate", mapOf(
                "x" to values[0].toDouble(),
                "y" to values[1].toDouble(),
                "z" to values[2].toDouble(),
                "timestamp" to System.currentTimeMillis()
            )) 
        }
    }

    private fun sendGyroscopeToFlutter(values: FloatArray) {
        postToFlutter("gyroscope") { 
            it.invokeMethod("onGyroscopeUpdate", mapOf(
                "x" to values[0].toDouble(),
                "y" to values[1].toDouble(),
                "z" to values[2].toDouble(),
                "timestamp" to System.currentTimeMillis()
            )) 
        }
    }

    private fun sendPressureToFlutter(hPa: Float) {
        postToFlutter("pressure") {
            it.invokeMethod("onPressureUpdate", mapOf(
                "hPa" to hPa,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    private fun sendLocationToFlutter(location: Location) {
        postToFlutter("location") {
            it.invokeMethod("onLocationUpdate", mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
                "altitude" to if (location.hasAltitude()) location.altitude else null,
                "speed" to if (location.hasSpeed()) location.speed.toDouble() else null,
                "bearing" to if (location.hasBearing()) location.bearing.toDouble() else null,
                "timestamp" to System.currentTimeMillis(),
                "provider" to location.provider
            ))
        }
    }

    private fun postToFlutter(tag: String, block: (MethodChannel) -> Unit) {
        val channel = methodChannel ?: return
        // Use Main Looper to invoke method channel
        android.os.Handler(Looper.getMainLooper()).post {
            try {
                block(channel)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending $tag to Flutter", e)
            }
        }
    }

    private fun setServiceEnabledPref(enabled: Boolean) {
        val prefs = getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(AppPrefs.FOREGROUND_ENABLED, enabled).apply()
    }

    private fun setTrackingPausedPref(paused: Boolean) {
        val prefs = getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(AppPrefs.TRACKING_PAUSED, paused).apply()
    }

    private fun readTrackingPausedPref(): Boolean {
        val prefs = getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(AppPrefs.TRACKING_PAUSED, false)
    }

    private fun notifyTrackingState() {
        if (!::notificationManager.isInitialized) return
        val lastUpload = NotificationsHelper.readLastUploadFromPrefs(this)
        NotificationsHelper.notifyUpdate(this, notificationManager, lastUpload, trackingPausedState)
    }

    private fun sendTrackingPausedToFlutter(paused: Boolean) {
        postToFlutter("tracking paused") { it.invokeMethod("onTrackingPaused", paused) }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForegroundService()
        coroutineScope.coroutineContext.cancelChildren()
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    companion object {
        private const val TAG = "GreenGainsFGService"
        // Align GPS interval to snapshot interval (10s) - saves 90% GPS battery with zero data loss
        private val LOCATION_UPDATES_INTERVAL_MS = 10.seconds.inWholeMilliseconds
        private const val NATIVE_SAMPLE_INTERVAL_MS = 10_000L
        const val ACTION_STOP_SERVICE = "com.eremat.greengains.action.STOP_SERVICE"
        const val ACTION_PAUSE_TRACKING = "com.eremat.greengains.action.PAUSE_TRACKING"
        const val ACTION_RESUME_TRACKING = "com.eremat.greengains.action.RESUME_TRACKING"
        const val ACTION_FLUSH_FIFO = "com.eremat.greengains.action.FLUSH_FIFO"
        @Volatile var running: Boolean = false
        @Volatile var trackingPaused: Boolean = false
        @Volatile var methodChannel: MethodChannel? = null
    }
}
