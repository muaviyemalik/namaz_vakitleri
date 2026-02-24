package com.example.namaz_vakitleri // Kendi paket adınla aynı olmalı!

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AyetWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // XML tasarımımızı (View) çağırıyoruz
            val views = RemoteViews(context.packageName, R.layout.widget_ayet).apply {
                // Dart'tan gönderdiğimiz "kayitli_ayet" verisini çekip XML'deki text'e basıyoruz
                val ayetMetni = widgetData.getString("kayitli_ayet", "Ayat bulunamadı. Lütfen uygulamayı açın.")
                setTextViewText(R.id.tv_ayet_metin, ayetMetni)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}