package dev.attendly.attendly
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONObject

class AttendanceWidget : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "dev.attendly.REFRESH_ATTENDANCE") {
            AttendancePlatform.refreshNow(context)
            return
        }
        super.onReceive(context, intent)
    }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { updateAll(context) }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) { updateAll(context) }
    companion object {
        fun snapshot(c: Context): JSONObject = runCatching { JSONObject(AttendancePlatform.prefs(c).getString("widget", "{}") ?: "{}") }.getOrDefault(JSONObject())
        fun updateAll(c: Context) {
            val manager = AppWidgetManager.getInstance(c)
            val json = snapshot(c)
            for (id in manager.getAppWidgetIds(ComponentName(c, AttendanceWidget::class.java))) {
                val options = manager.getAppWidgetOptions(id)
                val portrait = render(c, json, id, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250))
                val landscape = render(c, json, id, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250))
                manager.updateAppWidget(id, RemoteViews(landscape, portrait))
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_grid)
            }
        }
        private fun render(c: Context, json: JSONObject, id: Int, height: Int): RemoteViews {
            val views = RemoteViews(c.packageName, R.layout.attendance_widget)
            val adapter = Intent(c, AttendanceWidgetService::class.java).apply {
                putExtra("height", height)
                data = Uri.parse("attendly://widget/list/$id/$height")
            }
            views.setRemoteAdapter(R.id.widget_grid, adapter)
            views.setEmptyView(R.id.widget_grid, R.id.widget_empty)
            val open = Intent(c, MainActivity::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            views.setPendingIntentTemplate(R.id.widget_grid, PendingIntent.getActivity(c, id, open, flags))
            val refresh = Intent(c, AttendanceWidget::class.java).setAction("dev.attendly.REFRESH_ATTENDANCE")
            views.setOnClickPendingIntent(R.id.widget_refresh, PendingIntent.getBroadcast(c, 75, refresh, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            val state = AttendancePlatform.prefs(c).getString("refreshState", "") ?: ""
            views.setTextViewText(R.id.widget_refresh, when (state) { "running" -> "Refreshing…"; "queued" -> "Queued…"; else -> "Refresh" })
            views.setOnClickPendingIntent(R.id.widget_empty, AttendancePlatform.openIntent(c))
            views.setTextViewText(R.id.widget_updated, "Official · " + json.optString("updated", "Not refreshed yet").substringBefore(" · Tap"))
            return views
        }
    }
}
