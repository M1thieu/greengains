package com.eremat.greengains.service.sensors

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Raw device readings that are not SensorManager sensors, sent as extra `aux` channels next to
 * [AuxSensors]. Like those, they are never shown to the user; any use is decided server-side.
 *
 * - `battery_temp_c`, `battery_plugged` (0/1): battery temperature tracks air temperature only
 *   in city-wide daily aggregates and only when the charging state is known (Overeem et al.
 *   2013, GRL), so both are recorded.
 * - `cell_level` (0-4), `cell_dbm`, `cell_mccmnc`: serving-cell signal strength is the best
 *   validated phone radio measurement (Molinari 2018). MCC-MNC names the operator and country,
 *   not a person. No cell ID is ever read: 4 points at cell-antenna resolution identify 95% of
 *   people (de Montjoye et al. 2013).
 *
 * No permission: the battery broadcast is sticky and open, and getSignalStrength /
 * getNetworkOperator need none (CellInfoListener would need READ_PHONE_STATE and is not used).
 */
class DeviceChannels(private val context: Context) {

    private val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    /** Current values, or an empty map when none can be read. */
    fun read(): Map<String, Float> {
        val out = HashMap<String, Float>()
        try {
            val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (battery != null) {
                // EXTRA_TEMPERATURE is in tenths of a degree Celsius.
                val tenths = battery.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                if (tenths != Int.MIN_VALUE) out["battery_temp_c"] = tenths / 10f
                val plugged = battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
                if (plugged >= 0) out["battery_plugged"] = if (plugged == 0) 0f else 1f
            }
        } catch (e: Exception) {
            Log.w(TAG, "battery read failed: ${e.message}")
        }

        val tm = telephony
        if (tm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val signal = tm.signalStrength
                if (signal != null) {
                    out["cell_level"] = signal.level.toFloat()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        signal.cellSignalStrengths.firstOrNull()?.dbm
                            ?.takeIf { it != Int.MAX_VALUE && it < 0 }
                            ?.let { out["cell_dbm"] = it.toFloat() }
                    }
                }
                tm.networkOperator.toIntOrNull()?.let { out["cell_mccmnc"] = it.toFloat() }
            } catch (e: Exception) {
                Log.w(TAG, "cell read failed: ${e.message}")
            }
        }
        return out
    }

    private companion object {
        const val TAG = "GreenGainsDevice"
    }
}
