package dev.attendly.attendly

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.work.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object AttendancePlatform {
    @Volatile var foreground = false
    private const val workName = "attendly-refresh"
    fun prefs(c: Context) = c.getSharedPreferences("attendance_platform", Context.MODE_PRIVATE)
    fun enabled(c: Context) = prefs(c).getBoolean("background", true) && c.getSharedPreferences("ims_credentials", Context.MODE_PRIVATE).contains("encrypted")
    fun cancel(c: Context) {
        WorkManager.getInstance(c).cancelUniqueWork(workName)
        WorkManager.getInstance(c).cancelUniqueWork("attendly-manual-refresh")
        prefs(c).edit().remove("refreshState").apply()
        AttendanceWidget.updateAll(c)
    }
    fun refreshNow(c: Context) {
        if (!c.getSharedPreferences("ims_credentials", Context.MODE_PRIVATE).contains("encrypted")) {
            android.widget.Toast.makeText(c, "Open Attendly and sign in first", android.widget.Toast.LENGTH_LONG).show()
            return
        }
        val state = prefs(c).getString("refreshState", "")
        if (state == "queued" || state == "running") return
        val request = OneTimeWorkRequest.Builder(AttendanceWorker::class.java)
            .setInputData(Data.Builder().putBoolean("manual", true).build())
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES).build()
        prefs(c).edit().putString("refreshState", "queued").apply()
        WorkManager.getInstance(c).enqueueUniqueWork("attendly-manual-refresh", ExistingWorkPolicy.KEEP, request)
        AttendanceWidget.updateAll(c)
    }
    fun schedule(c: Context) {
        if (!enabled(c) || foreground) return
        val request = PeriodicWorkRequest.Builder(AttendanceWorker::class.java, 1, TimeUnit.HOURS)
            .setInitialDelay(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).setRequiresBatteryNotLow(true).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(c).enqueueUniquePeriodicWork(workName, ExistingPeriodicWorkPolicy.KEEP, request)
    }
    fun openIntent(c: Context) = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun notify(c: Context, type: String, title: String, body: String, fingerprint: String) {
        if (!prefs(c).getBoolean(type, true)) return
        val manager = c.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("attendance", "Attendance updates", NotificationManager.IMPORTANCE_DEFAULT))
        if (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        if (!manager.areNotificationsEnabled() || (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel("attendance")?.importance == NotificationManager.IMPORTANCE_NONE) || prefs(c).getString("seen-$type", null) == fingerprint) return
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "attendance") else Notification.Builder(c)
        manager.notify(type.hashCode(), builder.setSmallIcon(R.drawable.notification_icon).setContentTitle(title).setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body)).setContentIntent(openIntent(c)).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build())
        prefs(c).edit().putString("seen-$type", fingerprint).apply()
    }
    fun attach(c: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.attendly/platform").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "settings" -> {
                        val values = call.arguments as? Map<*, *>
                        if (values != null) {
                            val edit = prefs(c).edit()
                            for (key in listOf("background", "low", "updates", "discrepancies")) if (values[key] is Boolean) edit.putBoolean(key, values[key] as Boolean)
                            edit.apply()
                            for (key in listOf("low", "updates", "discrepancies")) if (values[key] == false) c.getSystemService(NotificationManager::class.java).cancel(key.hashCode())
                            if (!enabled(c)) cancel(c) else schedule(c)
                        }
                        val manager = c.getSystemService(NotificationManager::class.java)
                        result.success(mapOf("background" to prefs(c).getBoolean("background", true), "low" to prefs(c).getBoolean("low", true), "updates" to prefs(c).getBoolean("updates", true), "discrepancies" to prefs(c).getBoolean("discrepancies", true), "permission" to manager.areNotificationsEnabled(), "lastAttempt" to prefs(c).getString("lastAttempt", "Not run yet")))
                    }
                    "publish" -> {
                        if (call.hasArgument("widget")) {
                            prefs(c).edit().putString("widget", call.argument<String>("widget")).apply()
                            AttendanceWidget.updateAll(c)
                        }
                        val alerts = call.argument<List<Map<String, String>>>("alerts") ?: emptyList()
                        for (a in alerts) notify(c, a.getValue("type"), a.getValue("title"), a.getValue("body"), a.getValue("fingerprint"))
                        for (type in call.argument<List<String>>("clear") ?: emptyList()) {
                            c.getSystemService(NotificationManager::class.java).cancel(type.hashCode())
                            prefs(c).edit().remove("seen-$type").apply()
                        }
                        schedule(c)
                        result.success(null)
                    }
                    "status" -> { prefs(c).edit().putString("lastAttempt", call.argument<String>("message")).apply(); result.success(null) }
                    "clear" -> {
                        cancel(c)
                        val edit = prefs(c).edit().remove("widget").remove("lastAttempt")
                        for (type in listOf("low", "updates", "discrepancies", "auth")) { edit.remove("seen-$type"); c.getSystemService(NotificationManager::class.java).cancel(type.hashCode()) }
                        edit.apply(); AttendanceWidget.updateAll(c); result.success(null)
                    }
                    "pinWidget" -> {
                        val manager = AppWidgetManager.getInstance(c)
                        result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported && manager.requestPinAppWidget(ComponentName(c, AttendanceWidget::class.java), null, null))
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("PLATFORM", "Android attendance service unavailable", null) }
        }
    }
}
