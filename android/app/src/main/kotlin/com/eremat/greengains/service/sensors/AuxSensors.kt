package com.eremat.greengains.service.sensors

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log

/**
 * Extra channels that only SOME phones carry. Nothing here is required: a channel whose sensor
 * is absent simply never appears, so the same build runs unchanged on a phone with a humidity
 * sensor and on one without.
 *
 * Channels are discovered at runtime from SensorManager rather than assumed, and matched either
 * by standard Android type or by the vendor `stringType` the OEM publishes. Vendor types are how
 * Pixels expose their second (rear) light sensor and the temperature of the barometer die, which
 * the public API has no constant for.
 *
 * Why record these at all: the barometer's residual drift and the front light sensor's
 * occlusion are the two largest identifiable error sources in the current data. A chip
 * temperature and a second light sensor let the BACKEND test, from data, whether either explains
 * that error, instead of us guessing. They are recorded raw; every model decision happens
 * server-side and nothing here is shown to the user.
 *
 * No permissions: only sensors that declare none are used (the OS refuses the registration
 * otherwise and the channel is skipped). Non-wakeup sensors only, so this never wakes the CPU.
 */
class AuxSensors(private val sensorManager: SensorManager) {

    /** Where a channel comes from: a public Android type, or an OEM-published string type. */
    private class Spec(val key: String, val type: Int? = null, val stringType: String? = null)

    private inner class Channel(val key: String, val sensor: Sensor) : SensorEventListener {
        private val samples = ArrayList<Float>()
        private var last: Float? = null

        override fun onSensorChanged(event: SensorEvent) {
            val v = event.values.firstOrNull() ?: return
            if (!v.isFinite()) return
            synchronized(this) {
                samples.add(v)
                last = v
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

        /**
         * One value for the window just ended, or null if there is none.
         *
         * An on-change sensor emits nothing while its value is unchanged, so an empty window means
         * "still the last value" (documented Android semantics) and that value is carried.
         * A continuous sensor with an empty window has really gone quiet: report nothing.
         */
        fun drain(): Float? = synchronized(this) {
            val value = medianOf(samples)
                ?: if (sensor.reportingMode == Sensor.REPORTING_MODE_ON_CHANGE) last else null
            samples.clear()
            value
        }

        fun clear() = synchronized(this) { samples.clear(); last = null }
    }

    private var channels: List<Channel>? = null
    private var started = false

    /** Registers every channel this phone has. Idempotent; safe when none exist. */
    @Synchronized
    fun start() {
        if (started) return
        val found = channels ?: discover().also { channels = it }
        for (c in found) {
            val ok = sensorManager.registerListener(c, c.sensor, SensorManager.SENSOR_DELAY_NORMAL, FIFO_MAX_REPORT_LATENCY_US)
            Log.i(TAG, "aux '${c.key}' <- ${c.sensor.name} (${c.sensor.stringType}) registered=$ok")
        }
        started = true
    }

    @Synchronized
    fun stop() {
        if (!started) return
        channels?.forEach { sensorManager.unregisterListener(it); it.clear() }
        started = false
    }

    fun flush() {
        channels?.forEach { sensorManager.flush(it) }
    }

    /** Median per channel over the window since the last call, or null when nothing was measured. */
    fun drain(): Map<String, Float>? {
        val out = HashMap<String, Float>()
        channels?.forEach { c -> c.drain()?.let { out[c.key] = it } }
        return out.takeIf { it.isNotEmpty() }?.also { Log.d(TAG, "aux window: $it") }
    }

    private fun discover(): List<Channel> {
        val all = sensorManager.getSensorList(Sensor.TYPE_ALL).filter { !it.isWakeUpSensor }
        val found = CATALOG.mapNotNull { spec ->
            val sensor = all.firstOrNull { s ->
                (spec.type != null && s.type == spec.type) ||
                    (spec.stringType != null && s.stringType == spec.stringType)
            }
            sensor?.let { Channel(spec.key, it) }
        }
        Log.i(TAG, "aux channels available: ${found.map { it.key }.ifEmpty { listOf("none") }}")
        return found
    }

    companion object {
        private const val TAG = "GreenGainsAux"

        /** Same batching as the core sensors: samples ride the existing 60 s delivery, no extra wakeups. */
        private const val FIFO_MAX_REPORT_LATENCY_US = 60_000_000

        /**
         * `temp_ambient_c` degrees C, `rh_pct` percent, `lux_rear` lux-like (vendor unit, raw),
         * `temp_baro_c` degrees C (barometer die, used to test drift hypotheses; the datasheet
         * suggests its effect is small). The IMU die temperature is deliberately not collected.
         */
        private val CATALOG = listOf(
            Spec("temp_ambient_c", type = Sensor.TYPE_AMBIENT_TEMPERATURE),
            Spec("rh_pct", type = Sensor.TYPE_RELATIVE_HUMIDITY),
            Spec("lux_rear", stringType = "com.google.sensor.rear_light"),
            Spec("temp_baro_c", stringType = "com.google.sensor.pressure_temp"),
        )
    }
}

/**
 * Median of a window: no tuning constant and immune to a stray spike, which is why it is used
 * here instead of a mean with an outlier rule. Null for an empty window.
 */
internal fun medianOf(values: List<Float>): Float? {
    if (values.isEmpty()) return null
    val s = values.sorted()
    val mid = s.size / 2
    return if (s.size % 2 == 1) s[mid] else (s[mid - 1] + s[mid]) / 2f
}
