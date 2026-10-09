package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.graphics.*
import android.view.*
import android.widget.*
import org.json.*
import java.io.File

/** Uses the real RemoteViews renderer and isolated fixtures, leaves real plans alone. */
object WidgetKontrol {
    fun host(runner: Instrumentation): String {
        val c=runner.targetContext
        val manager=android.appwidget.AppWidgetManager.getInstance(c)
        val provider=android.content.ComponentName(c,GunlukVakitWidget::class.java)
        check(manager.installedProviders.count { it.provider.packageName == c.packageName && it.provider.className in WidgetMotoru.providers.map { p -> p.name } } == 4) { "four providers missing" }
        val updates=java.util.concurrent.atomic.AtomicInteger()
        val host=object : android.appwidget.AppWidgetHost(c,724017) {
            override fun onCreateView(context: android.content.Context, id: Int, info: android.appwidget.AppWidgetProviderInfo): android.appwidget.AppWidgetHostView {
                return object : android.appwidget.AppWidgetHostView(context) {
                    override fun updateAppWidget(views: android.widget.RemoteViews?) { super.updateAppWidget(views); updates.incrementAndGet() }
                }
            }
        }
        var id = -1
        try {
            runner.uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
            id=host.allocateAppWidgetId()
            check(manager.bindAppWidgetIdIfAllowed(id,provider)) { "temporary host bind denied" }
            check(manager.getAppWidgetInfo(id).provider == provider) { "provider mismatch" }
            var failure: Throwable? = null
            runner.runOnMainSync { try { host.startListening(); host.createView(c,id,manager.getAppWidgetInfo(id)); WidgetMotoru.refresh(c) } catch(e: Throwable) { failure=e } }
            failure?.let { throw it }
            val deadline=android.os.SystemClock.elapsedRealtime()+10000
            while(updates.get()<2 && android.os.SystemClock.elapsedRealtime()<deadline) android.os.SystemClock.sleep(100)
            check(updates.get()>=2) { "host did not receive RemoteViews" }
            val before=updates.get()
            c.sendBroadcast(android.content.Intent(c,WidgetGuncelleReceiver::class.java).setAction(WidgetMotoru.ACTION))
            val second=android.os.SystemClock.elapsedRealtime()+10000
            while(updates.get()<=before && android.os.SystemClock.elapsedRealtime()<second) android.os.SystemClock.sleep(100)
            check(updates.get()>before) { "native boundary receiver did not update host" }
            return "PASS four registered widget providers\nPASS temporary host binds daily provider\nPASS real AppWidgetHost receives canonical RemoteViews\nPASS native receiver refreshes without Flutter engine"
        } finally {
            host.stopListening()
            if(id>=0) host.deleteAppWidgetId(id)
            host.deleteHost()
            WidgetMotoru.schedule(c)
            runner.uiAutomation.dropShellPermissionIdentity()
        }
    }
    fun run(runner: Instrumentation): String {
        val c = runner.targetContext
        val log = mutableListOf<String>()
        fun verify(ok: Boolean, name: String) { check(ok) { name }; log.add("PASS $name") }
        val p = WidgetMotoru.snapshot(c)
        val days = p.optJSONArray("days")
        verify(days != null && days.length() > 1, "canonical future timeline saved")
        val first = days!!.getJSONObject(0)
        val second = days.getJSONObject(1)
        val prayers = first.getJSONArray("prayers")
        val early = prayers.getJSONObject(0).getLong("at") - 60000
        val afterIsha = prayers.getJSONObject(5).getLong("at") + 60000
        verify(WidgetMotoru.next(p,early)!!.getLong("at") == prayers.getJSONObject(0).getLong("at"), "next prayer before fajr")
        verify(WidgetMotoru.next(p, prayers.getJSONObject(0).getLong("at"))!!.getString("key") == "sunrise", "exact prayer boundary advances")
        verify(WidgetMotoru.next(p,afterIsha)!!.getLong("at") == second.getJSONArray("prayers").getJSONObject(0).getLong("at"), "tomorrow actual fajr, not today's hour")
        verify(WidgetMotoru.current(p,second.getLong("start"))!!.getString("date") == second.getString("date"), "midnight changes all six times and content")
        val last = days.getJSONObject(days.length()-1)
        verify(WidgetMotoru.current(p,last.getLong("end")) == null && WidgetMotoru.next(p,last.getLong("end")) == null, "expired coverage never reuses stale times")
        val gap = JSONObject(p.toString()).apply { put("days", JSONArray().put(first).put(JSONObject(second.toString()).put("start",second.getLong("start")+86400000).put("end",second.getLong("end")+86400000))) }
        verify(WidgetMotoru.next(gap,afterIsha) == null, "missing tomorrow never jumps across a gap")
        val previous = WidgetMotoru.prefs(c).getString("snapshot",null)
        try { WidgetMotoru.publish(c,"{\"version\":99,\"days\":[]}"); error("invalid version accepted") } catch (_: IllegalArgumentException) {}
        verify(WidgetMotoru.prefs(c).getString("snapshot",null) == previous,"invalid snapshot preserves previous atomic record")

        var problem: Throwable? = null
        runner.runOnMainSync {
            try {
                val density = c.resources.displayMetrics.density
                fun capture(kind: String, width: Int, height: Int, source: JSONObject, name: String): View {
                    val rv = WidgetMotoru.render(c,kind,source,early,width,height)
                    val view = rv.apply(c,null)
                    val w=(width*density).toInt(); val h=(height*density).toInt()
                    view.measure(View.MeasureSpec.makeMeasureSpec(w,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(h,View.MeasureSpec.EXACTLY))
                    view.layout(0,0,w,h)
                    val bitmap=Bitmap.createBitmap(w,h,Bitmap.Config.ARGB_8888)
                    view.draw(Canvas(bitmap))
                    File(c.getExternalFilesDir(null),"widget-$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
                    bitmap.recycle()
                    return view
                }
                val daily=capture("daily",320,250,p,"light")
                verify(daily.findViewById<TextView>(R.id.widget_time_0).text.toString() == prayers.getJSONObject(0).getString("time"),"six-time native layout uses canonical hours")
                verify(daily.findViewById<Chronometer>(R.id.widget_countdown).isCountDown,"native countdown configured")
                val dark=JSONObject(p.toString()).put("colors",JSONObject().put("surface",0xff13131cL).put("card",0xff20202bL).put("primary",0xffcebdffL).put("accent",0xff4b3a70L).put("onAccent",0xffecdfffL).put("text",0xffe8e0efL).put("muted",0xffcbc3d5L).put("outline",0xff494453L))
                val darkView=capture("daily",320,250,dark,"dark")
                verify(darkView.findViewById<TextView>(R.id.widget_next).currentTextColor == 0xffcebdff.toInt(),"selected app palette applied to native text")
                val compact=capture("compact",160,170,p,"compact")
                verify(compact.findViewById<Chronometer>(R.id.widget_countdown).bottom <= compact.height,"compact countdown fits")
                val ayah=capture("ayah",320,200,p,"ayah")
                verify(ayah.findViewById<TextView>(R.id.widget_reference).text.toString() == first.getString("ayahSource"),"ayah source separate and visible")
                capture("hadith",320,200,p,"hadith")
                val stale=capture("daily",320,250,JSONObject(p.toString()).put("days",JSONArray()),"expired")
                verify(stale.findViewById<Chronometer>(R.id.widget_countdown).visibility == View.GONE,"expired data hides countdown")
            } catch (e: Throwable) { problem=e }
        }
        problem?.let { throw it }
        return log.joinToString("\n")
    }
}
