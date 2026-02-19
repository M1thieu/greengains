package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager

/**
 * Proximity sensor — detects whether something is close to the device (near/far).
 *
 * Used for pocket detection: if the sensor reports NEAR while light is also dark,
 * the phone is almost certainly in a pocket. This is more reliable than the
 * light+tilt heuristic because it is a direct physical measurement.
 *
 * Reading interpretation:
 *   values[0] < sensor.maximumRange → NEAR (hand, pocket, or face)
 *   values[0] == sensor.maximumRange → FAR (nothing nearby)
 *
 * Note: Proximity sensors are wakeup sensors on Android — the system ignores the
 * 60s FIFO report latency and delivers events immediately. No data is batched.
 */
class ProximitySensor(sensorManager: SensorManager) :
    BaseSensor<Boolean>(sensorManager, Sensor.TYPE_PROXIMITY, "GreenGainsProximity") {

    override fun processEvent(event: SensorEvent) {
        // true = NEAR (occluded), false = FAR (clear)
        _dataFlow.value = event.values[0] < event.sensor.maximumRange
    }
}
