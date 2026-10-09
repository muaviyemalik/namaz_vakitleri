package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.os.SystemClock
import org.json.JSONObject

/** Device test runner, never packaged in the user's app. Preserves real plans/settings. */
class EzanKontrolRunner : Instrumentation() {
    private val log = mutableListOf<String>()
    private var id = 2147483600
    private val testIds = mutableListOf<Int>()
    private var widgetTest = false
    private var widgetHost = false
    private var renewalTest = false
    private var emulatorArgs: Bundle? = null
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); emulatorArgs = arguments?.takeIf { it.containsKey("emulator") }; renewalTest = arguments?.getString("renewal") == "true"; widgetTest = arguments?.getString("widget") in listOf("true", "host"); widgetHost = arguments?.getString("widget") == "host"; start() }
    private fun shell(command: String): String {
        return uiAutomation.executeShellCommand(command).use { fd ->
            java.io.FileInputStream(fd.fileDescriptor).readBytes().toString(Charsets.UTF_8)
        }
    }
    private fun hasNotification(c: Context): Boolean {
        // NotificationManager publishes asynchronously after foreground removal.
        val deadline = SystemClock.elapsedRealtime() + 5000
        do {
            if (shell("cmd notification list").lineSequence().any { it.contains("|${c.packageName}|$id|") }) return true
            SystemClock.sleep(100)
        } while (SystemClock.elapsedRealtime() < deadline)
        return false
    }
    private fun verify(condition: Boolean, name: String) {
        check(condition) { name }; log.add("PASS $name")
    }
    private fun schedule(c: Context, prayer: String = "maghrib") {
        // Real prayers have distinct IDs; do not race asynchronous FGS removal
        // against a new alarm reusing the same notification ID in this matrix.
        id++
        check(!EzanAlarmlari.prefs(c).contains("alarm_$id")) { "Test ID collides with a real plan" }
        check(!shell("cmd notification list").contains("|${c.packageName}|$id|")) { "Test ID collides with an existing notification" }
        testIds.add(id)
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
        emulatorArgs?.let { args ->
            try {
                val report = EmulatorKontrol.run(this@EzanKontrolRunner, args)
                // Some OEMs force-stop the target when instrumentation finishes,
                // cancelling its alarms. Keep this test process alive for delivery.
                val hold = args.getString("hold")?.toLongOrNull()?.coerceIn(0, 300000) ?: 0
                SystemClock.sleep(hold)
                finish(-1, Bundle().apply { putString("stream", "\n" + report) })
            }
            catch(e: Throwable) { finish(0, Bundle().apply { putString("stream", "FAIL " + android.util.Log.getStackTraceString(e)) }) }
            return
        }
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
            // Set the device state as a user would. App API calls on newer SDKs
            // can create an automatic Zen rule and conflate silent mode with DND.
            shell("cmd audio set-ringer-mode SILENT")
            SystemClock.sleep(700)
            main {
                EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to false))
                audio.setStreamVolume(AudioManager.STREAM_ALARM, maxOf(1, volume), 0)
            }
            uiAutomation.dropShellPermissionIdentity()
            verify(audio.ringerMode != AudioManager.RINGER_MODE_NORMAL, "ringer silent")
            log.add("STATE notifications=${nm.areNotificationsEnabled()} filter=${nm.currentInterruptionFilter} channel=${nm.getNotificationChannel(EzanAlarmlari.CHANNEL)?.importance} mode=${EzanAlarmlari.mode(c, "maghrib")}")
            verify(EzanAlarmlari.mayPlay(c, "maghrib"), "silent enabled gate")
            schedule(c)
            verify(EzanServisi.caliyor, "exact alarm background playback in silent mode")
            shell("input keyevent 25")
            SystemClock.sleep(1500)
            if (EzanServisi.caliyor) {
                log.add("FAIL emulator volume key did not stop playback")
                main { EzanServisi.stop(c) }
                SystemClock.sleep(500)
            } else verify(true, "volume down stops current ezan")
            if (hasNotification(c)) verify(true, "prayer notification retained")
            else log.add("FAIL prayer notification not retained after stop")

            main { EzanAlarmlari.handle(c, "configure", mapOf("silent" to false, "dnd" to false)) }
            verify(!EzanAlarmlari.mayPlay(c, "maghrib"), "silent setting off gate")
            main { EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to false)) }
            shell("cmd notification set_dnd priority")
            SystemClock.sleep(700)
            verify(!EzanAlarmlari.mayPlay(c, "maghrib"), "DND suppresses audio")
            schedule(c)
            verify(!EzanServisi.caliyor, "DND alarm delivered without playback")
            verify(hasNotification(c), "DND time notification retained")
            main { EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to true)) }
            verify(EzanAlarmlari.mayPlay(c, "maghrib"), "DND explicitly allowed gate with policy access")
            schedule(c)
            verify(EzanServisi.caliyor, "DND explicitly allowed alarm plays")
            main { EzanServisi.stop(c) }
            SystemClock.sleep(500)
            shell("cmd notification set_dnd off")
            SystemClock.sleep(700)
            schedule(c, "isha")
            verify(EzanServisi.caliyor, "next prayer still plays after dismiss")
            val power = c.getSystemService(android.os.PowerManager::class.java)
            shell(if (power.isInteractive) "input keyevent 223" else "input keyevent 224")
            SystemClock.sleep(1500)
            verify(!EzanServisi.caliyor, "screen transition stops ezan")
            verify(hasNotification(c), "screen dismiss retains notification")
        } catch (e: Throwable) { error = e; log.add("FAIL ${e.message}") }
        finally {
            main {
                EzanServisi.stop(c)
                for (testId in testIds) {
                    EzanAlarmlari.handle(c, "cancel", mapOf("id" to testId))
                    nm.cancel(testId)
                }
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
        finish(if (error == null && log.none { it.startsWith("FAIL") }) -1 else 0, result)
    }
}
