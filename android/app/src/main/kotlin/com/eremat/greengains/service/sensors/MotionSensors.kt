package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Manages both Accelerometer and Gyroscope since they are often used together.
 * Does not inherit from BaseSensor because it manages two sensors.
 *
 * Uses hardware FIFO batching for battery optimization (60s intervals).
 */
class MotionSensors(private val sensorManager: SensorManager) : SensorEventListener {
    private val tag = "GreenGainsMotion"

    private val _accelerometerFlow = MutableStateFlow<FloatArray?>(null)
    val accelerometerFlow: StateFlow<FloatArray?> = _accelerometerFlow

    private val _gyroscopeFlow = MutableStateFlow<FloatArray?>(null)
    val gyroscopeFlow: StateFlow<FloatArray?> = _gyroscopeFlow

    // Gravity-compensated accelerometer (Android sensor fusion, used for upload payload)
    private val _linearAccelerationFlow = MutableStateFlow<FloatArray?>(null)
    val linearAccelerationFlow: StateFlow<FloatArray?> = _linearAccelerationFlow

    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null
    private var linearAccelSensor: Sensor? = null

    init {
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        accelerometer?.let {
            val fifoMax = it.fifoMaxEventCount
            Log.d(tag, "Accelerometer: ${it.name}, FIFO: $fifoMax events")
            if (fifoMax > 0) {
                Log.i(tag, "✓ Accelerometer FIFO batching supported")
            }
        } ?: Log.w(tag, "Accelerometer not available")

        gyroscope?.let {
            val fifoMax = it.fifoMaxEventCount
            Log.d(tag, "Gyroscope: ${it.name}, FIFO: $fifoMax events")
            if (fifoMax > 0) {
                Log.i(tag, "✓ Gyroscope FIFO batching supported")
            }
        } ?: Log.w(tag, "Gyroscope not available")

        linearAccelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        linearAccelSensor?.let {
            Log.i(tag, "✓ Linear Acceleration sensor available (gravity-compensated via Android fusion)")
        } ?: Log.w(tag, "Linear Acceleration not available — will fall back to raw accelerometer for upload")
    }

    fun start() {
        accelerometer?.let {
            // Use FIFO batching: 60 second intervals
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_NORMAL, // ~200ms sampling
                FIFO_MAX_REPORT_LATENCY_US // 60s batching
            )
        }
        gyroscope?.let {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_NORMAL,
                FIFO_MAX_REPORT_LATENCY_US
            )
        }
        linearAccelSensor?.let {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_NORMAL,
                FIFO_MAX_REPORT_LATENCY_US
            )
        }
        Log.d(tag, "Motion listeners registered with FIFO batching (60s)")
    }

    /**
     * Flush both accelerometer and gyroscope FIFO buffers immediately.
     */
    fun flush() {
        var flushed = 0
        accelerometer?.let { if (sensorManager.flush(this)) flushed++ }
        gyroscope?.let { if (sensorManager.flush(this)) flushed++ }
        linearAccelSensor?.let { if (sensorManager.flush(this)) flushed++ }
        Log.d(tag, "FIFO flush: $flushed sensors flushed")
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        Log.d(tag, "Motion listeners unregistered")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                _accelerometerFlow.value = event.values.clone()
            }
            Sensor.TYPE_GYROSCOPE -> {
                _gyroscopeFlow.value = event.values.clone()
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                _linearAccelerationFlow.value = event.values.clone()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op
    }

    companion object {
        /**
         * FIFO batching interval: 60 seconds (in microseconds).
         */
        private const val FIFO_MAX_REPORT_LATENCY_US = 60_000_000 // 60 seconds (Int, not Long)
    }
}
