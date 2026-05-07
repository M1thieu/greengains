package com.eremat.greengains.models

/**
 * Domain models shared between ForegroundService and NativeBackendUploader.
 *
 * Extracted from NativeBackendUploader.kt to keep models separate from upload logic.
 */

// ── Sensor reading (one 10-second snapshot) ──────────────────────────────────

data class SensorReading(
    val timestamp: Long,
    val light: Float?,
    val accelerometer: AccelData?,
    val gyroscope: GyroData?,
    val pressure: Float?,
    val location: LocationData?,
    val quality: QualityMetadata?,
    val magneticField: MagneticData? = null
)

data class AccelData(val x: Float, val y: Float, val z: Float)
data class GyroData(val x: Float, val y: Float, val z: Float)

/**
 * Raw magnetometer reading in µT (microtesla).
 * magnitude = √(x² + y² + z²) — pre-computed for upload efficiency.
 * Elevated magnitude (>80 µT) suggests indoor environment or nearby metal/electronics.
 */
data class MagneticData(
    val x: Float,
    val y: Float,
    val z: Float,
    val magnitude: Float
)

data class LocationData(
    val latitude: Double,
    val longitude: Double,
    val accuracy: Double?
)

// ── Quality metadata ─────────────────────────────────────────────────────────

data class QualityMetadata(
    val orientation: OrientationState = OrientationState.UNKNOWN,
    val tiltDegrees: Float? = null,
    val motionState: MotionState = MotionState.UNKNOWN,
    val motionConfidence: Float = 0f,
    val pocketState: PocketState = PocketState.UNKNOWN,
    val locationQuality: LocationQuality = LocationQuality.NONE,
    /** Number of raw sensor samples averaged into this reading. Higher = more reliable. */
    val sampleCount: Int = 1,
    /**
     * True = proximity sensor reports NEAR (hand/pocket/face within ~5 cm).
     * Null = proximity sensor not available on this device.
     * More reliable than light+tilt heuristic for pocket detection.
     */
    val proximityNear: Boolean? = null,
    /**
     * Composite data quality score [0.0, 1.0] — higher = more trustworthy reading.
     * Factored from: GPS accuracy, location quality tier, pocket state, motion confidence.
     * Null = not yet computed (older readings before this field was added).
     */
    val precisionScore: Float? = null
)

enum class OrientationState {
    FACE_UP,
    FACE_DOWN,
    UPRIGHT_PORTRAIT,
    UPRIGHT_LANDSCAPE,
    UPRIGHT_UNKNOWN,
    UNKNOWN
}

enum class MotionState {
    UNKNOWN,
    STATIONARY,
    LIGHT,
    ACTIVE
}

enum class PocketState {
    UNKNOWN,
    LIKELY,
    UNLIKELY
}

enum class LocationQuality {
    NONE,
    STALE,
    HIGH,
    MEDIUM,
    LOW,
    POOR
}

// ── Upload status events ──────────────────────────────────────────────────────

enum class NativeUploadEventType {
    STARTED,
    SUCCESS,
    FAILURE
}

data class NativeUploadStatusEvent(
    val type: NativeUploadEventType,
    val timestamp: Long = System.currentTimeMillis(),
    val batchSize: Int = 0,
    val bufferSize: Int = 0,
    val errorMessage: String? = null
)

fun interface NativeUploadStatusListener {
    fun onStatus(event: NativeUploadStatusEvent)
}
