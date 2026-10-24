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
        fun updateRefreshState(c: Context) {
            val manager = AppWidgetManager.getInstance(c)
            val state = AttendancePlatform.prefs(c).getString("refreshState", "") ?: ""
            val views = RemoteViews(c.packageName, R.layout.attendance_widget)
            WidgetStyle(c).refreshIcon(views, state == "running" || state == "queued")
            views.setContentDescription(R.id.widget_refresh, if (state == "running" || state == "queued") "Refreshing attendance" else "Refresh attendance")
            for (id in manager.getAppWidgetIds(ComponentName(c, AttendanceWidget::class.java))) {
                manager.partiallyUpdateAppWidget(id, views)
            }
        }
        fun updateAll(c: Context, dataOnly: Boolean = false) {
            val manager = AppWidgetManager.getInstance(c)
            val json = snapshot(c)
            for (id in manager.getAppWidgetIds(ComponentName(c, AttendanceWidget::class.java))) {
                val options = manager.getAppWidgetOptions(id)
                val portrait = render(c, json, id, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250), !dataOnly)
                val landscape = render(c, json, id, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250), !dataOnly)
                if (dataOnly) manager.partiallyUpdateAppWidget(id, RemoteViews(landscape, portrait))
                else manager.updateAppWidget(id, RemoteViews(landscape, portrait))
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_grid)
            }
        }
        private fun render(c: Context, json: JSONObject, id: Int, height: Int, bindAdapter: Boolean): RemoteViews {
            val views = RemoteViews(c.packageName, R.layout.attendance_widget)
            val adapter = Intent(c, AttendanceWidgetService::class.java).apply {
                putExtra("height", height)
                data = Uri.parse("attendly://widget/list/$id/$height")
            }
            if (bindAdapter) views.setRemoteAdapter(R.id.widget_grid, adapter)
            views.setEmptyView(R.id.widget_grid, R.id.widget_empty)
            val open = Intent(c, MainActivity::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            views.setPendingIntentTemplate(R.id.widget_grid, PendingIntent.getActivity(c, id, open, flags))
            val refresh = Intent(c, AttendanceWidget::class.java).setAction("dev.attendly.REFRESH_ATTENDANCE")
            views.setOnClickPendingIntent(R.id.widget_refresh, PendingIntent.getBroadcast(c, 75, refresh, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            val state = AttendancePlatform.prefs(c).getString("refreshState", "") ?: ""
            views.setContentDescription(R.id.widget_refresh, when (state) { "running" -> "Refreshing attendance"; "queued" -> "Attendance refresh queued"; else -> "Refresh attendance" })
            views.setOnClickPendingIntent(R.id.widget_empty, AttendancePlatform.openIntent(c))
            views.setTextViewText(R.id.widget_updated, json.optString("updated", "Not refreshed yet").substringBefore(" · Tap"))
            val style = WidgetStyle(c, json)
            style.background(views, R.id.widget_root, "surface", "surface")
            style.refreshIcon(views, state == "running" || state == "queued")
            style.text(views, R.id.widget_empty, "text")
            style.text(views, R.id.widget_updated, "muted")
            return views
        }
    }
}
