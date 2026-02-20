package com.eremat.greengains.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.format.DateUtils
import androidx.core.app.NotificationCompat
import com.eremat.greengains.MainActivity
import com.eremat.greengains.R
import com.eremat.greengains.service.ForegroundService
import com.eremat.greengains.util.AppPrefs
import java.time.Instant

internal object NotificationsHelper {

    private const val NOTIFICATION_CHANNEL_ID = "general_notification_channel"
    const val NOTIFICATION_ID_SERVICE = 1
    const val NOTIFICATION_ID_WORKER = 2

    fun createNotificationChannel(context: Context) {
        val notificationManager = context.getSystemService(Service.NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Location Tracking",
            NotificationManager.IMPORTANCE_LOW // Low importance = silent, no popup
        ).apply {
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    fun buildNotification(context: Context, lastUploadMillis: Long? = null, isPaused: Boolean = false): Notification {
        val actionIntent = Intent(context, ForegroundService::class.java).apply {
            action = if (isPaused) {
                ForegroundService.ACTION_RESUME_TRACKING
            } else {
                ForegroundService.ACTION_PAUSE_TRACKING
            }
        }
        val actionPendingIntent = PendingIntent.getService(
            context,
            0,
            actionIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val (collapsed, detail) = buildSubtitle(context, lastUploadMillis, isPaused)
        val actionLabel = if (isPaused) {
            context.getString(R.string.notification_action_resume)
        } else {
            context.getString(R.string.notification_action_pause)
        }

        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(context.getString(R.string.app_name))
            .setContentText(collapsed)
            .setStyle(NotificationCompat.BigTextStyle().bigText(detail))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setOngoing(true)
            .addAction(
                R.mipmap.ic_launcher,
                actionLabel,
                actionPendingIntent
            )
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(Intent(context, MainActivity::class.java).let { notificationIntent ->
                PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
            })
            .build()
    }

    private fun buildSubtitle(context: Context, lastUploadMillis: Long?, isPaused: Boolean): Pair<String, String> {
        val relative: String? = lastUploadMillis?.let {
            val ageMs = System.currentTimeMillis() - it
            if (ageMs < 60_000L) {
                context.getString(R.string.notification_just_now)
            } else {
                DateUtils.getRelativeTimeSpanString(
                    it,
                    System.currentTimeMillis(),
                    DateUtils.MINUTE_IN_MILLIS
                ).toString()
            }
        }

        // Collapsed line: compact, shows upload time inline when available
        val collapsed = when {
            isPaused -> context.getString(R.string.notification_status_paused)
            relative != null -> context.getString(R.string.notification_collecting_with_upload, relative)
            else -> context.getString(R.string.notification_collecting_no_upload)
        }

        // Expanded detail line (shown in expanded notification)
        val detail = when {
            isPaused && relative != null ->
                context.getString(R.string.notification_last_upload_before_pause, relative)
            isPaused ->
                context.getString(R.string.notification_last_upload_paused_unknown)
            relative != null ->
                context.getString(R.string.notification_last_upload, relative)
            else ->
                context.getString(R.string.notification_last_upload_unknown)
        }

        return collapsed to detail
    }

    fun readLastUploadFromPrefs(context: Context): Long? {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(AppPrefs.LAST_UPLOAD_AT, null) ?: return null
        return runCatching { Instant.parse(raw).toEpochMilli() }.getOrNull()
    }

    fun notifyUpdate(context: Context, manager: NotificationManager, lastUpload: Long?, isPaused: Boolean) {
        manager.notify(NOTIFICATION_ID_SERVICE, buildNotification(context, lastUpload, isPaused))
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
