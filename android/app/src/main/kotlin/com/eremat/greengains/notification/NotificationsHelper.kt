package com.eremat.greengains.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.eremat.greengains.MainActivity
import com.eremat.greengains.R
import com.eremat.greengains.service.ForegroundService
import com.eremat.greengains.util.AppPrefs
import java.time.Instant

internal object NotificationsHelper {

    private const val NOTIFICATION_CHANNEL_ID   = "sensor_collection_v2"
    private const val LEGACY_CHANNEL_ID         = "general_notification_channel"
    const val NOTIFICATION_ID_SERVICE   = 1
    const val NOTIFICATION_ID_WORKER    = 2

    fun createNotificationChannel(context: Context) {
        val manager = context.getSystemService(Service.NOTIFICATION_SERVICE) as NotificationManager
        manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        val serviceChannel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Sensor Collection",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }
        manager.createNotificationChannel(serviceChannel)

        // Only the ongoing service notification remains. Deleting a channel also
        // removes anything still posted on it (session recap, weekly digest, streak).
        manager.deleteNotificationChannel("discovery_v1")
        manager.deleteNotificationChannel("streak_reminders")
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
        sessionZones: Int = 0,
        lux: Float? = null,
        hPa: Float? = null,
    ): Notification {
        val isMoving = motionState != "STATIONARY"

        val durationStr = sessionStartMillis?.let {
            val elapsed = System.currentTimeMillis() - it
            if (elapsed >= 60_000L) formatDuration(context, elapsed) else null
        }

        // ── Title: state + optional neighbourhood ────────────────────────────
        val territory = context
            .getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            .getString(AppPrefs.TERRITORY_LABEL, null)
            ?.takeIf { it.isNotBlank() }
        val baseTitle = when {
            isPaused -> context.getString(R.string.notification_paused_title)
            isMoving -> context.getString(R.string.notif_title_contributing)
            else     -> context.getString(R.string.notif_title_standby)
        }
        val title = if (territory != null) "$baseTitle · $territory" else baseTitle

        // ── Body: two numbers, no prose ──────────────────────────────────────
        val sessionZonesStr = if (!isPaused && sessionZones > 0)
            context.getString(R.string.notif_session_zones, sessionZones)
        else null
        val body = when {
            isPaused -> context.getString(R.string.notification_paused_body)
            else -> listOfNotNull(sessionZonesStr, durationStr).joinToString(" · ")
                .ifEmpty { context.getString(R.string.notif_body_measuring) }
        }

        // ── Actions with icons ─────────────────────────────────────────────────
        val pauseResumeIntent = Intent(context, ForegroundService::class.java).apply {
            action = if (isPaused) ForegroundService.ACTION_RESUME_TRACKING
                     else          ForegroundService.ACTION_PAUSE_TRACKING
        }
        // Use distinct request codes for pause vs resume so Android doesn't return the
        // cached PendingIntent with the wrong action when the state flips (FLAG_IMMUTABLE
        // prevents updates to existing intents sharing the same request code).
        val pauseResumeRequestCode = if (isPaused) 3 else 2
        val pauseResumePending = PendingIntent.getService(
            context, pauseResumeRequestCode, pauseResumeIntent, PendingIntent.FLAG_IMMUTABLE)
        val pauseResumeIcon = if (isPaused) R.drawable.ic_notif_play else R.drawable.ic_notif_pause
        val pauseResumeLabel = if (isPaused) context.getString(R.string.notification_action_resume)
                               else          context.getString(R.string.notification_action_pause)

        val stopIntent = Intent(context, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_STOP_SERVICE
        }
        val stopPending = PendingIntent.getService(
            context, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE)

        val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification_leaf)
            .setColor(android.graphics.Color.parseColor("#10B981"))
            .setColorized(false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .addAction(pauseResumeIcon, pauseResumeLabel, pauseResumePending)
            .addAction(R.drawable.ic_notif_stop,
                context.getString(R.string.notification_action_stop), stopPending)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(
                PendingIntent.getActivity(
                    context, 0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE
                )
            )

        // Indeterminate progress bar only when actively moving — signals "alive, collecting"
        if (!isPaused && isMoving) builder.setProgress(0, 0, true)

        return builder.build()
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
        sessionZones: Int = 0,
        lux: Float? = null,
        hPa: Float? = null,
    ) {
        manager.notify(NOTIFICATION_ID_SERVICE, buildNotification(
            context, lastUpload, isPaused, uploadsToday, totalUploads, zonesTotal,
            motionState, readingsCount, sessionStartMillis, sessionZones, lux, hPa,
        ))
    }

    fun buildWorkerNotification(context: Context): Notification {
        return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(context.getString(R.string.notification_worker_title))
            .setContentText(context.getString(R.string.notification_worker_body))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(
                PendingIntent.getActivity(
                    context, 4, // distinct from service notification (requestCode=0)
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────────

private fun formatDuration(context: Context, elapsedMs: Long): String {
        val totalMin = elapsedMs / 60_000
        val hours = totalMin / 60
        val minutes = totalMin % 60
        return if (hours > 0L)
            context.getString(R.string.notif_duration_hours_min, hours, minutes)
        else
            context.getString(R.string.notif_duration_minutes, minutes)
    }
}
