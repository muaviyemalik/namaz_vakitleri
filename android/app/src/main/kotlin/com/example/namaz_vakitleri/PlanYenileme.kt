package com.example.namaz_vakitleri

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** One persistent renewal job, independent of the Activity. No exact wakeup
 * just for maintenance. All engine mutations are serialized on Android main. */
object PlanYenileme {
    const val PERIODIC = "prayer-plan-renewal-v1"
    const val NOW = "prayer-plan-renewal-now-v1"
    val handler = Handler(Looper.getMainLooper())
    private val leases = mutableSetOf<Int>()
    private var nextLease = 0
    var visible = false
    var active: PlanYenilemeWorker? = null
    fun prefs(c: Context) = c.getSharedPreferences("plan_renewal_v1", Context.MODE_PRIVATE)
    fun configured(c: Context): Boolean = prefs(c).contains("context")
    fun foreground() { active?.finish(false, "foreground_preempted") }
    fun begin(c: Context): Int {
        foreground()
        // The UI may install its short immediate plan. Refill the full window
        // after that write even if the previous background run was recent.
        prefs(c).edit().putLong("lastSuccess", 0).commit()
        return (++nextLease).also { leases.add(it) }
    }
    fun end(c: Context, id: Int) { leases.remove(id); request(c, false) }
    fun busy() = visible || leases.isNotEmpty() || active != null
    fun releaseUi(c: Context) { leases.clear(); request(c, false) }

    fun configure(c: Context, raw: String) {
        val packet = JSONObject(raw)
        val renewal = packet.optJSONObject("renewal") ?: return
        val location = renewal.optJSONObject("location")
        val p = prefs(c)
        if (location == null) {
            foreground()
            p.edit().remove("context").remove("key").commit()
            WorkManager.getInstance(c).cancelUniqueWork(PERIODIC)
            WorkManager.getInstance(c).cancelUniqueWork(NOW)
            return
        }
        // Context contains selected city/method/settings and presentation only;
        // daily snapshot changes do not reset the renewal schedule.
        val context = JSONObject().put("renewal", renewal)
            .put("language", packet.getString("language"))
            .put("colors", packet.getJSONObject("colors"))
            .put("labels", packet.getJSONObject("labels"))
        val key = context.toString()
        if (p.getString("key", null) != key) {
            foreground()
            check(p.edit().putString("context", key).putString("key", key)
                .putLong("lastSuccess", 0).commit())
        }
        val periodic = PeriodicWorkRequest.Builder(PlanYenilemeWorker::class.java, 6, TimeUnit.HOURS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(c).enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, periodic)
        request(c, false)
    }

    fun request(c: Context, force: Boolean) {
        if (!configured(c)) return
        if (!force && System.currentTimeMillis() - prefs(c).getLong("lastSuccess", 0) < 6 * 3600000L) return
        val work = OneTimeWorkRequest.Builder(PlanYenilemeWorker::class.java)
            .setInputData(Data.Builder().putBoolean("force", force).build())
            .setInitialDelay(15, TimeUnit.SECONDS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(c).enqueueUniqueWork(NOW, ExistingWorkPolicy.KEEP, work)
    }

    fun attach(c: Context, engine: FlutterEngine, worker: PlanYenilemeWorker? = null) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "namaz_vakitleri/renewal")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "context" -> { check(active === worker && worker != null); result.success(prefs(c).getString("context", null)) }
                        "complete" -> {
                            check(active === worker && worker != null)
                            val report = JSONObject(call.arguments as Map<*, *>)
                            result.success(null)
                            handler.post { worker.finish(report.optBoolean("ok"), report.toString()) }
                        }
                        "foregroundBegin" -> { check(worker == null); result.success(begin(c)) }
                        "foregroundEnd" -> { check(worker == null); end(c, (call.arguments as Number).toInt()); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("renewal", e.message, null) }
            }
        if (worker != null) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "namaz_vakitleri/ezan")
                .setMethodCallHandler { call, result ->
                    try {
                        check(active === worker && !visible && leases.isEmpty())
                        result.success(EzanAlarmlari.handle(c, call.method, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()))
                    } catch (e: Exception) { result.error("renewal_stale", e.message, null) }
                }
            MethodChannel(engine.dartExecutor.binaryMessenger, "namaz_vakitleri/widget")
                .setMethodCallHandler { call, result ->
                    try {
                        check(active === worker && !visible && leases.isEmpty())
                        check(call.method == "publish")
                        WidgetMotoru.publish(c, call.arguments as String)
                        result.success(null)
                    } catch (e: Exception) { result.error("renewal_stale", e.message, null) }
                }
        }
    }
}

/** WorkManager owns process/wakelock/reboot persistence. The engine is created
 * on main, destroyed on completion/preemption/timeout/stop. No Activity launch. */
class PlanYenilemeWorker(c: Context, params: WorkerParameters) : Worker(c, params) {
    private val done = CountDownLatch(1)
    @Volatile private var successful = false
    private var engine: FlutterEngine? = null
    private var finished = false
    override fun doWork(): Result {
        PlanYenileme.handler.post {
            if (isStopped || !PlanYenileme.configured(applicationContext)) {
                successful = true; done.countDown(); return@post
            }
            if (!inputData.getBoolean("force", false) &&
                System.currentTimeMillis() - PlanYenileme.prefs(applicationContext)
                    .getLong("lastSuccess", 0) < 6 * 3600000L) {
                successful = true; done.countDown(); return@post
            }
            if (PlanYenileme.busy()) { done.countDown(); return@post }
            PlanYenileme.active = this
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val e = FlutterEngine(applicationContext)
                engine = e
                PlanYenileme.attach(applicationContext, e, this)
                e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "arkaPlanYenile"))
            } catch (e: Exception) { finish(false, e.toString()) }
        }
        if (!done.await(120, TimeUnit.SECONDS)) {
            PlanYenileme.handler.post { finish(false, "timeout") }
            return Result.retry()
        }
        return if (successful) Result.success() else Result.retry()
    }
    fun finish(ok: Boolean, report: String) {
        if (finished) return
        finished = true
        successful = ok
        PlanYenileme.prefs(applicationContext).edit().putString("report", report)
            .putLong("lastAttempt", System.currentTimeMillis()).apply()
        if (ok) PlanYenileme.prefs(applicationContext).edit()
            .putLong("lastSuccess", System.currentTimeMillis()).apply()
        android.util.Log.i("PlanYenileme", report)
        if (PlanYenileme.active === this) PlanYenileme.active = null
        engine?.destroy(); engine = null
        done.countDown()
    }
    override fun onStopped() { PlanYenileme.handler.post { finish(false, "stopped") } }
}
