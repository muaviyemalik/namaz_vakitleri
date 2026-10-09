package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.os.Bundle
import android.content.Context
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import com.dexterous.flutterlocalnotifications.models.NotificationDetails
import java.time.Instant
import java.time.ZoneId

/** Test APK only: schedules a labelled real alarm, then exits so adb can
 * force idle or reboot before delivery. Never ships a production test hook. */
object EmulatorKontrol {
    const val ID = 2147483644
    const val REMINDER_ID = 2147483643
    fun run(runner: Instrumentation, args: Bundle): String {
        val c = runner.targetContext
        val backup = c.getSharedPreferences("emulator_check_backup", 0)
        var result = ""
        var failure: Throwable? = null
        runner.runOnMainSync {
            try {
                if (args.getString("emulator") == "cleanup") {
                    EzanServisi.stop(c)
                    EzanAlarmlari.handle(c, "cancel", mapOf("id" to ID))
                    EzanAlarmlari.notificationManager(c).cancel(ID)
                    val pi = PendingIntent.getBroadcast(c, REMINDER_ID,
                        Intent(c, ScheduledNotificationReceiver::class.java),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    c.getSystemService(AlarmManager::class.java).cancel(pi)
                    EzanAlarmlari.notificationManager(c).cancel(REMINDER_ID)
                    if (backup.contains("settings")) {
                        val saved = backup.getString("settings", null)
                        val edit = EzanAlarmlari.prefs(c).edit()
                        if (saved == null) edit.remove("settings") else edit.putString("settings", saved)
                        check(edit.commit())
                    }
                    backup.edit().clear().commit()
                    result = "PASS test alarm removed and original settings restored"
                } else {
                    if (!backup.contains("settings")) {
                        check(backup.edit().putString("settings", EzanAlarmlari.prefs(c).getString("settings", "{}")).commit())
                    }
                    val mode = args.getString("mode", "bildirim")
                    EzanAlarmlari.handle(c, "configure", mapOf("silent" to true, "dnd" to false,
                        "modes" to mapOf("maghrib" to mode)))
                    val whenMs = System.currentTimeMillis() + args.getString("delay", "30000")!!.toLong()
                    EzanAlarmlari.handle(c, "schedule", mapOf("id" to ID, "time" to whenMs,
                        "prayer" to "maghrib", "title" to "AVD alarm testi",
                        "body" to args.getString("label", "Kontrollü test"), "exact" to true))
                    if (args.getString("reminder") == "true") {
                        // Clone a real Flutter-created reminder, changing only test ID/text/time.
                        // Reflection is confined to androidTest and the pinned plugin version.
                        val plugin = FlutterLocalNotificationsPlugin::class.java
                        val load = plugin.getDeclaredMethod("loadScheduledNotifications", Context::class.java).apply { isAccessible = true }
                        val entries = load.invoke(null, c) as List<*>
                        val template = entries.filterIsInstance<NotificationDetails>().first {
                            it.channelId == "erken_uyari_sicak_v1"
                        }
                        // load returns detached models; false below leaves the real cache untouched.
                        val reminder = template
                        reminder.id = REMINDER_ID
                        reminder.title = "AVD erken uyarı testi"
                        reminder.body = "deep-doze-plugin"
                        reminder.payload = "avd-test-reminder"
                        // Deliver in the same allow-while-idle wakeup window as the prayer alarm.
                        reminder.scheduledDateTime = Instant.ofEpochMilli(whenMs).atZone(ZoneId.of(reminder.timeZoneName)).toLocalDateTime().toString()
                        plugin.getDeclaredMethod("zonedScheduleNotification", Context::class.java,
                            NotificationDetails::class.java, java.lang.Boolean::class.java)
                            .apply { isAccessible = true }.invoke(null, c, reminder, false)
                        result += "PASS real plugin reminder scheduled id=$REMINDER_ID time=$whenMs\n"
                    }
                    result += "PASS real alarm scheduled id=$ID time=$whenMs mode=$mode"
                }
            } catch (e: Throwable) { failure = e }
        }
        failure?.let { throw it }
        return result
    }
}
