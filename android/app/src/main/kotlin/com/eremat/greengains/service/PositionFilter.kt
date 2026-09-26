package com.eremat.greengains.service

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sqrt

/** A smoothed position. Deliberately carries no accuracy: see [PositionFilter]. */
data class FilteredPosition(val latitude: Double, val longitude: Double)

/**
 * Accuracy-weighted position filter (a Kalman filter on an isotropic 2-D random walk).
 *
 * Why: Android reports each fix's `accuracy` as the radius of 68 % confidence, i.e. about one
 * standard deviation. That makes it directly usable as a measurement variance, so a 5 m fix
 * outweighs a 100 m one instead of the two simply replacing each other. It matters most when
 * the phone is stationary: the app drops to a coarse network-based provider (~50-150 m) to save
 * battery, and without a filter every coarse fix overwrites a previous good one, so the stored
 * position wanders inside a ~174 m hexagon and can flip between neighbouring cells.
 *
 * The filter works in a local metric frame (metres east/north of the first fix), which is exact
 * enough over the distances involved and avoids degree-scaling errors.
 *
 * It returns a position only, never an accuracy. GPS errors are strongly correlated in time
 * (multipath and atmospheric error persist), so successive fixes do not average down like
 * independent samples and a filter-derived accuracy would be over-confident. Callers keep the
 * raw fix's accuracy, so every downstream quality threshold behaves exactly as before.
 *
 * Pure Kotlin on purpose, so it can be unit-tested on the JVM without Android.
 */
class PositionFilter {
    companion object {
        /** Reported accuracy is clamped up to this: a fix claiming 0-2 m is not trusted blindly. */
        const val MIN_SIGMA_M = 3.0

        /** Used when a fix carries no accuracy at all. Deliberately pessimistic. */
        const val UNKNOWN_SIGMA_M = 100.0

        /**
         * Assumed drift speed of a phone the motion sensors say is stationary: small movements
         * while sitting or standing, not a real displacement.
         */
        const val STATIONARY_SPEED_MPS = 0.2

        /** Assumed speed when moving but the fix has no Doppler speed: ordinary walking, 5 km/h. */
        const val DEFAULT_MOVING_SPEED_MPS = 1.4

        /**
         * A new fix further than this many predicted standard deviations from the estimate is a
         * genuine move (or a wrong "stationary" flag), not noise: the filter restarts on it
         * instead of dragging toward it over several updates. 3 sigma gives ~1 % false restarts
         * for Gaussian 2-D error.
         */
        const val GATE_SIGMAS = 3.0

        private const val METRES_PER_DEG_LAT = 111_320.0
    }

    private var refLat = 0.0
    private var refLon = 0.0
    private var metresPerDegLon = METRES_PER_DEG_LAT
    private var x = 0.0            // metres east of the reference point
    private var y = 0.0            // metres north of the reference point
    private var variance = -1.0    // m^2, isotropic; negative = not initialised
    private var lastTimeMs = 0L

    val isInitialized: Boolean get() = variance >= 0.0

    fun reset() {
        variance = -1.0
        lastTimeMs = 0L
    }

    /**
     * @param accuracyM  the fix's reported accuracy (68 % radius), or null if unknown
     * @param timeMs     fix time in epoch ms, used only to size the prediction step
     * @param speedMps   Doppler speed from the fix if it has one
     * @param stationary whether the motion sensors currently report the phone as stationary
     */
    fun update(
        latitude: Double,
        longitude: Double,
        accuracyM: Double?,
        timeMs: Long,
        speedMps: Double?,
        stationary: Boolean,
    ): FilteredPosition {
        val raw = FilteredPosition(latitude, longitude)
        if (!latitude.isFinite() || !longitude.isFinite()) {
            reset()
            return raw
        }

        val sigma = (accuracyM?.takeIf { it.isFinite() && it > 0.0 } ?: UNKNOWN_SIGMA_M)
            .coerceAtLeast(MIN_SIGMA_M)
        val measurementVariance = sigma * sigma

        if (!isInitialized) {
            start(latitude, longitude, measurementVariance, timeMs)
            return raw
        }

        val mx = (longitude - refLon) * metresPerDegLon
        val my = (latitude - refLat) * METRES_PER_DEG_LAT

        // Predict: uncertainty grows with how far the phone could have moved since last fix.
        val dtS = ((timeMs - lastTimeMs).coerceAtLeast(0L)) / 1000.0
        val speed = when {
            stationary -> STATIONARY_SPEED_MPS
            speedMps != null && speedMps.isFinite() && speedMps >= 0.0 -> maxOf(speedMps, STATIONARY_SPEED_MPS)
            else -> DEFAULT_MOVING_SPEED_MPS
        }
        val predictedVariance = variance + (speed * dtS) * (speed * dtS)
        lastTimeMs = timeMs

        // Gate: a fix this far from the estimate is a real move, not noise.
        val innovation = hypot(mx - x, my - y)
        if (innovation > GATE_SIGMAS * sqrt(predictedVariance + measurementVariance)) {
            start(latitude, longitude, measurementVariance, timeMs)
            return raw
        }

        // Update: weight the fix by its share of the total variance.
        val gain = predictedVariance / (predictedVariance + measurementVariance)
        x += gain * (mx - x)
        y += gain * (my - y)
        variance = (1.0 - gain) * predictedVariance

        return FilteredPosition(
            latitude = refLat + y / METRES_PER_DEG_LAT,
            longitude = refLon + x / metresPerDegLon,
        )
    }

    private fun start(latitude: Double, longitude: Double, measurementVariance: Double, timeMs: Long) {
        refLat = latitude
        refLon = longitude
        metresPerDegLon = METRES_PER_DEG_LAT * cos(latitude * PI / 180.0).coerceAtLeast(0.01)
        x = 0.0
        y = 0.0
        variance = measurementVariance
        lastTimeMs = timeMs
    }
}
