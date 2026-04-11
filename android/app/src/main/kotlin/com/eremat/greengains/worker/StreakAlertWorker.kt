package com.eremat.greengains.worker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.eremat.greengains.MainActivity
import com.eremat.greengains.R
import com.eremat.greengains.util.AppPrefs
import java.time.LocalDate

/**
 * Fires a single streak-at-risk local notification if:
 *   - User has an active streak (>= 2 days)
 *   - No upload recorded today
 *   - We haven't already alerted today
 *
 * Scheduled as a daily PeriodicWorkRequest starting near 8 pm local time.
 * Silent channel — no sound, no vibration. One notification per day max.
 */
class StreakAlertWorker(
    private val context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        const val WORK_NAME = "streak_alert_daily"
        private const val CHANNEL_ID = "streak_reminders"
        private const val NOTIFICATION_ID = 4
        private const val MIN_STREAK_TO_ALERT = 2
    }

    override suspend fun doWork(): Result {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val today = LocalDate.now().toString() // YYYY-MM-DD

        // Dedup — only alert once per day
        val lastAlertDate = prefs.getString(AppPrefs.STREAK_ALERT_DATE, null)
        if (lastAlertDate == today) return Result.success()

        // Check streak — written by Flutter after profile fetch
        val streak = prefs.getInt(AppPrefs.CURRENT_STREAK, 0)
        if (streak < MIN_STREAK_TO_ALERT) return Result.success()

        // Check if user already uploaded today
        val uploadsDate = prefs.getString(AppPrefs.UPLOADS_TODAY_DATE, null)
        val uploadsToday = if (uploadsDate == today) prefs.getInt(AppPrefs.UPLOADS_TODAY_COUNT, 0) else 0
        if (uploadsToday > 0) return Result.success()

        // All conditions met — fire the notification
        fireNotification(streak)
        prefs.edit().putString(AppPrefs.STREAK_ALERT_DATE, today).apply()

        return Result.success()
    }

    private fun fireNotification(streak: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel if needed (idempotent)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_streak_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT, // heads-up capable, but not loud
            ).apply {
                enableVibration(false)
                setSound(null, null)
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }

        val openAppIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(context.getString(R.string.notification_streak_title, streak))
            .setContentText(context.getString(R.string.notification_streak_body))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#10B981"))
            .setAutoCancel(true)
            .setContentIntent(openAppIntent)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }
}
