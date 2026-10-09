package com.example.namaz_vakitleri

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        PlanYenileme.foreground()
        PlanYenileme.attach(this, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "namaz_vakitleri/widget")
            .setMethodCallHandler { call, result ->
                if (call.method != "publish") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    PlanYenileme.foreground()
                    val raw = call.arguments as String
                    WidgetMotoru.publish(this, raw)
                    PlanYenileme.configure(this, raw)
                    result.success(null)
                }
                catch (e: Exception) { result.error("widget_publish", e.message, null) }
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "namaz_vakitleri/ezan")
            .setMethodCallHandler { call, result ->
                try {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    if (call.method in listOf("schedule", "cancel", "configure")) PlanYenileme.foreground()
                    result.success(EzanAlarmlari.handle(this, call.method, args))
                } catch (e: Exception) { result.error("ezan_platform", e.message, null) }
            }
    }
    override fun onStart() {
        PlanYenileme.visible = true
        PlanYenileme.foreground()
        super.onStart()
    }
    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        PlanYenileme.releaseUi(this)
        super.cleanUpFlutterEngine(engine)
    }
    override fun onStop() {
        super.onStop()
        PlanYenileme.visible = false
        PlanYenileme.request(this, false)
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.action == KeyEvent.ACTION_DOWN && EzanServisi.caliyor) {
            EzanServisi.stop(this)
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
