package com.eremat.greengains.service

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.sqrt

/** A smoothed position. Deliberately carries no accuracy: see [PositionFilter]. */
data class FilteredPosition(val latitude: Double, val longitude: Double)

/**
 * Accuracy-weighted position filter (a Kalman filter on an isotropic 2-D random walk).
 *
 * Why: Android reports each fix's `accuracy` as the radius of the circle holding the true
 * position with 68 % probability. For an isotropic 2-D Gaussian error that radius is
 * sigma * sqrt(-2 ln(1 - 0.68)) = 1.51 sigma (the Rayleigh distribution), so the per-axis standard
 * deviation is accuracy / 1.51, NOT the accuracy itself. That makes it directly usable as a
 * measurement variance, so a 5 m fix outweighs a 100 m one instead of the two simply replacing
 * each other. It matters most when
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
        /** Confidence level Android documents for `Location.getAccuracy()`. */
        const val ACCURACY_CONFIDENCE = 0.68

        /**
         * Per-axis sigma per metre of reported accuracy. For 2-D isotropic Gaussian error the
         * radius holding probability p is sigma * sqrt(-2 ln(1 - p)) (Rayleigh), so this is
         * 1 / sqrt(-2 ln(1 - 0.68)) = 0.662. Derived from the documented definition, not tuned.
         */
        val SIGMA_PER_ACCURACY: Double = 1.0 / sqrt(-2.0 * ln(1.0 - ACCURACY_CONFIDENCE))

        /**
         * HEURISTIC, not derived: reported accuracy is clamped up to this. A fix claiming 0-2 m is
         * not trusted blindly. GPS.gov quotes about 5 m as typical smartphone open-sky accuracy
         * (confidence level not stated on the page), which is the right order of magnitude.
         */
        const val MIN_ACCURACY_M = 3.0

        /** HEURISTIC: used when a fix carries no accuracy at all. Deliberately pessimistic. */
        const val UNKNOWN_ACCURACY_M = 100.0

        /** HEURISTIC: assumed drift speed of a phone the motion sensors say is stationary. */
        const val STATIONARY_SPEED_MPS = 0.2

        /** Assumed speed when moving but the fix has no Doppler speed: preferred walking speed, ~1.4 m/s (5 km/h). */
        const val DEFAULT_MOVING_SPEED_MPS = 1.4

        /**
         * Probability that an honest fix (noise only, no real move) is wrongly treated as a move
         * and restarts the filter. Gate on the squared normalised innovation: with per-axis
         * variance S it is chi-square with 2 degrees of freedom, whose tail is exp(-x / 2), so
         * the threshold is x = -2 ln(alpha). This is a risk the designer chooses, stated as a
         * probability instead of a bare "3 sigma" (which is the same thing, alpha = 1.1 %).
         */
        const val FALSE_RESTART_PROBABILITY = 0.01

        private val GATE_CHI2 = -2.0 * ln(FALSE_RESTART_PROBABILITY)

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

        val accuracy = (accuracyM?.takeIf { it.isFinite() && it > 0.0 } ?: UNKNOWN_ACCURACY_M)
            .coerceAtLeast(MIN_ACCURACY_M)
        val sigma = accuracy * SIGMA_PER_ACCURACY
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
        if (innovation * innovation > GATE_CHI2 * (predictedVariance + measurementVariance)) {
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
