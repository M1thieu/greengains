package com.eremat.greengains.service

import android.location.Location
import com.eremat.greengains.models.LocationQuality
import com.eremat.greengains.models.MotionState
import com.eremat.greengains.models.OrientationState
import com.eremat.greengains.models.PocketState
import com.eremat.greengains.models.QualityMetadata
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Analyses ambient sensor data to produce quality metadata for each snapshot.
 *
 * Tracks a rolling window of accelerometer samples to classify motion state,
 * derive orientation, detect pocket placement, and assess location quality.
 */
internal class SensorQualityAnalyzer {
    private data class MotionSample(val timestamp: Long, val magnitude: Float)
    private data class OrientationInfo(
        val state: OrientationState = OrientationState.UNKNOWN,
        val tiltDegrees: Float? = null
    )

    private val accelSamples = ArrayDeque<MotionSample>()
    private val gyroSamples  = ArrayDeque<MotionSample>()
    private var lastProximityNear: Boolean? = null
    private val gravityVector = FloatArray(3)
    private var gravityInitialized = false
    private var lastLux: Float? = null

    fun onLight(lux: Float) = synchronized(this) {
        lastLux = lux
    }

    fun onProximity(near: Boolean) = synchronized(this) {
        lastProximityNear = near
    }

    fun onAccelerometer(values: FloatArray) = synchronized(this) {
        val now = System.currentTimeMillis()
        updateGravity(values)
        accelSamples.addLast(MotionSample(now, magnitude(values)))
        trimOld(now)
    }

    fun onGyroscope(values: FloatArray) = synchronized(this) {
        val now = System.currentTimeMillis()
        gyroSamples.addLast(MotionSample(now, magnitude(values)))
        while (gyroSamples.isNotEmpty() && now - gyroSamples.first().timestamp > WINDOW_MS) {
            gyroSamples.removeFirst()
        }
    }

    /**
     * Returns true when the light sensor is obscured — phone is face-down or likely in a pocket.
     * Use this to gate light samples out of the averaging window at collection time.
     *
     * Detection priority (most reliable first):
     *   1. Proximity sensor NEAR → definitive (physical contact with pocket/face/surface)
     *   2. Orientation FACE_DOWN → definitive (gravity vector analysis)
     *   3. Low lux + upright tilt → heuristic (pocket without proximity sensor)
     */
    fun isLightObscured(): Boolean = synchronized(this) {
        // Proximity is a direct physical measurement — no false positives when NEAR
        if (lastProximityNear == true) return@synchronized true
        val orientationInfo = computeOrientation()
        if (orientationInfo.state == OrientationState.FACE_DOWN) return@synchronized true
        val lux = lastLux ?: return@synchronized false
        val tilt = orientationInfo.tiltDegrees ?: return@synchronized false
        lux < POCKET_LUX_THRESHOLD && tilt in POCKET_TILT_MIN..POCKET_TILT_MAX
    }

    fun buildMetadata(location: Location?): QualityMetadata = synchronized(this) {
        val orientationInfo = computeOrientation()
        val (motionState, motionConfidence) = classifyMotion(
            accelVariance = computeVariance(accelSamples),
            gyroRms = computeRms(gyroSamples)
        )
        val pocketState = determinePocketState(orientationInfo, lastLux, motionState)
        val locationQuality = determineLocationQuality(location)
        val precisionScore = computePrecisionScore(locationQuality, pocketState, location)

        return QualityMetadata(
            orientation = orientationInfo.state,
            tiltDegrees = orientationInfo.tiltDegrees,
            motionState = motionState,
            motionConfidence = motionConfidence,
            pocketState = pocketState,
            locationQuality = locationQuality,
            proximityNear = lastProximityNear,
            precisionScore = precisionScore
        )
    }

