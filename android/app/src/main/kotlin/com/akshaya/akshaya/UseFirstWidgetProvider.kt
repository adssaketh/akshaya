package com.akshaya.akshaya

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** "Use these first": the most urgent Food rescue entries. */
class UseFirstWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val rowIds = intArrayOf(
            R.id.use_row_0, R.id.use_row_1, R.id.use_row_2, R.id.use_row_3, R.id.use_row_4,
        )
        val count = widgetData.getInt("use_first_count", 0)
        val more = widgetData.getInt("use_first_more", 0)
        val open = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("akshaya://use_first"),
        )
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_use_first).apply {
                setOnClickPendingIntent(R.id.use_root, open)
                for (i in rowIds.indices) {
                    if (i < count) {
                        setTextViewText(rowIds[i], widgetData.getString("use_first_$i", "") ?: "")
                        setViewVisibility(rowIds[i], View.VISIBLE)
                    } else {
                        setViewVisibility(rowIds[i], View.GONE)
                    }
                }
                setViewVisibility(R.id.use_empty, if (count == 0) View.VISIBLE else View.GONE)
                if (more > 0) {
                    setTextViewText(R.id.use_more, "+$more more")
                    setViewVisibility(R.id.use_more, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.use_more, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
