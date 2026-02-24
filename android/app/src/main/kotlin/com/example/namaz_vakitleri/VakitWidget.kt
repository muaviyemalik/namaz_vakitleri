package com.example.namaz_vakitleri

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class VakitWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_vakit).apply {
                // Bu sefer iki farklı veri çekiyoruz (Vaktin adı ve Saati)
                val vakitAd = widgetData.getString("kayitli_vakit_ad", "Lütfen Uygulamayı")
                val vakitSaat = widgetData.getString("kayitli_vakit_saat", "Açın")
                
                setTextViewText(R.id.tv_vakit_ad, vakitAd)
                setTextViewText(R.id.tv_vakit_saat, vakitSaat)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}