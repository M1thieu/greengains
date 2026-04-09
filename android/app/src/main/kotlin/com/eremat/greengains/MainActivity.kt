package com.eremat.greengains

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.Manifest.permission.ACCESS_COARSE_LOCATION
import android.Manifest.permission.ACCESS_FINE_LOCATION
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.eremat.greengains.service.ForegroundService
import com.eremat.greengains.util.AppLogger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter <-> native foreground service and handles permission requests.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
        private const val ZONE_CHANNEL_ID = "zone_discoveries"
        private const val NOTIFICATION_ID_ZONE = 3
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppLogger.init(this)
        AppLogger.i("MainActivity", "App started")
        checkAndRequestNotificationPermission()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sensor trigger channel used by the ForegroundService to push data to Flutter.
        val sensorTriggerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "greengains/sensor_trigger"
        )
        ForegroundService.methodChannel = sensorTriggerChannel

        // Foreground service control channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "greengains/foreground")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        startForegroundService()
                        result.success(true)
                    }
                    "pauseForegroundService" -> {
                        result.success(sendServiceAction(ForegroundService.ACTION_PAUSE_TRACKING))
                    }
                    "resumeForegroundService" -> {
                        result.success(sendServiceAction(ForegroundService.ACTION_RESUME_TRACKING))
                    }
                    "stopForegroundService" -> {
                        result.success(stopFgService())
                    }
                    "isForegroundServiceRunning" -> {
                        result.success(ForegroundService.running)
                    }
                    "isTrackingPaused" -> {
                        result.success(ForegroundService.trackingPaused)
                    }
                    "wasAppUserStopped" -> {
                        result.success(wasAppUserStopped())
                    }
                    "requestLocationPermission" -> {
                        requestLocationPermissions()
                        result.success(true)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }
                        result.success(ignoring)
                    }
                    "flushSensorBuffers" -> {
                        // Flush FIFO buffers to get fresh data in UI
                        result.success(sendServiceAction(ForegroundService.ACTION_FLUSH_FIFO))
                    }
                    "showZoneNotification" -> {
                        val newZones = call.argument<Int>("newZones") ?: 0
                        val totalZones = call.argument<Int>("totalZones") ?: 0
                        showZoneNotification(newZones, totalZones)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Logging channel for debugging and analytics
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "greengains/logger")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readLogs" -> {
                        val logs = AppLogger.getInstance().readLogs()
                        result.success(logs)
                    }
                    "clearLogs" -> {
                        AppLogger.getInstance().clearLogs()
                        result.success(true)
                    }
                    "getLogFileSizeBytes" -> {
                        val size = AppLogger.getInstance().getLogFileSizeBytes()
                        result.success(size)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        // Avoid leaking the MethodChannel when the engine is torn down
        ForegroundService.methodChannel = null
    }

    /**
     * Check for notification permission before starting the service so that the notification is visible.
     */
    private fun checkAndRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)) {
                PackageManager.PERMISSION_GRANTED -> {
                    // already granted
                }
                else -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                        NOTIFICATION_PERMISSION_REQUEST_CODE
                    )
                }
            }
        }
    }

    /**
     * Request location permissions (FINE + COARSE).
     */
    private fun requestLocationPermissions() {
        val fineGranted = ContextCompat.checkSelfPermission(this, ACCESS_FINE_LOCATION)
        val coarseGranted = ContextCompat.checkSelfPermission(this, ACCESS_COARSE_LOCATION)

        if (fineGranted != PackageManager.PERMISSION_GRANTED &&
            coarseGranted != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        } // already granted — nothing to do
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                val fineGranted = grantResults.getOrNull(0) == PackageManager.PERMISSION_GRANTED
                val coarseGranted = grantResults.getOrNull(1) == PackageManager.PERMISSION_GRANTED
                when {
                    fineGranted || coarseGranted -> {
                        Toast.makeText(this, "Location permission granted", Toast.LENGTH_SHORT).show()
                    }
                    else -> {
                        Toast.makeText(this, "Location permission denied", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                // If denied, service still runs; notification may not show.
            }
        }
    }

    /**
     * Creates and starts the ForegroundService as a foreground service.
     */
    private fun startForegroundService() {
        // CRITICAL: On Android 14+, location permissions MUST be granted before starting
        // a foreground service with type location. Otherwise it will crash with SecurityException.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val hasFineLocation = ContextCompat.checkSelfPermission(
                this,
                ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            val hasCoarseLocation = ContextCompat.checkSelfPermission(
                this,
                ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasFineLocation && !hasCoarseLocation) {
                android.util.Log.e("GreenGains", "Cannot start foreground service: location permission not granted")
                return
            }
        }

        val serviceIntent = Intent(this, ForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) {
            return
        }

        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }

        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    private fun stopFgService(): Boolean {
        return try {
            val intent = Intent(this, ForegroundService::class.java)
            stopService(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun sendServiceAction(action: String): Boolean {
        return try {
            val serviceIntent = Intent(this, ForegroundService::class.java).apply {
                this.action = action
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Posts a heads-up notification when the user discovers new zones.
     * Uses a separate low-priority channel so it doesn't interrupt ongoing service notifications.
     */
    private fun showZoneNotification(newZones: Int, totalZones: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = manager.getNotificationChannel(ZONE_CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    ZONE_CHANNEL_ID,
                    getString(R.string.notification_zone_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    enableVibration(true)
                    setShowBadge(true)
                }
                manager.createNotificationChannel(channel)
            }
        }

        val body = if (newZones == 1) {
            getString(R.string.notification_zone_body_single, totalZones)
        } else {
            getString(R.string.notification_zone_body_multiple, newZones, totalZones)
        }

        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, ZONE_CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_zone_title))
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
            .build()

        manager.notify(NOTIFICATION_ID_ZONE, notification)
    }

    /**
     * Returns true when Android reports the previous process exit as user-requested.
     * This maps to Task Manager stop on Android 13+.
     */
    private fun wasAppUserStopped(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val reasons = activityManager.getHistoricalProcessExitReasons(packageName, 0, 1)
            val reason = reasons.firstOrNull()?.reason
            reason == ApplicationExitInfo.REASON_USER_REQUESTED
        } catch (_: Exception) {
            false
        }
    }
}
