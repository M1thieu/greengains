package com.eremat.greengains

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.eremat.greengains.service.ForegroundService
import com.eremat.greengains.util.AppPrefs

/**
 * BroadcastReceiver that restarts the ForegroundService after device reboot
 * if the service was running before.
 *
 * This ensures continuous tracking even after device restarts.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        Log.i(TAG, "Device boot completed. Checking if service should restart...")

        // Check if service was enabled before reboot
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val wasServiceRunning = prefs.getBoolean(AppPrefs.FOREGROUND_ENABLED, false)

        if (wasServiceRunning) {
            // BOOT_COMPLETED is explicitly exempt from Android 14+ background FGS restrictions.
            // Direct startForegroundService() is safe here — no WorkManager needed.
            Log.i(TAG, "Service was running before reboot — restarting directly")
            val intent = Intent(context, ForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } else {
            Log.i(TAG, "Service was not running before reboot — skipping restart")
        }
    }

    companion object {
        private const val TAG = "GreenGainsBootReceiver"
    }
}
