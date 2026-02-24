package com.example.namaz_vakitleri

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HadisWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_hadis).apply {
                // "kayitli_hadis" verisini çekiyoruz
                val hadisMetni = widgetData.getString("kayitli_hadis", "Hadis bulunamadı. Lütfen uygulamayı açın.")
                setTextViewText(R.id.tv_hadis_metin, hadisMetni)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}