package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager

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
 */
class Magnetometer(sensorManager: SensorManager) :
    BaseSensor<FloatArray>(sensorManager, Sensor.TYPE_MAGNETIC_FIELD, "GreenGainsMagnetometer") {

    override fun processEvent(event: SensorEvent) {
        _dataFlow.value = event.values.clone()
    }
}
