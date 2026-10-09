package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.os.SystemClock
import android.view.KeyEvent
import org.json.JSONObject

/** Device test runner, never packaged in the user's app. Preserves real plans/settings. */
class EzanKontrolRunner : Instrumentation() {
    private val log = mutableListOf<String>()
    private val id = 2147483645
    private var widgetTest = false
    private var widgetHost = false
    private var renewalTest = false
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); renewalTest = arguments?.getString("renewal") == "true"; widgetTest = arguments?.getString("widget") in listOf("true", "host"); widgetHost = arguments?.getString("widget") == "host"; start() }
    private fun shell(command: String) {
        uiAutomation.executeShellCommand(command).use { fd ->
            java.io.FileInputStream(fd.fileDescriptor).readBytes()
        }
    }
    private fun verify(condition: Boolean, name: String) {
        check(condition) { name }; log.add("PASS $name")
    }
    private fun schedule(c: Context, prayer: String = "maghrib") {
        val args = mapOf("id" to id, "time" to System.currentTimeMillis() + 3500,
            "prayer" to prayer, "title" to "Ezan testi", "body" to "Etiketli cihaz testi",
            "stop" to "Testi durdur", "exact" to true)
        main { EzanAlarmlari.handle(c, "schedule", args) }
        val shouldPlay = EzanAlarmlari.mayPlay(c, prayer)
        val deadline = SystemClock.elapsedRealtime() + 15000
        while (SystemClock.elapsedRealtime() < deadline &&
            (EzanAlarmlari.prefs(c).contains("alarm_$id") || (shouldPlay && !EzanServisi.caliyor))) SystemClock.sleep(100)
        SystemClock.sleep(500)
    }
    private fun main(block: () -> Unit) {
        var failure: Throwable? = null
        runOnMainSync { try { block() } catch (e: Throwable) { failure = e } }
        failure?.let { throw it }
    }
    override fun onStart() {
        if (renewalTest) {
            try { finish(-1, Bundle().apply { putString("stream", "\n" + PlanKontrol.run(this@EzanKontrolRunner)) }) }
            catch(e: Throwable) { finish(0, Bundle().apply { putString("stream", "FAIL " + android.util.Log.getStackTraceString(e)) }) }
            return
        }
        if (widgetTest) {
            try { finish(-1, Bundle().apply { putString("stream", "\n" + (if (widgetHost) WidgetKontrol.host(this@EzanKontrolRunner) else WidgetKontrol.run(this@EzanKontrolRunner))) }) }
            catch(e: Throwable) { finish(0, Bundle().apply { putString("stream", "FAIL " + android.util.Log.getStackTraceString(e)) }) }
            return
        }
        val c = targetContext
        val prefs = EzanAlarmlari.prefs(c)
        val saved = prefs.getString("settings", null)
        val audio = c.getSystemService(AudioManager::class.java)
        val nm = c.getSystemService(NotificationManager::class.java)
        val ringer = audio.ringerMode
        val dnd = nm.currentInterruptionFilter
        val policy = nm.isNotificationPolicyAccessGranted
        val volume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        var error: Throwable? = null
        try {
            for (resource in listOf(R.raw.ezan_sabah, R.raw.ezan_ogle, R.raw.ezan_ikindi, R.raw.ezan_aksam, R.raw.ezan_yatsi, R.raw.hatirlatici)) {
                val retriever = android.media.MediaMetadataRetriever()
                c.resources.openRawResourceFd(resource).use { retriever.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                verify((retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0) > 1000, "audio decodable $resource")
                retriever.release()
            }
            shell("cmd notification allow_dnd " + c.packageName)
            shell("cmd notification set_dnd off")
            uiAutomation.adoptShellPermissionIdentity("android.permission.MODIFY_AUDIO_SETTINGS", "android.permission.ACCESS_NOTIFICATION_POLICY")
            main { audio.ringerMode = AudioManager.RINGER_MODE_SILENT }
            shell("cmd notification set_dnd off")
            SystemClock.sleep(700)
            main {
                EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to false))
                audio.setStreamVolume(AudioManager.STREAM_ALARM, maxOf(1, volume), 0)
            }
            uiAutomation.dropShellPermissionIdentity()
            verify(audio.ringerMode != AudioManager.RINGER_MODE_NORMAL, "ringer silent")
            verify(EzanAlarmlari.mayPlay(c, "maghrib"), "silent enabled gate")
            schedule(c)
            verify(EzanServisi.caliyor, "exact alarm background playback in silent mode")
            uiAutomation.injectInputEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_VOLUME_DOWN), true)
            uiAutomation.injectInputEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_VOLUME_DOWN), true)
            SystemClock.sleep(1500)
            verify(!EzanServisi.caliyor, "volume down stops current ezan")
            verify(nm.activeNotifications.any { it.id == id }, "prayer notification retained")

            main { EzanAlarmlari.handle(c, "configure", mapOf("silent" to false, "dnd" to false)) }
            verify(!EzanAlarmlari.mayPlay(c, "maghrib"), "silent setting off gate")
            main { EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to false)) }
            shell("cmd notification set_dnd priority")
            SystemClock.sleep(700)
            verify(!EzanAlarmlari.mayPlay(c, "maghrib"), "DND suppresses audio")
            schedule(c)
            verify(!EzanServisi.caliyor, "DND alarm delivered without playback")
            verify(nm.activeNotifications.any { it.id == id }, "DND time notification retained")
            shell("cmd notification set_dnd off")
            SystemClock.sleep(700)
            schedule(c, "isha")
            verify(EzanServisi.caliyor, "next prayer still plays after dismiss")
            val power = c.getSystemService(android.os.PowerManager::class.java)
            shell(if (power.isInteractive) "input keyevent 223" else "input keyevent 224")
            SystemClock.sleep(1500)
            verify(!EzanServisi.caliyor, "screen transition stops ezan")
            verify(nm.activeNotifications.any { it.id == id }, "screen dismiss retains notification")
        } catch (e: Throwable) { error = e; log.add("FAIL ${e.message}") }
        finally {
            main {
                EzanServisi.stop(c)
                EzanAlarmlari.handle(c, "cancel", mapOf("id" to id))
                nm.cancel(id)
                val edit = prefs.edit()
                if (saved == null) edit.remove("settings") else edit.putString("settings", saved)
                edit.commit()
                audio.ringerMode = ringer
                audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
            }
            shell("cmd notification set_dnd " + when (dnd) {
                NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "priority"
                NotificationManager.INTERRUPTION_FILTER_ALARMS -> "alarms"
                NotificationManager.INTERRUPTION_FILTER_NONE -> "none"
                else -> "off"
            })
            if (!policy) shell("cmd notification disallow_dnd " + c.packageName)
            uiAutomation.dropShellPermissionIdentity()
        }
        val result = Bundle().apply { putString("stream", "\n" + log.joinToString("\n")) }
        finish(if (error == null) -1 else 0, result)
    }
}