    private fun updateGravity(values: FloatArray) {
        if (!gravityInitialized) {
            gravityVector[0] = values[0]
            gravityVector[1] = values[1]
            gravityVector[2] = values[2]
            gravityInitialized = true
            return
        }
        gravityVector[0] = ALPHA * values[0] + (1 - ALPHA) * gravityVector[0]
        gravityVector[1] = ALPHA * values[1] + (1 - ALPHA) * gravityVector[1]
        gravityVector[2] = ALPHA * values[2] + (1 - ALPHA) * gravityVector[2]
    }

    private fun trimOld(now: Long) {
        while (accelSamples.isNotEmpty() && now - accelSamples.first().timestamp > WINDOW_MS) {
            accelSamples.removeFirst()
        }
    }

    private fun magnitude(values: FloatArray): Float {
        return sqrt(values[0] * values[0] + values[1] * values[1] + values[2] * values[2])
    }

    private fun computeOrientation(): OrientationInfo {
        if (!gravityInitialized) return OrientationInfo()
        val norm = magnitude(gravityVector)
        if (norm < 0.1f) return OrientationInfo()

        val gx = gravityVector[0] / norm
        val gy = gravityVector[1] / norm
        val gz = gravityVector[2] / norm

        val tiltRad = acos(max(-1f, min(1f, gz)).toDouble())
        val tiltDeg = Math.toDegrees(tiltRad).toFloat()

        val absGz = abs(gz)
        val absGx = abs(gx)
        val absGy = abs(gy)

        // Android accelerometer: z-axis points OUT of the screen.
        // Face-up (screen facing ceiling): gravity is +9.8 on z → gz ≈ +1
        // Face-down (screen facing floor): gravity is -9.8 on z → gz ≈ -1
        val state = when {
            gz >= FACE_THRESHOLD  -> OrientationState.FACE_UP
            gz <= -FACE_THRESHOLD -> OrientationState.FACE_DOWN
            absGz < UPRIGHT_THRESHOLD -> {
                when {
                    absGy - absGx > ORIENTATION_MARGIN -> OrientationState.UPRIGHT_PORTRAIT
                    absGx - absGy > ORIENTATION_MARGIN -> OrientationState.UPRIGHT_LANDSCAPE
                    else -> OrientationState.UPRIGHT_UNKNOWN
                }
            }
            else -> OrientationState.UNKNOWN
        }

        return OrientationInfo(state = state, tiltDegrees = tiltDeg)
    }

    private fun computeRms(samples: ArrayDeque<MotionSample>): Double {
        if (samples.isEmpty()) return 0.0
        return sqrt(samples.sumOf { it.magnitude.toDouble() * it.magnitude.toDouble() } / samples.size)
    }

    private fun computeVariance(samples: ArrayDeque<MotionSample>): Double {
        if (samples.size < 2) return 0.0
        val mean = samples.sumOf { it.magnitude.toDouble() } / samples.size
        return samples.sumOf {
            val diff = it.magnitude - mean
            (diff * diff)
        } / samples.size
    }

    private fun classifyMotion(
        accelVariance: Double,
        gyroRms: Double
    ): Pair<MotionState, Float> {
        if (accelSamples.isEmpty()) {
            return MotionState.UNKNOWN to 0f
        }
        // Fuse accel variance (primary) and gyro RMS (secondary, 30% weight).
        // Gyro catches subtle rotation that low-variance translation misses (e.g. slow pan).
        val accelRatio = (accelVariance / ACCEL_MOVING_VARIANCE).toFloat()
        val gyroRatio  = (gyroRms / GYRO_MOVING_RMS).toFloat()
        val confidence = (0.7f * accelRatio + 0.3f * gyroRatio).coerceIn(0f, 1f)

        val state = when {
            confidence < 0.2f -> MotionState.STATIONARY
            confidence < 0.6f -> MotionState.LIGHT
            else -> MotionState.ACTIVE
        }
        return state to confidence
    }

