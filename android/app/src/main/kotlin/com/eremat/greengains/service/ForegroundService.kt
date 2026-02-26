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
import com.eremat.greengains.models.MagneticData
import com.eremat.greengains.models.MotionState
import com.eremat.greengains.models.NativeUploadEventType
import com.eremat.greengains.models.NativeUploadStatusEvent
import com.eremat.greengains.models.SensorReading
import com.eremat.greengains.notification.NotificationsHelper
import com.eremat.greengains.util.AppPrefs
import com.eremat.greengains.service.sensors.Barometer
import com.eremat.greengains.service.sensors.LightSensor
import com.eremat.greengains.service.sensors.Magnetometer
import com.eremat.greengains.service.sensors.MotionSensors
import com.eremat.greengains.service.sensors.ProximitySensor
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
    private lateinit var proximitySensor: ProximitySensor
    private lateinit var magnetometer: Magnetometer

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

    // Temporal averaging windows — accumulate samples between snapshots, then average.
    // Reduces noise by ~√N (N = samples collected per window). Thread-safe via windowLock.
    private val windowLock = Any()
    private val lightWindow = mutableListOf<Float>()
    private val pressureWindow = mutableListOf<Float>()
    private val linearAccelWindow = mutableListOf<FloatArray>() // gravity-free
    private val gyroWindow = mutableListOf<FloatArray>()
    private val magneticWindow = mutableListOf<FloatArray>()

    // Kalman filter for barometric pressure — persists across snapshots, tracks real weather
    // changes while optimally suppressing MEMS sensor noise (tuned for BME280-class sensors).
    private val pressureKalman = KalmanFilter1D.forPressure()

    // Exponential moving average for the light sensor (α = 0.15).
    // Light sensors exhibit hardware-level hysteresis: when a light source is removed, the
    // lux reading decays gradually (e.g. 200 → 20 → 1 over ~3 s) rather than snapping to the
    // new level. Without smoothing, the decay tail inflates the window average.
    // α = 0.15 responds to genuine scene changes in ~5 samples (~1 s at 5 Hz) while attenuating
    // transient decay spikes. Null until first reading so cold start doesn't bias the filter.
    private var lightEma: Float? = null

    // GPS jump detection — track last physically-plausible location to reject multipath glitches.
    private var lastAcceptedLocation: Location? = null

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
        proximitySensor = ProximitySensor(sensorManager)
        magnetometer = Magnetometer(sensorManager)

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
                    val prev = lastAcceptedLocation
                    if (prev != null) {
                        val dtMs = location.time - prev.time
                        val distM = prev.distanceTo(location)
                        // Reject physically impossible jumps: > 300 m/s (1080 km/h) is a GPS glitch.
                        // Legitimate fast travel (highway, train) is well under this threshold.
                        val speedMs = if (dtMs > 0) distM / (dtMs / 1000.0) else 0.0
                        if (speedMs > MAX_PLAUSIBLE_SPEED_MS) {
                            Log.w(TAG, "GPS jump rejected: ${speedMs.toInt()} m/s from (${prev.latitude},${prev.longitude}) to (${location.latitude},${location.longitude})")
                            return@let
                        }
                    }
                    lastAcceptedLocation = location
                    Log.d(TAG, "Location accepted: lat=${location.latitude}, lon=${location.longitude}, accuracy=${location.accuracy}m, provider=${location.provider}")
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
                    // Only accumulate light samples when the phone is not face-down or in a pocket.
                    // Occluded readings (0 lux) are physically invalid for ambient light mapping.
                    if (!qualityAnalyzer.isLightObscured()) {
                        // Apply EMA before window accumulation to attenuate sensor hysteresis /
                        // decay tails (e.g. 200→20→1 lux after a light switches off).
                        val ema = lightEma?.let { prev -> 0.85f * prev + 0.15f * it } ?: it
                        lightEma = ema
                        synchronized(windowLock) { lightWindow.add(ema) }
                    }
                }
            }
        }

        coroutineScope.launch {
            barometer.dataFlow.collect { hPa ->
                _pressureFlow.value = hPa
                hPa?.let {
                    sendPressureToFlutter(it)
                    synchronized(windowLock) { pressureWindow.add(it) }
                }
            }
        }

        // Raw accelerometer: kept for quality analyzer (motion/orientation detection needs gravity)
        coroutineScope.launch {
            motionSensors.accelerometerFlow.collect { values ->
                _accelerometerFlow.value = values
                values?.let {
                    qualityAnalyzer.onAccelerometer(it)
                    sendAccelerometerToFlutter(it)
                }
            }
        }

        // Linear acceleration (gravity-free): collected for upload window
        coroutineScope.launch {
            motionSensors.linearAccelerationFlow.collect { values ->
                values?.let {
                    synchronized(windowLock) { linearAccelWindow.add(it.clone()) }
                }
            }
        }

        coroutineScope.launch {
            motionSensors.gyroscopeFlow.collect { values ->
                _gyroscopeFlow.value = values
                values?.let {
                    qualityAnalyzer.onGyroscope(it)
                    sendGyroscopeToFlutter(it)
                    synchronized(windowLock) { gyroWindow.add(it.clone()) }
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

        // Proximity: real-time pocket detection signal — feed directly to quality analyzer
        coroutineScope.launch {
            proximitySensor.dataFlow.collect { near ->
                near?.let { qualityAnalyzer.onProximity(it) }
            }
        }

        // Magnetometer: raw magnetic field data — accumulated for averaging + streamed to Flutter
        coroutineScope.launch {
            magnetometer.dataFlow.collect { values ->
                values?.let {
                    synchronized(windowLock) { magneticWindow.add(it.clone()) }
                    sendMagneticFieldToFlutter(it)
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

        // Handle pause/resume actions.
        // If the service was killed while paused and restarted via notification,
        // `running` is still false here — ensure it's initialised before delegating.
        if (intent?.action == ACTION_PAUSE_TRACKING) {
            if (!running) startForegroundService()
            pauseTracking()
            return START_STICKY
        }
        if (intent?.action == ACTION_RESUME_TRACKING) {
            if (!running) startForegroundService()
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
        proximitySensor.start()
        magnetometer.start()
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
        proximitySensor.stop()
        magnetometer.stop()
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
        magnetometer.flush()
        // ProximitySensor is a wakeup sensor — no FIFO to flush
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
     * Update GPS priority AND interval based on motion state.
     *
     * STATIONARY → BALANCED_POWER_ACCURACY (cell+WiFi, ~50-150m) at 60s
     *   - Drops GPS chip entirely, uses cell towers + WiFi for positioning
     *   - ~70% battery reduction vs HIGH_ACCURACY with negligible data quality loss:
     *     stationary users stay in the same neighborhood H3 cell regardless of 50m vs 5m precision
     *   - Geohash precision adapts automatically (≤200m → precision 5, still valid for aggregation)
     *
     * LIGHT/ACTIVE → HIGH_ACCURACY (GPS+WiFi+cell) at 10-30s
     *   - Full GPS precision when user is moving and spatial diversity matters
     *   - Transition back from STATIONARY is fast: first accelerometer spike triggers upgrade
     */
    private fun gpsConfigFor(state: MotionState): Pair<Int, Long> = when (state) {
        MotionState.STATIONARY -> LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY to 60_000L
        MotionState.LIGHT      -> LocationRequest.PRIORITY_HIGH_ACCURACY to 30_000L
        MotionState.ACTIVE     -> LocationRequest.PRIORITY_HIGH_ACCURACY to 10_000L
        MotionState.UNKNOWN    -> LocationRequest.PRIORITY_HIGH_ACCURACY to LOCATION_UPDATES_INTERVAL_MS
    }

    @SuppressLint("MissingPermission")
    private fun updateGpsPriority(motionState: MotionState) {
        if (motionState == currentMotionState) return

        val (newPriority, newInterval) = gpsConfigFor(motionState)
        val (curPriority, curInterval) = gpsConfigFor(currentMotionState)

        if (newPriority != curPriority || newInterval != curInterval) {
            Log.i(TAG, "Motion: ${currentMotionState.name} → ${motionState.name} | GPS: ${getPriorityName(curPriority)}@${curInterval}ms → ${getPriorityName(newPriority)}@${newInterval}ms")
            currentMotionState = motionState
            stopLocationUpdates()
            startLocationUpdates(newPriority, newInterval)
        } else {
            currentMotionState = motionState
        }
    }

    private fun getCurrentLocationInterval(): Long = gpsConfigFor(currentMotionState).second

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

        // Snapshot loop: averages accumulated sensor samples at an adaptive interval.
        //
        // How temporal averaging + FIFO work together:
        // - Hardware sensors sample at ~200ms via FIFO (no CPU wakeup cost)
        // - Each sample is added to a window accumulator as it arrives
        // - This loop fires at an adaptive interval based on motion state:
        //     STATIONARY → 60s  (1 reading/min, ~300 samples averaged → ~17x noise reduction)
        //     LIGHT      → 30s  (1 reading/30s, ~150 samples averaged → ~12x noise reduction)
        //     ACTIVE     → 15s  (1 reading/15s, ~75 samples averaged → ~9x noise reduction)
        // - Each snapshot drains + averages the window, then clears it
        //
        // DB impact vs previous 10s single-sample: 1.5–6x fewer rows, better SNR
        nativeSamplerJob = coroutineScope.launch(Dispatchers.Default) {
            var intervalMs = NATIVE_SAMPLE_INTERVAL_ACTIVE_MS
            while (isActive) {
                delay(intervalMs)
                val snapshot = captureSensorSnapshot()
                if (snapshot != null) {
                    nativeUploader?.addReading(snapshot)
                }
                intervalMs = when (currentMotionState) {
                    MotionState.STATIONARY -> NATIVE_SAMPLE_INTERVAL_STATIONARY_MS
                    MotionState.LIGHT      -> NATIVE_SAMPLE_INTERVAL_LIGHT_MS
                    else                   -> NATIVE_SAMPLE_INTERVAL_ACTIVE_MS
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
        // Drain accumulators atomically, apply outlier rejection, then average.
        val rawLight: List<Float>
        val rawPressure: List<Float>
        val rawLinearAccel: List<FloatArray>
        val rawGyro: List<FloatArray>
        val rawMagnetic: List<FloatArray>

        synchronized(windowLock) {
            rawLight       = lightWindow.toList()
            rawPressure    = pressureWindow.toList()
            rawLinearAccel = linearAccelWindow.map { it.clone() }
            rawGyro        = gyroWindow.map { it.clone() }
            rawMagnetic    = magneticWindow.map { it.clone() }
            lightWindow.clear()
            pressureWindow.clear()
            linearAccelWindow.clear()
            gyroWindow.clear()
            magneticWindow.clear()
        }

        // IQR outlier rejection — removes sensor glitches before averaging.
        // Tukey's method (Q1 - 1.5*IQR, Q3 + 1.5*IQR): textbook robust statistics.
        val cleanLight    = rejectOutliersFloat(rawLight)
        val cleanPressure = rejectOutliersFloat(rawPressure)
        val cleanAccel    = rejectOutliersVectors(rawLinearAccel)
        val cleanGyro     = rejectOutliersVectors(rawGyro)
        val cleanMagnetic = rejectOutliersVectors(rawMagnetic)

        val sampleCount = maxOf(cleanLight.size, cleanPressure.size, cleanAccel.size, 1)

        // Light: plain average of non-occluded, outlier-filtered samples
        val light = if (cleanLight.isNotEmpty()) cleanLight.average().toFloat() else _lightFlow.value

        // Pressure: average first, then feed through Kalman filter for optimal smoothing.
        // The Kalman estimate tracks real weather changes while suppressing MEMS noise.
        val rawPressureAvg = if (cleanPressure.isNotEmpty()) cleanPressure.average() else null
        val pressure = rawPressureAvg?.let { pressureKalman.update(it).toFloat() }
            ?: if (pressureKalman.isInitialized) null else _pressureFlow.value

        // Motion: prefer gravity-free linear accel; fall back to raw if sensor unavailable
        val avgAccel = averageFloatArrayWindow(cleanAccel)
            ?: _accelerometerFlow.value?.let { floatArrayOf(it[0], it[1], it[2]) }
        val avgGyro  = averageFloatArrayWindow(cleanGyro)
            ?: _gyroscopeFlow.value?.let { floatArrayOf(it[0], it[1], it[2]) }

        val location = _locationFlow.value
        Log.d(TAG, "Snapshot: n=$sampleCount samples, motion=${currentMotionState.name}, light=$light, pressure=$pressure")

        // Magnetometer: average cleaned window, compute magnitude
        val avgMagnetic = averageFloatArrayWindow(cleanMagnetic)
        val magnetic = avgMagnetic?.takeIf { it.size >= 3 }?.let { m ->
            val mag = kotlin.math.sqrt((m[0] * m[0] + m[1] * m[1] + m[2] * m[2]).toDouble()).toFloat()
            MagneticData(x = m[0], y = m[1], z = m[2], magnitude = mag)
        }

        val accel = avgAccel?.takeIf { it.size >= 3 }?.let { AccelData(it[0], it[1], it[2]) }
        val gyro  = avgGyro?.takeIf  { it.size >= 3 }?.let { GyroData(it[0], it[1], it[2]) }
        val locationData = location?.let {
            LocationData(
                latitude  = it.latitude,
                longitude = it.longitude,
                accuracy  = if (it.hasAccuracy()) it.accuracy.toDouble() else null
            )
        }
        val quality = qualityAnalyzer.buildMetadata(location)?.copy(sampleCount = sampleCount)
        quality?.motionState?.let { updateGpsPriority(it) }

        if (light == null && accel == null && gyro == null && locationData == null) return null

        return SensorReading(
            timestamp     = System.currentTimeMillis(),
            light         = light,
            accelerometer = accel,
            gyroscope     = gyro,
            pressure      = pressure,
            location      = locationData,
            quality       = quality,
            magneticField = magnetic
        )
    }

    /**
     * Tukey IQR outlier rejection for scalar sensor windows.
     * Removes values outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR]. Returns input unchanged if < 4 samples.
     */
    private fun rejectOutliersFloat(values: List<Float>): List<Float> {
        if (values.size < 4) return values
        val sorted = values.sorted()
        val q1 = sorted[sorted.size / 4]
        val q3 = sorted[sorted.size * 3 / 4]
        val iqr = q3 - q1
        if (iqr == 0f) return values
        val lo = q1 - 1.5f * iqr
        val hi = q3 + 1.5f * iqr
        return values.filter { it in lo..hi }
    }

    /**
     * Tukey IQR outlier rejection for vector sensor windows (accel, gyro).
     * Uses vector magnitude for outlier scoring; retains or rejects the full vector.
     */
    private fun rejectOutliersVectors(vectors: List<FloatArray>): List<FloatArray> {
        if (vectors.size < 4) return vectors
        val magnitudes = vectors.map { arr ->
            kotlin.math.sqrt(arr[0] * arr[0] + arr[1] * arr[1] + arr[2] * arr[2])
        }
        val sorted = magnitudes.sorted()
        val q1 = sorted[sorted.size / 4]
        val q3 = sorted[sorted.size * 3 / 4]
        val iqr = q3 - q1
        if (iqr == 0f) return vectors
        val lo = q1 - 1.5f * iqr
        val hi = q3 + 1.5f * iqr
        return vectors.filterIndexed { i, _ -> magnitudes[i] in lo..hi }
    }

    /** Average a list of same-length FloatArrays component-wise. Returns null if empty. */
    private fun averageFloatArrayWindow(window: List<FloatArray>): FloatArray? {
        if (window.isEmpty()) return null
        val dims = window[0].size
        val sum = FloatArray(dims)
        for (arr in window) for (i in 0 until minOf(dims, arr.size)) sum[i] += arr[i]
        val n = window.size.toFloat()
        return FloatArray(dims) { i -> sum[i] / n }
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

    private fun sendMagneticFieldToFlutter(values: FloatArray) {
        val mag = kotlin.math.sqrt((values[0] * values[0] + values[1] * values[1] + values[2] * values[2]).toDouble())
        postToFlutter("magnetic") {
            it.invokeMethod("onMagneticFieldUpdate", mapOf(
                "x"         to values[0].toDouble(),
                "y"         to values[1].toDouble(),
                "z"         to values[2].toDouble(),
                "magnitude" to mag,
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
        private val LOCATION_UPDATES_INTERVAL_MS = 10.seconds.inWholeMilliseconds
        // Adaptive snapshot intervals — motion state drives how often we flush the averaging window.
        // More samples per window = better SNR. Fewer snapshots = fewer DB rows.
        private const val NATIVE_SAMPLE_INTERVAL_STATIONARY_MS = 60_000L // ~300 samples → ~17x noise reduction
        private const val NATIVE_SAMPLE_INTERVAL_LIGHT_MS      = 30_000L // ~150 samples → ~12x noise reduction
        private const val NATIVE_SAMPLE_INTERVAL_ACTIVE_MS     = 15_000L // ~75  samples → ~9x  noise reduction
        // GPS jump detection: reject locations implying speed > 300 m/s (1080 km/h).
        // Handles GPS multipath teleportation; well above any realistic travel speed.
        private const val MAX_PLAUSIBLE_SPEED_MS = 300.0
        const val ACTION_STOP_SERVICE = "com.eremat.greengains.action.STOP_SERVICE"
        const val ACTION_PAUSE_TRACKING = "com.eremat.greengains.action.PAUSE_TRACKING"
        const val ACTION_RESUME_TRACKING = "com.eremat.greengains.action.RESUME_TRACKING"
        const val ACTION_FLUSH_FIFO = "com.eremat.greengains.action.FLUSH_FIFO"
        @Volatile var running: Boolean = false
        @Volatile var trackingPaused: Boolean = false
        @Volatile var methodChannel: MethodChannel? = null
    }
}
