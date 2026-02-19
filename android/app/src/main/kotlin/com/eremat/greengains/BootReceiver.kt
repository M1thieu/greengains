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
            // Android 14+ (SDK 35) doesn't allow starting location services from background
            // Service will auto-start when user opens the app instead
            Log.i(TAG, "Service was running before reboot. Will auto-start when app opens.")
        } else {
            Log.i(TAG, "Service was not running before reboot. Skipping restart.")
        }
    }

    companion object {
        private const val TAG = "GreenGainsBootReceiver"
    }
}