    private fun determinePocketState(
        orientationInfo: OrientationInfo,
        lux: Float?,
        motionState: MotionState
    ): PocketState {
        // Proximity available: use it as the primary authoritative signal.
        // NEAR + dark = definitive pocket; FAR = definitely not in pocket (dark room ≠ pocket).
        if (lastProximityNear != null) {
            return when {
                lastProximityNear == true -> PocketState.LIKELY
                // FACE_UP: gravity vector confirms screen faces the ceiling — physically
                // impossible to be in a pocket, regardless of lighting conditions.
                orientationInfo.state == OrientationState.FACE_UP -> PocketState.UNLIKELY
                lux != null && lux > BRIGHT_ENV_LUX -> PocketState.UNLIKELY
                else -> PocketState.UNKNOWN
            }
        }

        // No proximity sensor — fall back to lux+tilt heuristic.
        // This path fires on ~1% of modern phones without a proximity sensor.
        val tilt = orientationInfo.tiltDegrees
        if (lux == null || tilt == null) {
            return PocketState.UNKNOWN
        }

        return when {
            lux < POCKET_LUX_THRESHOLD &&
                tilt in POCKET_TILT_MIN..POCKET_TILT_MAX &&
                motionState != MotionState.ACTIVE -> PocketState.LIKELY
            lux > BRIGHT_ENV_LUX -> PocketState.UNLIKELY
            else -> PocketState.UNKNOWN
        }
    }

    /**
     * GPS precision score [0.0, 1.0] based solely on the reported horizontal accuracy.
     *
     * location.accuracy is Android's 68% confidence radius (1σ). Motion state and pocket
     * state are intentionally excluded — a runner's GPS fix is not spatially less valid
     * than a stationary person's. Only the GPS signal quality itself matters here.
     *
     * Formula: linear interpolation from 0m (score=1.0) to MAX_ACCEPT_M (score=0.0),
     * clamped. Any fix past the accuracy filter threshold is already excluded upstream.
     */
    private fun computePrecisionScore(
        locationQuality: LocationQuality,
        pocketState: PocketState,
        location: Location?
    ): Float? {
        if (locationQuality == LocationQuality.NONE || locationQuality == LocationQuality.STALE) return null
        val accuracy = location?.takeIf { it.hasAccuracy() }?.accuracy ?: return null
        // Linear decay: 0m → 1.0, MAX_ACCEPT_M → 0.0
        return (1f - accuracy / MAX_ACCEPTED_ACCURACY_M).coerceIn(0f, 1f)
    }

    private fun determineLocationQuality(location: Location?): LocationQuality {
        location ?: return LocationQuality.NONE
        val now = System.currentTimeMillis()
        if (now - location.time > STALE_LOCATION_MS) return LocationQuality.STALE
        return when {
            location.accuracy <= 25f -> LocationQuality.HIGH
            location.accuracy <= 75f -> LocationQuality.MEDIUM
            location.accuracy <= 200f -> LocationQuality.LOW
            else -> LocationQuality.POOR
        }
    }

    companion object {
        private const val WINDOW_MS = 10_000L
        private const val ALPHA = 0.1f
        private const val FACE_THRESHOLD = 0.7f
        private const val UPRIGHT_THRESHOLD = 0.4f
        private const val ORIENTATION_MARGIN = 0.15f
        private const val ACCEL_MOVING_VARIANCE = 0.5
        private const val GYRO_MOVING_RMS = 0.07
        private const val POCKET_LUX_THRESHOLD = 2f
        private const val BRIGHT_ENV_LUX = 15f
        private const val POCKET_TILT_MIN = 60f
        private const val POCKET_TILT_MAX = 120f
        private const val STALE_LOCATION_MS = 60_000L
        // Accuracy filter threshold — matches the upstream rejection gate in ForegroundService.
        // Stationary mode accepts up to 150m (BALANCED_POWER fix quality), active accepts 50m.
        // Using 150m here so the score is always computed even for stationary fixes.
        private const val MAX_ACCEPTED_ACCURACY_M = 150f
    }
}
