package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.os.SystemClock
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Exercises real WorkManager + headless Dart + real system alarms. Only test
 * APK. Keeps selected city/theme/settings, never changes clock or internet. */
object PlanKontrol {
    fun run(runner: Instrumentation): String {
        val c = runner.targetContext
        val wm = WorkManager.getInstance(c)
        val log = mutableListOf<String>()
        fun verify(b: Boolean, name: String) { check(b) { name }; log.add("PASS $name") }
        fun main(block: () -> Unit) {
            var error: Throwable? = null
            runner.runOnMainSync { try { block() } catch (e: Throwable) { error = e } }
            error?.let { throw it }
        }
        val p = PlanYenileme.prefs(c)
        val context = p.getString("context", null)!!
        val original = JSONObject(context)
        fun renew(): JSONObject {
            p.edit().putLong("lastSuccess", 0).commit()
            val work = OneTimeWorkRequest.Builder(PlanYenilemeWorker::class.java)
                .setInputData(Data.Builder().putBoolean("force", true).build()).build()
            wm.enqueueUniqueWork("renewal-device-check", ExistingWorkPolicy.REPLACE, work).result.get(10, TimeUnit.SECONDS)
            val deadline = SystemClock.elapsedRealtime() + 90000
            var state: WorkInfo.State? = null
            while (SystemClock.elapsedRealtime() < deadline) {
                state = wm.getWorkInfoById(work.id).get(5, TimeUnit.SECONDS)?.state
                if (state?.isFinished == true) break
                if (p.getLong("lastSuccess", 0) > 0) break
                SystemClock.sleep(100)
            }
            check(p.getLong("lastSuccess", 0) > 0) { "Worker failed: $state ${p.getString("report", "none")}" }
            return JSONObject(p.getString("report", "{}")!!)
        }
        try {
            verify(!PlanYenileme.visible, "no foreground Activity needed")
            val old = WidgetMotoru.snapshot(c)
            val initial = JSONArray()
            val oldDays = old.getJSONArray("days")
            for (i in 0 until minOf(8, oldDays.length())) initial.put(oldDays.getJSONObject(i))
            old.put("days", initial)
            main { WidgetMotoru.publish(c, old.toString()) }
            verify(WidgetMotoru.snapshot(c).getJSONArray("days").length() <= 8, "legacy 8-day snapshot prepared")
            val report = renew()
            verify(report.getInt("days") == 30, "headless WorkManager extends to 30 days")
            verify(report.getString("source") == "resmiDiyanet", "canonical embedded Diyanet source")
            val timeline = WidgetMotoru.snapshot(c)
            verify(timeline.getJSONArray("days").length() == 30, "widget renewed without Flutter screen")
            verify(timeline.getJSONObject("colors").toString() == original.getJSONObject("colors").toString(), "original app palette preserved")
            verify(timeline.getString("language") == original.getString("language"), "selected language preserved")
            verify(p.getString("context", null) == context, "selected source context unchanged")
            val events = EzanAlarmlari.prefs(c).all.filterKeys { it.startsWith("alarm_") }
                .values.filterIsInstance<String>().map { JSONObject(it) }
            verify(events.size >= 145, "30 days of real native prayer alarms stored")
            verify(events.all { it.getLong("time") > System.currentTimeMillis() }, "future-only alarms, no late playback")
            val lastDay = timeline.getJSONArray("days").getJSONObject(29)
            val lastFajr = lastDay.getJSONArray("prayers").getJSONObject(0).getLong("at")
            verify(events.any { it.getString("prayer") == "fajr" && it.getLong("time") == lastFajr }, "last-day alarm exactly matches canonical widget UTC")
            val periodic = wm.getWorkInfosForUniqueWork(PlanYenileme.PERIODIC).get(10, TimeUnit.SECONDS)
            verify(periodic.count { !it.state.isFinished } == 1, "one persistent periodic renewal, no duplicates")
            main {
                val lease = PlanYenileme.begin(c)
                verify(PlanYenileme.busy(), "foreground plan excludes background writer")
                PlanYenileme.end(c, lease)
                verify(!PlanYenileme.busy(), "foreground lease released")
            }
            val before = EzanAlarmlari.prefs(c).all.filterKeys { it.startsWith("alarm_") }.size
            // Unknown timezone simulates unavailable current-day data. Job must
            // fail safely without erasing the healthy future alarm plan.
            val invalid = JSONObject(context)
            invalid.getJSONObject("renewal").getJSONObject("location").put("zone", "Invalid/Timezone")
            p.edit().putString("context", invalid.toString()).putLong("lastSuccess", 0).commit()
            val work = OneTimeWorkRequest.Builder(PlanYenilemeWorker::class.java)
                .setInputData(Data.Builder().putBoolean("force", true).build()).build()
            val stamp = p.getLong("lastAttempt", 0)
            wm.enqueueUniqueWork("renewal-device-check", ExistingWorkPolicy.REPLACE, work).result.get(10, TimeUnit.SECONDS)
            val end = SystemClock.elapsedRealtime() + 45000
            while (p.getLong("lastAttempt", 0) <= stamp && SystemClock.elapsedRealtime() < end) SystemClock.sleep(100)
            verify(!JSONObject(p.getString("report", "{}")!!).optBoolean("ok", true), "bad timezone rejected")
            verify(EzanAlarmlari.prefs(c).all.filterKeys { it.startsWith("alarm_") }.size == before, "failed renewal preserves existing real alarms")
        } finally {
            wm.cancelUniqueWork("renewal-device-check").result.get(10, TimeUnit.SECONDS)
            main { PlanYenileme.foreground() }
            p.edit().putString("context", context).putLong("lastSuccess", 0).commit()
            renew()
            wm.cancelUniqueWork("renewal-device-check").result.get(10, TimeUnit.SECONDS)
        }
        return log.joinToString("\n")
    }
}
