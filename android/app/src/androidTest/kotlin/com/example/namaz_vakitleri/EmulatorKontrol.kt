package com.example.namaz_vakitleri

import android.app.Instrumentation
import android.os.Bundle

/** Test APK only: schedules a labelled real alarm, then exits so adb can
 * force idle or reboot before delivery. Never ships a production test hook. */
object EmulatorKontrol {
    const val ID = 2147483644
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
                    result = "PASS real alarm scheduled id=$ID time=$whenMs mode=$mode"
                }
            } catch (e: Throwable) { failure = e }
        }
        failure?.let { throw it }
        return result
    }
}
