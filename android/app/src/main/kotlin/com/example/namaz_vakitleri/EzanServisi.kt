package com.example.namaz_vakitleri

import android.app.Service
import android.content.*
import android.media.*
import android.media.session.*
import android.os.*
import org.json.JSONObject

/** Single bounded playback; no Flutter engine needed at delivery time. */
class EzanServisi : Service() {
    companion object {
        @Volatile var caliyor = false
        @Volatile var activeId = -1
        private var instance: EzanServisi? = null
        fun stop(c: Context) { instance?.finishPlayback() }
        fun stopPreview() { instance?.let { if (it.preview) it.finishPlayback() } }
        fun settingsChanged(c: Context) {
            instance?.let { if (!it.preview && !EzanAlarmlari.mayPlay(c, it.prayer)) it.finishPlayback() }
        }
        fun preview(c: Context, sound: String) {
            check(instance == null || instance!!.preview || !caliyor) { "A prayer adhan is playing" }
            val intent = Intent(c, EzanServisi::class.java).putExtra("preview", sound)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        }
    }
    private var player: MediaPlayer? = null
    private var session: MediaSession? = null
    private var focus: AudioFocusRequest? = null
    private var event: JSONObject? = null
    private var preview = false
    private var prayer = ""
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finishPlayback() }
    private val audio by lazy { getSystemService(AudioManager::class.java) }
    private val focusListener = AudioManager.OnAudioFocusChangeListener {
        android.util.Log.i("Ezan", "Audio focus change: $it")
        if (it < 0) handler.post { finishPlayback() }
    }
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            android.util.Log.i("Ezan", "State broadcast: ${i.action} allowed=${EzanAlarmlari.mayPlay(c, prayer)}")
            if (i.action == Intent.ACTION_SCREEN_OFF || i.action == Intent.ACTION_SCREEN_ON ||
                (!preview && !EzanAlarmlari.mayPlay(c, prayer))) finishPlayback()
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate(); instance = this
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF).apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(screenReceiver, filter)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        releaseAudio()
        val sample = intent?.getStringExtra("preview")
        preview = sample != null
        activeId = if (preview) 2147483646 else intent?.getIntExtra("id", -1) ?: -1
        event = if (preview) JSONObject().put("title", getString(R.string.app_name))
            .put("body", sample).put("stop", getString(R.string.ezan_stop))
            else intent?.getStringExtra("event")?.let { JSONObject(it) }
        val current = event
        if (current == null || activeId < 0) { stopSelf(); return START_NOT_STICKY }
        prayer = if (preview) sample!! else current.getString("prayer")
        try {
            session = MediaSession(this, "NamazEzan").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onStop() { finishPlayback() }
                    override fun onPause() { finishPlayback() }
                }, handler)
                setPlaybackState(PlaybackState.Builder().setState(PlaybackState.STATE_PLAYING, 0, 1f)
                    .setActions(PlaybackState.ACTION_STOP or PlaybackState.ACTION_PAUSE).build())
                val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                setPlaybackToRemote(object : VolumeProvider(VolumeProvider.VOLUME_CONTROL_RELATIVE, max,
                    audio.getStreamVolume(AudioManager.STREAM_ALARM)) {
                    override fun onAdjustVolume(direction: Int) {
                        if (direction == AudioManager.ADJUST_LOWER || direction == AudioManager.ADJUST_MUTE)
                            handler.post { finishPlayback() }
                        else if (direction == AudioManager.ADJUST_RAISE) {
                            audio.adjustStreamVolume(AudioManager.STREAM_ALARM, direction, 0)
                            setCurrentVolume(audio.getStreamVolume(AudioManager.STREAM_ALARM))
                        }
                    }
                })
                isActive = true
            }
            startForeground(activeId, EzanAlarmlari.notification(this, current, true, session))
            if (!preview && !EzanAlarmlari.mayPlay(this, prayer)) { finishPlayback(); return START_NOT_STICKY }
            // AudioService may see the old process state until the FGS transition settles.
            handler.postDelayed({ if (activeId >= 0) beginPlayback() }, 250)
        } catch (e: Exception) {
            android.util.Log.e("Ezan", "Playback failed", e); finishPlayback()
        }
        return START_NOT_STICKY
    }
    private fun beginPlayback() {
        try {
            if (!preview && !EzanAlarmlari.mayPlay(this, prayer)) { finishPlayback(); return }
            val attributes = AudioAttributes.Builder().setUsage(
                if (preview) AudioAttributes.USAGE_MEDIA else AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
            val granted = if (Build.VERSION.SDK_INT >= 26) {
                focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener, handler).build()
                audio.requestAudioFocus(focus!!)
            } else audio.requestAudioFocus(focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { finishPlayback(); return }
            val resource = when (prayer) {
                "fajr" -> R.raw.ezan_sabah
                "dhuhr" -> R.raw.ezan_ogle
                "asr" -> R.raw.ezan_ikindi
                "maghrib" -> R.raw.ezan_aksam
                "isha" -> R.raw.ezan_yatsi
                else -> R.raw.hatirlatici
            }
            player = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setWakeMode(this@EzanServisi, PowerManager.PARTIAL_WAKE_LOCK)
                resources.openRawResourceFd(resource).use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                setOnCompletionListener { finishPlayback() }
                setOnErrorListener { _, what, extra -> android.util.Log.e("Ezan", "Player error: $what/$extra"); finishPlayback(); true }
                prepare(); start()
            }
            caliyor = true
            handler.postDelayed(timeout, 6 * 60 * 1000L)
            android.util.Log.i("Ezan", "Playback started: $prayer preview=$preview")
        } catch (e: Exception) {
            android.util.Log.e("Ezan", "Playback failed", e); finishPlayback()
        }
    }
    private fun releaseAudio() {
        handler.removeCallbacksAndMessages(null)
        player?.release(); player = null
        session?.release(); session = null
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else audio.abandonAudioFocus(focusListener)
        focus = null; caliyor = false
    }
    private fun finishPlayback() {
        android.util.Log.i("Ezan", "Playback stop", Throwable("stop reason"))
        releaseAudio()
        val id = activeId; activeId = -1
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else stopForeground(true)
        if (!preview && id >= 0) event?.let {
            val retained = EzanAlarmlari.notification(this, it, false)
            // FGS removal is asynchronous in system_server. Updating the same
            // ID immediately can lose the replacement. Use a separate handler
            // so onDestroy's audio cleanup cannot cancel this final update.
            Handler(Looper.getMainLooper()).postDelayed({
                try { EzanAlarmlari.notificationManager(this).notify(id, retained) }
                catch (e: Exception) { android.util.Log.w("Ezan", "Retained notification unavailable", e) }
            }, 500)
        }
        stopSelf()
    }
    override fun onDestroy() {
        releaseAudio(); activeId = -1; instance = null
        unregisterReceiver(screenReceiver)
        super.onDestroy()
    }
}
