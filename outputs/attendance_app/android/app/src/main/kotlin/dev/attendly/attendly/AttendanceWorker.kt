package dev.attendly.attendly

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class AttendanceWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object { private val running = AtomicBoolean(false) }
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var ims: ImsBridge? = null
    private val completed = CountDownLatch(1)
    @Volatile private var success = false
    override fun doWork(): Result {
        val generation = AttendancePlatform.generation.get()
        val manual = inputData.getBoolean("manual", false)
        if (AttendancePlatform.foreground || (!manual && !AttendancePlatform.enabled(applicationContext))) return Result.success()
        if (!running.compareAndSet(false, true)) return Result.retry()
        try {
        AttendancePlatform.prefs(applicationContext).edit().putString("refreshState", "running").apply()
        AttendanceWidget.updateRefreshState(applicationContext)
        main.post {
            if (isStopped || AttendancePlatform.foreground || generation != AttendancePlatform.generation.get()) { completed.countDown(); return@post }
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val current = FlutterEngine(applicationContext)
                engine = current
                ims = ImsBridge(applicationContext).also { it.attach(current) }
                AttendancePlatform.attach(applicationContext, current)
                MethodChannel(current.dartExecutor.binaryMessenger, "dev.attendly/background").setMethodCallHandler { call, result ->
                    if (call.method == "complete") {
                        success = call.argument<Boolean>("success") == true
                        result.success(null)
                        completed.countDown()
                    } else result.notImplemented()
                }
                current.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "attendanceBackground"))
            } catch (_: Exception) { completed.countDown() }
        }
        completed.await(3, TimeUnit.MINUTES)
        main.post { cleanup() }
        return if (success) Result.success() else if (runAttemptCount < 2) Result.retry() else Result.failure()
        } finally {
            running.set(false)
            if (generation == AttendancePlatform.generation.get()) AttendancePlatform.prefs(applicationContext).edit().putString("refreshState", if (!success && !isStopped && runAttemptCount < 2) "queued" else "").apply()
            AttendanceWidget.updateRefreshState(applicationContext)
        }
    }
    private fun cleanup() { ims?.close(); ims = null; engine?.destroy(); engine = null }
    override fun onStopped() { completed.countDown(); main.post { cleanup() }; super.onStopped() }
}
