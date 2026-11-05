package com.akshaya.akshaya

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** The shopping list with check-off: tapping a row ticks it without opening the app. */
class ShoppingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val rowIds = intArrayOf(
            R.id.shop_row_0, R.id.shop_row_1, R.id.shop_row_2,
            R.id.shop_row_3, R.id.shop_row_4, R.id.shop_row_5,
        )
        val count = widgetData.getInt("shop_count", 0)
        val more = widgetData.getInt("shop_more", 0)
        val open = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("akshaya://shopping"),
        )
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_shopping).apply {
                setOnClickPendingIntent(R.id.shop_title, open)
                for (i in rowIds.indices) {
                    if (i < count) {
                        val id = widgetData.getString("shop_id_$i", "") ?: ""
                        val text = widgetData.getString("shop_text_$i", "") ?: ""
                        val checked = widgetData.getBoolean("shop_checked_$i", false)
                        setTextViewText(rowIds[i], (if (checked) "☑  " else "☐  ") + text)
                        setInt(
                            rowIds[i],
                            "setPaintFlags",
                            if (checked) Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG
                            else Paint.ANTI_ALIAS_FLAG,
                        )
                        setViewVisibility(rowIds[i], View.VISIBLE)
                        val toggle = HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            Uri.parse("akshaya://check?id=" + Uri.encode(id)),
                        )
                        setOnClickPendingIntent(rowIds[i], toggle)
                    } else {
                        setViewVisibility(rowIds[i], View.GONE)
                    }
                }
                setViewVisibility(R.id.shop_empty, if (count == 0) View.VISIBLE else View.GONE)
                if (more > 0) {
                    setTextViewText(R.id.shop_more, "+$more more")
                    setViewVisibility(R.id.shop_more, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.shop_more, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
