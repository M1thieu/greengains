package com.eremat.greengains.worker

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
import com.eremat.greengains.notification.NotificationsHelper
import com.eremat.greengains.util.AppPrefs

/**
 * Fires a passive weekly digest Sunday morning: "Your map this week — +X new places."
 * Informative only — no call to action. Uses the existing discovery channel.
 *
 * Self-gates: skips if user has never collected any zones.
 * Stores zones_at_last_digest so next run can compute the weekly delta.
 */
class WeeklyDigestWorker(
    private val context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        const val WORK_NAME = "weekly_digest"
        private const val NOTIFICATION_ID = 5
        private const val PREF_ZONES_AT_LAST_DIGEST = "gg.zones_at_last_digest"
    }

    override suspend fun doWork(): Result {
        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val currentZones = prefs.getInt(AppPrefs.ZONES_TOTAL_COUNT, 0)

        if (currentZones == 0) return Result.success()

        val lastDigestZones = prefs.getInt(PREF_ZONES_AT_LAST_DIGEST, -1)
        prefs.edit().putInt(PREF_ZONES_AT_LAST_DIGEST, currentZones).apply()

        val newThisWeek = if (lastDigestZones >= 0)
            (currentZones - lastDigestZones).coerceAtLeast(0)
        else 0

        fireNotification(currentZones, newThisWeek)
        return Result.success()
    }

    private fun fireNotification(total: Int, newThisWeek: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val tapIntent = PendingIntent.getActivity(
            context, NOTIFICATION_ID,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val body = if (newThisWeek > 0)
            context.getString(R.string.notification_weekly_body_growth, newThisWeek, total)
        else
            context.getString(R.string.notification_weekly_body_stable, total)

        val notification = NotificationCompat.Builder(context, NotificationsHelper.CHANNEL_ID_DISCOVERY)
            .setContentTitle(context.getString(R.string.notification_weekly_title))
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification_leaf)
            .setColor(Color.parseColor("#10B981"))
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }
}
