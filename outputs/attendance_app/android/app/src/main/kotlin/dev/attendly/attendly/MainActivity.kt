package dev.attendly.attendly

import android.Manifest
import android.os.Build
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ims: ImsBridge? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        ims = ImsBridge(applicationContext).also { it.attach(engine) }
        AttendancePlatform.attach(applicationContext, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.attendly/theme").setMethodCallHandler { call, result ->
            if (call.method == "systemAccent") {
                result.success(if (Build.VERSION.SDK_INT >= 31) getColor(android.R.color.system_accent1_500).toLong() and 0xFFFFFFFFL else null)
            } else result.notImplemented()
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.attendly/permission").setMethodCallHandler { call, result ->
            if (call.method == "request" || call.method == "requestOnce") {
                val prefs = AttendancePlatform.prefs(applicationContext)
                if (call.method == "requestOnce" && prefs.getBoolean("askedPermission", false)) { result.success(null); return@setMethodCallHandler }
                if (call.method == "request" && Build.VERSION.SDK_INT >= 33 && prefs.getBoolean("askedPermission", false) && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED && !shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null); return@setMethodCallHandler
                }
                prefs.edit().putBoolean("askedPermission", true).apply()
                if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 75)
                result.success(null)
            } else result.notImplemented()
        }
    }
    override fun onStart() {
        super.onStart()
        AttendancePlatform.foreground = true
        AttendancePlatform.cancel(applicationContext)
    }
    override fun onStop() {
        AttendancePlatform.foreground = false
        AttendancePlatform.schedule(applicationContext)
        super.onStop()
    }
    override fun onDestroy() { ims?.close(); super.onDestroy() }
}
