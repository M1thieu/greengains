package com.eremat.greengains.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.eremat.greengains.MainActivity
import com.eremat.greengains.R

class GreenGainsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        for (id in ids) renderWidget(context, manager, id, prefs)
    }

    companion object {
        const val PREFS_NAME = "GreenGainsWidgetPrefs"
        private const val KEY_ZONE_COUNT = "zone_count"
        private const val KEY_STREAK = "streak"
        private const val KEY_IS_ACTIVE = "is_active"

        fun updateAll(context: Context, zones: Int, streak: Int, isActive: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putInt(KEY_ZONE_COUNT, zones)
                .putInt(KEY_STREAK, streak)
                .putBoolean(KEY_IS_ACTIVE, isActive)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, GreenGainsWidgetProvider::class.java)
            )
            for (id in ids) renderWidget(context, manager, id, prefs)
        }

        private fun renderWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            prefs: SharedPreferences,
        ) {
            val zones = prefs.getInt(KEY_ZONE_COUNT, 0)
            val streak = prefs.getInt(KEY_STREAK, 0)
            val isActive = prefs.getBoolean(KEY_IS_ACTIVE, false)

            val views = RemoteViews(context.packageName, R.layout.greengains_widget)
            views.setTextViewText(R.id.widget_zone_count, zones.toString())

            if (streak >= 1) {
                val streakText = context.resources.getQuantityString(
                    R.plurals.widget_streak, streak, streak
                )
                views.setTextViewText(R.id.widget_streak, streakText)
                views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_streak, View.GONE)
            }

            views.setViewVisibility(
                R.id.widget_active,
                if (isActive) View.VISIBLE else View.GONE
            )

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }
    }
}
