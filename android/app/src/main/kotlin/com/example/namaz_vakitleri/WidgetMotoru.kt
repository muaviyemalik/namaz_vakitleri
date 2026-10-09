package com.example.namaz_vakitleri

import android.app.*
import android.appwidget.*
import android.content.*
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.view.View
import android.widget.RemoteViews
import org.json.*
import java.text.SimpleDateFormat
import java.util.*

/** A persisted canonical timeline, no network/Flutter engine or prayer calculation. */
object WidgetMotoru {
    const val PREFS = "widget_timeline_v1"
    const val ACTION = "com.example.namaz_vakitleri.WIDGET_BOUNDARY"
    val providers = listOf(VakitWidget::class.java, GunlukVakitWidget::class.java, AyetWidget::class.java, HadisWidget::class.java)
    fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun publish(c: Context, raw: String) {
        require(raw.length <= 512000)
        val p = JSONObject(raw)
        require(p.getInt("version") == 1)
        val days = p.getJSONArray("days")
        require(days.length() <= 30)
        if (days.length() > 0) require(p.getString("zone") in TimeZone.getAvailableIDs())
        var previous = Long.MIN_VALUE
        for (i in 0 until days.length()) {
            val d = days.getJSONObject(i)
            val start = d.getLong("start"); val end = d.getLong("end")
            require(start > previous && end > start); previous = start
            val times = d.getJSONArray("prayers")
            require(times.length() == 6)
            var last = start
            for (j in 0..5) {
                val t = times.getJSONObject(j).getLong("at")
                require(t > last && t < end); last = t
            }
        }
        check(prefs(c).edit().putString("snapshot", raw).commit())
        refresh(c)
    }
    fun snapshot(c: Context): JSONObject = try {
        JSONObject(prefs(c).getString("snapshot", "{}")!!)
    } catch (_: Exception) { JSONObject() }
    fun current(p: JSONObject, now: Long): JSONObject? {
        val days = p.optJSONArray("days") ?: return null
        for (i in 0 until days.length()) {
            val d = days.getJSONObject(i)
            if (now >= d.getLong("start") && now < d.getLong("end")) return d
        }
        return null
    }
    fun next(p: JSONObject, now: Long): JSONObject? {
        // A missing current day is a coverage gap, never silently jump over it.
        val today = current(p, now) ?: return null
        val days = p.optJSONArray("days") ?: return null
        for (i in 0 until days.length()) {
            val d = days.getJSONObject(i)
            if (d.getLong("start") < today.getLong("start")) continue
            if (d.getLong("start") > today.getLong("end")) return null
            val times = d.getJSONArray("prayers")
            for (j in 0..5) if (times.getJSONObject(j).getLong("at") > now) return times.getJSONObject(j)
        }
        return null
    }
    private fun color(p: JSONObject, key: String): Int = p.optJSONObject("colors")?.optLong(key, when(key) {
        "primary" -> 0xff00695c; "accent" -> 0xffb2dfdb; "onAccent" -> 0xff003d35
        "text" -> 0xff172420; "muted" -> 0xff54635f; "outline" -> 0xffc6d5d0
        "card" -> 0xffeff5f2; else -> 0xfffbfdfb
    })?.toInt() ?: when(key) { "primary" -> Color.rgb(0,105,92); "text" -> Color.DKGRAY; "muted" -> Color.GRAY; else -> Color.WHITE }
    private fun label(p: JSONObject, key: String, fallback: String) = p.optJSONObject("labels")?.optString(key, fallback) ?: fallback
    private fun background(c: Context, width: Int, height: Int, first: Int, second: Int, stroke: Int): Bitmap {
        val density = c.resources.displayMetrics.density
        val w = (width * density).toInt().coerceIn(120, 1400)
        val h = (height * density).toInt().coerceIn(120, 1400)
        return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply {
            val d = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(first, second))
            d.cornerRadius = 22 * density; d.setStroke(maxOf(1, density.toInt()), stroke)
            d.setBounds(0, 0, w, h); d.draw(Canvas(this))
        }
    }
    fun render(c: Context, kind: String, p: JSONObject = snapshot(c), now: Long = System.currentTimeMillis(), width: Int = 320, height: Int = 240): RemoteViews {
        val layout = when (kind) { "daily" -> R.layout.widget_gunluk; "ayah" -> R.layout.widget_ayet; "hadith" -> R.layout.widget_hadis; else -> R.layout.widget_vakit }
        val v = RemoteViews(c.packageName, layout)
        v.setInt(R.id.widget_root, "setLayoutDirection", if(p.optString("language") in listOf("ara","fas")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        v.setImageViewBitmap(R.id.widget_background, background(c, width, height, color(p,"surface"), color(p,"card"), color(p,"outline")))
        val launch = PendingIntent.getActivity(c, 40, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        v.setOnClickPendingIntent(R.id.widget_root, launch)
        val today = current(p, now)
        val upcoming = next(p, now)
        val zone = p.optString("zone").takeIf { it in TimeZone.getAvailableIDs() }
        val date = SimpleDateFormat("dd.MM.yyyy", Locale.ROOT).apply { timeZone = TimeZone.getTimeZone(zone ?: TimeZone.getDefault().id) }.format(Date(now))
        v.setTextViewText(R.id.widget_city, p.optString("city"))
        v.setTextViewText(R.id.widget_date, date)
        v.setTextColor(R.id.widget_city, color(p,"text")); v.setTextColor(R.id.widget_date, color(p,"muted"))
        val unavailable = label(p,"open", c.getString(R.string.widget_vakit_acilis))
        if (kind == "ayah" || kind == "hadith") {
            val ayah = kind == "ayah"
            v.setTextViewText(R.id.widget_title, label(p, if(ayah) "ayahTitle" else "hadithTitle", c.getString(if(ayah) R.string.widget_ayet_baslik else R.string.widget_hadis_baslik)))
            v.setTextViewText(R.id.widget_content, today?.optString(if(ayah) "ayah" else "hadith") ?: unavailable)
            v.setTextViewText(R.id.widget_reference, today?.optString(if(ayah) "ayahSource" else "hadithSource") ?: "")
            v.setTextColor(R.id.widget_title, color(p,"primary")); v.setTextColor(R.id.widget_content, color(p,"text")); v.setTextColor(R.id.widget_reference, color(p,"primary"))
            return v
        }
        v.setTextViewText(R.id.widget_title, label(p,"nextTitle", c.getString(R.string.widget_vakit_baslik)))
        v.setTextViewText(R.id.widget_next, upcoming?.optString("label") ?: unavailable)
        v.setTextViewText(R.id.widget_next_time, upcoming?.optString("time") ?: "—")
        v.setTextColor(R.id.widget_title, color(p,"muted")); v.setTextColor(R.id.widget_next, color(p,"primary")); v.setTextColor(R.id.widget_next_time, color(p,"muted"))
        v.setTextColor(R.id.widget_countdown, color(p,"text"))
        val am = c.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        // No negative clock when exact access is unavailable: show the target
        // time and honest approximate-update status instead of a stale countdown.
        val counting = upcoming != null && exact
        v.setViewVisibility(R.id.widget_countdown, if (counting) View.VISIBLE else View.GONE)
        if (counting) {
            v.setChronometerCountDown(R.id.widget_countdown, true)
            v.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime() + upcoming!!.getLong("at") - now, null, true)
        } else v.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false)
        v.setTextViewText(R.id.widget_source, if (today == null) unavailable else if (!exact) label(p,"approximate", unavailable) else p.optString("source"))
        v.setTextColor(R.id.widget_source, color(p,"muted"))
        if (kind == "daily") {
            val names = intArrayOf(R.id.widget_name_0,R.id.widget_name_1,R.id.widget_name_2,R.id.widget_name_3,R.id.widget_name_4,R.id.widget_name_5)
            val times = intArrayOf(R.id.widget_time_0,R.id.widget_time_1,R.id.widget_time_2,R.id.widget_time_3,R.id.widget_time_4,R.id.widget_time_5)
            val backgrounds = intArrayOf(R.id.widget_tile_0,R.id.widget_tile_1,R.id.widget_tile_2,R.id.widget_tile_3,R.id.widget_tile_4,R.id.widget_tile_5)
            val keys = listOf("fajr","sunrise","dhuhr","asr","maghrib","isha")
            for (i in 0..5) {
                val prayer = today?.getJSONArray("prayers")?.getJSONObject(i)
                val selected = prayer != null && upcoming?.optLong("at") == prayer.getLong("at")
                v.setTextViewText(names[i], prayer?.optString("label") ?: label(p,keys[i], "—"))
                v.setTextViewText(times[i], prayer?.optString("time") ?: "—")
                v.setTextColor(names[i], color(p,if(selected) "onAccent" else "muted"))
                v.setTextColor(times[i], color(p,if(selected) "onAccent" else "text"))
                v.setImageViewBitmap(backgrounds[i], background(c, 100, 60, color(p,if(selected) "accent" else "surface"), color(p,if(selected) "accent" else "surface"), color(p,"outline")))
            }
        }
        return v
    }
    fun update(c: Context, provider: Class<*>, ids: IntArray) {
        val kind = when(provider) { GunlukVakitWidget::class.java -> "daily"; AyetWidget::class.java -> "ayah"; HadisWidget::class.java -> "hadith"; else -> "compact" }
        val manager = AppWidgetManager.getInstance(c)
        val p = snapshot(c)
        for(id in ids) {
            val options = manager.getAppWidgetOptions(id)
            manager.updateAppWidget(id, render(c, kind, p, width=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,320), height=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,240)))
        }
    }
    fun refresh(c: Context) {
        val manager = AppWidgetManager.getInstance(c)
        for (provider in providers) update(c, provider, manager.getAppWidgetIds(ComponentName(c,provider)))
        schedule(c)
    }
    fun schedule(c: Context) {
        val manager = AppWidgetManager.getInstance(c)
        val am = c.getSystemService(AlarmManager::class.java)
        val pi = PendingIntent.getBroadcast(c, 41, Intent(c,WidgetGuncelleReceiver::class.java).setAction(ACTION), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        am.cancel(pi)
        if (providers.none { manager.getAppWidgetIds(ComponentName(c,it)).isNotEmpty() }) return
        val now = System.currentTimeMillis()
        val p = snapshot(c)
        val today = current(p,now) ?: return
        val boundary = minOf(next(p,now)?.getLong("at") ?: Long.MAX_VALUE, today.getLong("end"))
        try {
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) am.setExact(AlarmManager.RTC, boundary, pi)
            else am.set(AlarmManager.RTC, boundary, pi)
        } catch (_: SecurityException) { am.set(AlarmManager.RTC,boundary,pi) }
    }
}

open class TemaliWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, manager: AppWidgetManager, ids: IntArray) { WidgetMotoru.update(c,javaClass,ids); WidgetMotoru.schedule(c) }
    override fun onAppWidgetOptionsChanged(c: Context, manager: AppWidgetManager, id: Int, options: Bundle) { onUpdate(c,manager,intArrayOf(id)) }
    override fun onDisabled(c: Context) { WidgetMotoru.schedule(c) }
}
class GunlukVakitWidget : TemaliWidget()
class WidgetGuncelleReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) { WidgetMotoru.refresh(c) }
}
