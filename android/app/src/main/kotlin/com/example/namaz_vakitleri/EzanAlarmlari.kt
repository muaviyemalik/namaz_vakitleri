package com.example.namaz_vakitleri

import android.app.*
import android.content.*
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import org.json.JSONObject

/** Receivers consume only the canonical Flutter plan, no second prayer-time engine. */
object EzanAlarmlari {
    const val CHANNEL = "vakit_sessiz_v1"
    const val PREFS = "ezan_native_v1"
    const val ACTION = "com.example.namaz_vakitleri.EZAN"
    fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun notificationManager(c: Context) = c.getSystemService(NotificationManager::class.java)
    private fun alarms(c: Context) = c.getSystemService(AlarmManager::class.java)
    private fun pending(c: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(
        c, id, Intent(c, EzanAlarmReceiver::class.java).setAction(ACTION).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun handle(c: Context, method: String, args: Map<*, *>): Any? {
        when (method) {
            "schedule" -> {
                val id = (args["id"] as Number).toInt()
                require(args["prayer"] in listOf("fajr", "dhuhr", "asr", "maghrib", "isha"))
                val event = JSONObject(args)
                val old = prefs(c).getString("alarm_$id", null)
                check(prefs(c).edit().putString("alarm_$id", event.toString()).commit())
                try { schedule(c, id, event) } catch (e: Exception) {
                    val edit = prefs(c).edit()
                    if (old == null) edit.remove("alarm_$id") else edit.putString("alarm_$id", old)
                    edit.commit()
                    throw e
                }
            }
            "cancel" -> {
                val id = (args["id"] as Number).toInt()
                alarms(c).cancel(pending(c, id))
                check(prefs(c).edit().remove("alarm_$id").commit())
                if (EzanServisi.activeId == id) EzanServisi.stop(c)
            }
            "configure" -> {
                check(prefs(c).edit().putString("settings", JSONObject(args).toString()).commit())
                EzanServisi.settingsChanged(c)
            }
            "policyAccess" -> return notificationManager(c).isNotificationPolicyAccessGranted
            "settings" -> {
                val type = args["type"]
                val action = if (type == "dnd") Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS
                    else if (type == "exact" && Build.VERSION.SDK_INT >= 31) Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
                    else Settings.ACTION_APP_NOTIFICATION_SETTINGS
                val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (type == "exact" && Build.VERSION.SDK_INT >= 31)
                    intent.data = android.net.Uri.parse("package:${c.packageName}")
                else intent.putExtra(Settings.EXTRA_APP_PACKAGE, c.packageName)
                c.startActivity(intent)
            }
            "preview" -> {
                val sound = args["sound"] as? String ?: "hatirlatici"
                require(sound in listOf("hatirlatici", "fajr", "dhuhr", "asr", "maghrib", "isha"))
                EzanServisi.preview(c, sound)
            }
            "stop" -> EzanServisi.stop(c)
            "stopPreview" -> EzanServisi.stopPreview()
            else -> throw IllegalArgumentException("Unknown method: $method")
        }
        return null
    }
    private fun schedule(c: Context, id: Int, event: JSONObject) {
        val whenMs = event.getLong("time")
        if (whenMs <= System.currentTimeMillis()) return
        val am = alarms(c)
        if (event.optBoolean("exact", true)) {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms())
                throw SecurityException("Exact alarm permission missing")
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pending(c, id))
        } else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pending(c, id))
    }
    fun restore(c: Context) {
        val now = System.currentTimeMillis()
        for ((key, value) in prefs(c).all) {
            if (!key.startsWith("alarm_") || value !is String) continue
            try {
                val id = key.removePrefix("alarm_").toInt()
                val event = JSONObject(value)
                if (event.getLong("time") <= now) {
                    prefs(c).edit().remove(key).apply()
                    continue
                }
                try { schedule(c, id, event) } catch (_: SecurityException) {
                    event.put("exact", false)
                    schedule(c, id, event)
                }
            } catch (e: Exception) { android.util.Log.e("Ezan", "Restore failed: $key", e) }
        }
    }
    fun mode(c: Context, prayer: String): String =
        JSONObject(prefs(c).getString("settings", "{}")!!)
            .optJSONObject("modes")?.optString(prayer, "ezan") ?: "ezan"
    fun mayPlay(c: Context, prayer: String): Boolean {
        if (mode(c, prayer) != "ezan") return false
        val settings = JSONObject(prefs(c).getString("settings", "{}")!!)
        val nm = notificationManager(c)
        if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE)
            return false
        if (nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL &&
            (!settings.optBoolean("dnd", false) || !nm.isNotificationPolicyAccessGranted)) return false
        val audio = c.getSystemService(AudioManager::class.java)
        if (!settings.optBoolean("silent", true) && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
        return true
    }
    fun channels(c: Context, name: String) {
        if (Build.VERSION.SDK_INT >= 26) notificationManager(c).createNotificationChannel(
            NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null); enableVibration(false)
            })
    }
    fun notification(c: Context, event: JSONObject, ringing: Boolean,
                     session: android.media.session.MediaSession? = null): Notification {
        channels(c, event.optString("channel", c.getString(R.string.app_name)))
        val launch = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        builder.setSmallIcon(R.drawable.ic_stat_namaz).setContentTitle(event.optString("title"))
            .setContentText(event.optString("body")).setContentIntent(launch)
            .setCategory(if (ringing) Notification.CATEGORY_ALARM else Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setOngoing(ringing)
            .setAutoCancel(!ringing).setOnlyAlertOnce(true).setSound(null)
        if (ringing) {
            val stop = PendingIntent.getBroadcast(c, 0, Intent(c, EzanStopReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(Notification.Action.Builder(null, event.optString("stop", "Durdur"), stop).build())
            if (session != null) builder.setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0))
        }
        return builder.build()
    }
}
class EzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action != EzanAlarmlari.ACTION) return
        val id = intent.getIntExtra("id", -1)
        val stored = EzanAlarmlari.prefs(c).getString("alarm_$id", null) ?: return
        val event = JSONObject(stored)
        val now = System.currentTimeMillis()
        if (event.getLong("time") > now + 1000) return
        EzanAlarmlari.prefs(c).edit().remove("alarm_$id").commit()
        PlanYenileme.request(c, false)
        val prayer = event.getString("prayer")
        if (EzanAlarmlari.mode(c, prayer) == "kapali") return
        try {
            EzanAlarmlari.notificationManager(c).notify(id, EzanAlarmlari.notification(c, event, false))
            if (now - event.getLong("time") > 120000 || !EzanAlarmlari.mayPlay(c, prayer)) return
            val service = Intent(c, EzanServisi::class.java).putExtra("event", event.toString()).putExtra("id", id)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(service) else c.startService(service)
        } catch (e: Exception) { android.util.Log.e("Ezan", "Audio unavailable; time notification retained", e) }
    }
}
class EzanBootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        // Future alarms only; no mediaPlayback service from BOOT_COMPLETED.
        EzanAlarmlari.restore(c)
        PlanYenileme.request(c, true)
    }
}
class EzanStopReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) { EzanServisi.stop(c) }
}
