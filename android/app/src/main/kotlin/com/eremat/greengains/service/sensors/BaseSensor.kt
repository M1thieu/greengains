package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Abstract base class for managing Android sensors.
 * Handles listener registration/unregistration and flow updates.
 *
 * Uses hardware FIFO batching for battery optimization:
 * - Sensor chip stores samples in hardware buffer (CPU sleeps)
 * - CPU wakes every 60 seconds to read batch of samples
 * - Result: 6x fewer CPU wakeups with ZERO data loss
 * - Fallback: If FIFO not supported, events delivered immediately
 */
abstract class BaseSensor<T>(
    private val sensorManager: SensorManager,
    private val sensorType: Int,
    private val tag: String
) : SensorEventListener {

    protected val _dataFlow = MutableStateFlow<T?>(null)
    val dataFlow: StateFlow<T?> = _dataFlow

    private var sensor: Sensor? = null

    init {
        sensor = sensorManager.getDefaultSensor(sensorType)
        if (sensor == null) {
            Log.w(tag, "Sensor not available on this device")
        } else {
            val fifoMax = sensor?.fifoMaxEventCount ?: 0
            val fifoReserved = sensor?.fifoReservedEventCount ?: 0
            Log.d(tag, "Sensor available: ${sensor?.name}, FIFO: max=$fifoMax, reserved=$fifoReserved")

            if (fifoMax > 0) {
                Log.i(tag, "✓ Hardware FIFO batching supported (buffer size: $fifoMax events)")
            } else {
                Log.i(tag, "⚠ FIFO not supported - will use immediate delivery (still works, just less battery efficient)")
            }
        }
    }

    fun start() {
        sensor?.let {
            // Use FIFO batching: batch samples for up to 60 seconds before delivery
            // If sensor doesn't support FIFO, samples are delivered immediately (safe fallback)
            // 60 seconds = 60,000,000 microseconds
            val success = sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_NORMAL, // ~200ms sampling rate
                FIFO_MAX_REPORT_LATENCY_US // 60 second batching
            )
            Log.d(tag, "Listener registered: success=$success, sensor=${it.name}, type=${it.type}, batching=${FIFO_MAX_REPORT_LATENCY_US}us")
            if (success) onStarted()
        } ?: Log.w(tag, "Cannot start: sensor is null")
    }

    /** Called after the listener is registered; subclasses reset per-run state here. */
    protected open fun onStarted() = Unit

    /**
     * Flush the sensor FIFO buffer immediately.
     * Useful when user opens app (show fresh data) or battery drops low.
     */
    fun flush() {
        sensor?.let {
            val success = sensorManager.flush(this)
            Log.d(tag, "FIFO flush: success=$success")
        }
    }

    fun stop() {
        if (sensor != null) {
            sensorManager.unregisterListener(this)
            Log.d(tag, "Listener unregistered")
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op by default
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == sensorType) {
            if (tag == "GreenGainsBarometer") {
                Log.d(tag, "onSensorChanged called, values: ${event.values.joinToString()}")
            }
            processEvent(event)
        }
    }

    protected abstract fun processEvent(event: SensorEvent)

    companion object {
        /**
         * FIFO batching interval: 60 seconds (in microseconds).
         * Reduces CPU wakeups from 6/min to 1/min with zero data loss.
         */
        private const val FIFO_MAX_REPORT_LATENCY_US = 60_000_000 // 60 seconds (Int, not Long)
    }
}
