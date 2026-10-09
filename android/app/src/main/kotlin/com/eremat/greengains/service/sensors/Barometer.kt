package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager
import android.os.SystemClock
import android.util.Log

class Barometer(sensorManager: SensorManager) :
    BaseSensor<Float>(sensorManager, Sensor.TYPE_PRESSURE, "GreenGainsBarometer") {

    /** elapsedRealtimeNanos at the last registration; sensor events share this time base. */
    @Volatile private var startedAtNs = 0L

    override fun onStarted() {
        startedAtNs = SystemClock.elapsedRealtimeNanos()
    }

    override fun processEvent(event: SensorEvent) {
        // A barometer reads off just after waking: its IIR filter makes the first reading
        // wrong by ~75% of a pressure change (McNicholas & Mass 2018). Hintz et al. 2019
        // skip 5 s; McNicholas (2017 thesis) recommends at least 15 s, used here.
        if (event.timestamp - startedAtNs < WARM_UP_NS) return
        val pressure = event.values[0]
        Log.d("GreenGainsBarometer", "Pressure reading: ${pressure} hPa")
        _dataFlow.value = pressure
    }

    private companion object {
        const val WARM_UP_NS = 15_000_000_000L
    }
}
