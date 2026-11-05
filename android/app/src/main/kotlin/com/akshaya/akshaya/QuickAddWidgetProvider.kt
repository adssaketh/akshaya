package com.akshaya.akshaya

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Three quick-add buttons: Voice, Scan and Add. */
class QuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
                setOnClickPendingIntent(R.id.quick_voice, launch(context, "voice"))
                setOnClickPendingIntent(R.id.quick_scan, launch(context, "scan"))
                setOnClickPendingIntent(R.id.quick_add, launch(context, "add"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launch(context: Context, target: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("akshaya://$target"),
        )
}
