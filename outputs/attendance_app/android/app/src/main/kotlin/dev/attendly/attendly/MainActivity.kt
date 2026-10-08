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
    private var csvResult: MethodChannel.Result? = null
    private val csvReader = java.util.concurrent.Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        ims = ImsBridge(applicationContext).also { it.attach(engine) }
        AttendancePlatform.attach(applicationContext, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.attendly/timetable").setMethodCallHandler { call, result ->
            if (call.method != "pickCsv") { result.notImplemented(); return@setMethodCallHandler }
            if (csvResult != null) { result.error("BUSY", "A file picker is already open", null); return@setMethodCallHandler }
            csvResult = result
            try {
                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/csv", "text/plain", "application/csv", "application/vnd.ms-excel", "application/octet-stream"))
                }, 8401)
            } catch (_: Exception) { csvResult = null; result.error("FILE", "Use paste to import CSV on this device", null) }
        }
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
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8401) return
        val result = csvResult ?: return
        csvResult = null
        val uri = data?.data
        if (resultCode != android.app.Activity.RESULT_OK || uri == null) { result.success(null); return }
        csvReader.execute {
            val read = runCatching {
                require(uri.scheme == "content")
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input)
                    val bytes = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        require(bytes.size() + count <= 200000)
                        bytes.write(buffer, 0, count)
                    }
                    Charsets.UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                        .decode(java.nio.ByteBuffer.wrap(bytes.toByteArray())).toString()
                }
            }
            runOnUiThread { if (!isDestroyed) read.fold(onSuccess = { result.success(it) }, onFailure = { result.error("FILE", "Choose a UTF-8 CSV under 200 KB", null) }) }
        }
    }
    override fun onDestroy() { csvResult?.success(null); csvResult = null; csvReader.shutdown(); ims?.close(); super.onDestroy() }
}
