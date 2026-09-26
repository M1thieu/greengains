package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager
import android.util.Log

/**
 * Magnetometer — measures ambient magnetic field in µT (microtesla) on X/Y/Z axes.
 *
 * Use cases for GreenGains:
 *   - Full 3D orientation: combined with accelerometer gives yaw (compass heading),
 *     enabling complete roll/pitch/yaw for richer quality metadata.
 *   - Indoor/outdoor detection: indoor magnetic field is highly distorted by steel
 *     structures (>60–80 µT total vs ~25–65 µT outdoors). Elevated magnitude strongly
 *     suggests an indoor environment — valuable for environmental context tagging.
 *   - Environmental data point: magnetic anomalies near power lines, transformers, or
 *     industrial equipment are scientifically measurable and commercially interesting.
 *
 * Typical values:
 *   Earth's field: ~25–65 µT (varies by latitude)
 *   Near electronics: 100–500 µT
 *   Near power cables: 500+ µT
 *
 * Calibration: a magnetometer that needs calibration reports a biased field. Android says so
 * through SensorEvent.accuracy, and SENSOR_STATUS_UNRELIABLE is documented as "the values
 * returned by this sensor cannot be trusted, calibration is needed or the environment doesn't
 * allow readings". A biased field would corrupt the interference metric, so those events are
 * dropped.
 */
class Magnetometer(sensorManager: SensorManager) :
    BaseSensor<FloatArray>(sensorManager, Sensor.TYPE_MAGNETIC_FIELD, "GreenGainsMagnetometer") {

    // Fail-open guard: some devices never report a meaningful status (a constant 0). Filtering
    // on 0 there would delete every reading, so only start dropping once this device has shown
    // at least once that it can report something better than UNRELIABLE.
    private var deviceReportsStatus = false
    private var dropped = 0

    override fun processEvent(event: SensorEvent) {
        val reliable = event.accuracy > SensorManager.SENSOR_STATUS_UNRELIABLE
        if (reliable) deviceReportsStatus = true

        if (!reliable && deviceReportsStatus) {
            dropped++
            if (dropped == 1 || dropped % 100 == 0) {
                Log.i("GreenGainsMagnetometer", "Dropping uncalibrated readings (SENSOR_STATUS_UNRELIABLE), total=$dropped")
            }
            return
        }
        _dataFlow.value = event.values.clone()
    }
}
