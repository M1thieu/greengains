package com.eremat.greengains.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.app.NotificationCompat
import com.eremat.greengains.MainActivity
import com.eremat.greengains.R
import com.eremat.greengains.service.ForegroundService
import com.eremat.greengains.util.AppPrefs
import java.time.Instant

internal object NotificationsHelper {

    /** Short elapsed-time label for "X ago" style upload timestamps. */
    private fun formatElapsedUpload(context: Context, lastUploadMillis: Long): String {
        val elapsedMs = System.currentTimeMillis() - lastUploadMillis
        return when {
            elapsedMs < 90_000L -> context.getString(R.string.notification_upload_just_now)
            elapsedMs < 3_600_000L -> context.getString(R.string.notification_upload_minutes_ago, elapsedMs / 60_000)
            elapsedMs < 86_400_000L -> context.getString(R.string.notification_upload_hours_ago, elapsedMs / 3_600_000)
            else -> context.getString(R.string.notification_upload_yesterday)
        }
    }

    // v2 channel — renames the user-visible label from "Location Tracking" to
    // "Sensor Collection". Old channel is deleted on first run so Android picks up the new name.
    private const val NOTIFICATION_CHANNEL_ID = "sensor_collection_v2"
    private const val LEGACY_CHANNEL_ID       = "general_notification_channel"
    const val NOTIFICATION_ID_SERVICE = 1
    const val NOTIFICATION_ID_WORKER = 2

    fun createNotificationChannel(context: Context) {
        val notificationManager = context.getSystemService(Service.NOTIFICATION_SERVICE) as NotificationManager

        // Remove the legacy channel so Android picks up the new user-visible name.
        notificationManager.deleteNotificationChannel(LEGACY_CHANNEL_ID)

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Sensor Collection",           // was "Location Tracking" — clearer + less invasive
            NotificationManager.IMPORTANCE_LOW // Low importance = silent, no popup
        ).apply {
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    fun buildNotification(
        context: Context,
        lastUploadMillis: Long? = null,
        isPaused: Boolean = false,
        uploadsToday: Int = 0,
        totalUploads: Int = 0,
        zonesTotal: Int = 0,
        motionState: String = "UNKNOWN",
        readingsCount: Int = 0,
        sessionStartMillis: Long? = null,
    ): Notification {
        // Primary action — Pause ↔ Resume
        val primaryIntent = Intent(context, ForegroundService::class.java).apply {
            action = if (isPaused) ForegroundService.ACTION_RESUME_TRACKING
                     else          ForegroundService.ACTION_PAUSE_TRACKING
        }
        val primaryPendingIntent = PendingIntent.getService(
            context, 0, primaryIntent, PendingIntent.FLAG_IMMUTABLE
        )
        val primaryLabel = if (isPaused) context.getString(R.string.notification_action_resume)
                           else          context.getString(R.string.notification_action_pause)

        val stopIntent = Intent(context, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_STOP_SERVICE
        }
        val stopPendingIntent = PendingIntent.getService(
            context, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val title = when {
            isPaused -> context.getString(R.string.notification_paused_title)
            motionState == "STATIONARY" -> context.getString(R.string.notification_status_stationary)
            else -> context.getString(R.string.notification_status_collecting)
        }

        val isUploadingNow = lastUploadMillis != null &&
            (System.currentTimeMillis() - lastUploadMillis) < 15_000L

        // Collapsed body — zone count is the primary signal. Elapsed time is now
        // handled by the native chronometer (setUsesChronometer) so the body stays
        // clean without custom refresh logic.
        val body = when {
            isPaused ->
                if (zonesTotal > 0) context.getString(R.string.notification_body_paused_zones, zonesTotal)
                else context.getString(R.string.notification_paused_body)
            motionState == "STATIONARY" && zonesTotal > 0 ->
                context.getString(R.string.notification_body_stationary, zonesTotal)
            zonesTotal > 0 ->
                if (isUploadingNow) context.getString(R.string.notification_body_zones_uploading, zonesTotal)
                else context.getString(R.string.notification_body_zones_collecting, zonesTotal)
            readingsCount > 0 ->
                context.getString(R.string.notification_readings_uploading, readingsCount)
            else -> context.getString(R.string.notification_collecting_no_upload)
        }

        // Compact status line: "Uploaded 5 min ago  ·  moving" — factual, no fluff.
        val uploadPart = when {
            isPaused        -> null
            isUploadingNow  -> context.getString(R.string.notification_sync_uploading)
            lastUploadMillis != null ->
                context.getString(R.string.notification_sync_uploaded, formatElapsedUpload(context, lastUploadMillis))
            else            -> context.getString(R.string.notification_sync_none)
        }
        val motionPart = when {
            isPaused -> null
            motionState == "STATIONARY" -> context.getString(R.string.notification_motion_stationary)
            else -> context.getString(R.string.notification_motion_moving)
        }
        val infoLine = when {
            isPaused -> context.getString(R.string.notification_expanded_paused)
            uploadPart != null && motionPart != null -> "$uploadPart  ·  $motionPart"
            else -> uploadPart ?: motionPart ?: ""
        }
        val bigText = "$body\n$infoLine"

        val isActive = !isPaused
        val sensorsRunning = isActive && motionState != "STATIONARY"
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setColorized(isActive)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(0, 0, sensorsRunning)
            .setShowWhen(false)
            .addAction(0, primaryLabel, primaryPendingIntent)
            .addAction(0, context.getString(R.string.notification_action_stop), stopPendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(Intent(context, MainActivity::class.java).let { notificationIntent ->
                PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
            })
            .build()
    }

    fun readLastUploadFromPrefs(context: Context): Long? {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(AppPrefs.LAST_UPLOAD_AT, null) ?: return null
        return runCatching { Instant.parse(raw).toEpochMilli() }.getOrNull()
    }

    fun readZonesTotalFromPrefs(context: Context): Int {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        return prefs.getInt(AppPrefs.ZONES_TOTAL_COUNT, 0)
    }

    fun notifyUpdate(
        context: Context,
        manager: NotificationManager,
        lastUpload: Long?,
        isPaused: Boolean,
        uploadsToday: Int = 0,
        totalUploads: Int = 0,
        zonesTotal: Int = 0,
        motionState: String = "UNKNOWN",
        readingsCount: Int = 0,
        sessionStartMillis: Long? = null,
    ) {
        manager.notify(NOTIFICATION_ID_SERVICE, buildNotification(
            context, lastUpload, isPaused, uploadsToday, totalUploads, zonesTotal,
            motionState, readingsCount, sessionStartMillis,
        ))
    }

    fun buildWorkerNotification(context: Context): Notification {
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(context.getString(R.string.notification_worker_title))
            .setContentText(context.getString(R.string.notification_worker_body))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(Intent(context, MainActivity::class.java).let { notificationIntent ->
                PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
            })
            .build()
    }
}
