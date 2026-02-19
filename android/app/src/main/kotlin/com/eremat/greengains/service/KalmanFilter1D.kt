package com.eremat.greengains.service

/**
 * Minimal 1-dimensional Kalman filter for slowly-varying scalar sensors (e.g. barometric pressure).
 *
 * The Kalman filter is the statistically optimal estimator for linear systems with Gaussian noise.
 * It balances trust between the process model (how fast the true value changes) and the
 * measurement (how noisy the sensor is), adapting in real time.
 *
 * Tuned for barometric pressure from MEMS sensors (Bosch BME280 class):
 *   Q = 0.001  — process noise: pressure changes slowly (~0.1–1 hPa/hr for weather)
 *   R = 0.04   — measurement noise variance (~0.2 hPa RMS per BME280 datasheet, R = σ²)
 *
 * @param processNoise     Q — variance of how fast the true value can change. Lower = smoother
 *                         but slower to track real changes (e.g. entering a building).
 * @param measurementNoise R — sensor noise variance. Higher = less trust in raw readings.
 */
class KalmanFilter1D(
    private val processNoise: Double,
    private val measurementNoise: Double
) {
    private var estimate = Double.NaN
    private var errorCovariance = 1.0

    val isInitialized: Boolean get() = !estimate.isNaN()

    /**
     * Feed a new measurement. Returns the filtered (optimal) estimate.
     * On first call, returns the measurement unchanged (cold-start).
     */
    fun update(measurement: Double): Double {
        if (!isInitialized) {
            estimate = measurement
            return estimate
        }
        // Predict: uncertainty grows by process noise each step
        errorCovariance += processNoise

        // Update: blend prediction and measurement weighted by their uncertainties
        val gain = errorCovariance / (errorCovariance + measurementNoise)
        estimate += gain * (measurement - estimate)
        errorCovariance *= (1.0 - gain)

        return estimate
    }

    fun reset() {
        estimate = Double.NaN
        errorCovariance = 1.0
    }

    companion object {
        /** Pre-tuned instance for barometric pressure (MEMS barometer, hPa units). */
        fun forPressure() = KalmanFilter1D(processNoise = 0.001, measurementNoise = 0.04)
    }
}
