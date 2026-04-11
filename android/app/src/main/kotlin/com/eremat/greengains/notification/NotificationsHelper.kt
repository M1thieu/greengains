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
        currentStreak: Int = 0,
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

        // Stop action — always available; users shouldn't need to open the app to stop.
        val stopIntent = Intent(context, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_STOP_SERVICE
        }
        val stopPendingIntent = PendingIntent.getService(
            context, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE
        )

        // Title = status ("Mapping your city" or "Paused") — bold first line users scan.
        // Body  = upload counts or instruction.
        // setWhen: Android SystemUI auto-updates "X min. ago" — no refresh loop needed.
        val title = if (isPaused) context.getString(R.string.notification_paused_title)
                    else          context.getString(R.string.notification_status_collecting)

        val body = when {
            isPaused    -> context.getString(R.string.notification_paused_body)
            uploadsToday > 0 -> context.getString(
                R.string.notification_readings_with_total, uploadsToday, totalUploads
            )
            else -> context.getString(R.string.notification_collecting_no_upload)
        }

        // subText: streak nudge when streak > 1 and actively collecting.
        // Appears in the notification header line next to the app name — subtle motivation.
        val subText = if (!isPaused && currentStreak > 1)
            context.getString(R.string.notification_subtext_streak, currentStreak)
        else null

        val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setWhen(lastUploadMillis ?: 0L)
            .setShowWhen(lastUploadMillis != null && !isPaused)
            // Action icons: 0 = hidden on Android 7+, avoids ic_launcher blob in action row.
            .addAction(0, primaryLabel, primaryPendingIntent)
            .addAction(0, context.getString(R.string.notification_action_stop), stopPendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(Intent(context, MainActivity::class.java).let { notificationIntent ->
                PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
            })

        if (subText != null) builder.setSubText(subText)

        return builder.build()
    }

    fun readLastUploadFromPrefs(context: Context): Long? {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(AppPrefs.LAST_UPLOAD_AT, null) ?: return null
        return runCatching { Instant.parse(raw).toEpochMilli() }.getOrNull()
    }

    fun notifyUpdate(
        context: Context,
        manager: NotificationManager,
        lastUpload: Long?,
        isPaused: Boolean,
        uploadsToday: Int = 0,
        totalUploads: Int = 0,
        currentStreak: Int = 0,
    ) {
        manager.notify(NOTIFICATION_ID_SERVICE, buildNotification(context, lastUpload, isPaused, uploadsToday, totalUploads, currentStreak))
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
