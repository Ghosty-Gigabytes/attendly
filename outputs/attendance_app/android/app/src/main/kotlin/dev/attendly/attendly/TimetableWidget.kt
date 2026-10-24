package dev.attendly.attendly

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.util.Calendar
import java.text.SimpleDateFormat
import java.util.Locale

class TimetableWidget : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == NAVIGATE) {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.getAppWidgetIds(ComponentName(context, TimetableWidget::class.java)).contains(id)) return
            val prefs = AttendancePlatform.prefs(context)
            val step = intent.getIntExtra("step", 0)
            var offset = if (step == 0) 0 else prefs.getInt("timetable-day-$id", 0) + step
            if (step != 0) {
                while (weekday(day(offset)) > 5) offset += step
            }
            prefs.edit().putInt("timetable-day-$id", offset.coerceIn(-365, 365)).apply()
            updateAll(context)
            return
        }
        super.onReceive(context, intent)
    }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = updateAll(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = updateAll(context)
    override fun onDeleted(context: Context, ids: IntArray) {
        val edit = AttendancePlatform.prefs(context).edit()
        for (id in ids) edit.remove("timetable-day-$id")
        edit.apply()
    }
    companion object {
        const val NAVIGATE = "dev.attendly.TIMETABLE_DAY"
        fun day(offset: Int): Calendar = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, offset) }
        fun weekday(date: Calendar): Int = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
        fun date(c: Context, id: Int): Calendar = day(AttendancePlatform.prefs(c).getInt("timetable-day-$id", 0))
        fun rows(c: Context, date: Calendar): List<JSONObject> {
            val rules = AttendanceWidget.snapshot(c).optJSONArray("timetable") ?: return emptyList()
            val key = SimpleDateFormat("yyyy-MM-dd", Locale.ENGLISH).format(date.time)
            return (0 until rules.length()).mapNotNull { rules.optJSONObject(it) }.filter {
                weekday(date) <= 5 && it.optInt("weekday") == weekday(date) &&
                    key >= it.optString("from") && key <= it.optString("until")
            }.sortedBy { it.optInt("hour") * 60 + it.optInt("minute") }
        }
        fun updateAll(c: Context, dataOnly: Boolean = false) {
            val manager = AppWidgetManager.getInstance(c)
            for (id in manager.getAppWidgetIds(ComponentName(c, TimetableWidget::class.java))) {
                val date = date(c, id)
                val views = RemoteViews(c.packageName, R.layout.timetable_widget)
                views.setTextViewText(R.id.tt_date, SimpleDateFormat("EEE, d MMM yyyy", Locale.ENGLISH).format(date.time))
                views.setContentDescription(R.id.tt_date, SimpleDateFormat("EEEE, d MMMM yyyy", Locale.ENGLISH).format(date.time) + ". Tap to show today.")
                views.setTextViewText(R.id.tt_empty, if ((AttendanceWidget.snapshot(c).optJSONArray("timetable")?.length() ?: 0) == 0) "Set up your timetable in Attendly" else "No classes scheduled for this day")
                val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280).coerceAtLeast(200)
                if (!dataOnly) views.setRemoteAdapter(R.id.tt_list, Intent(c, TimetableWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    putExtra("width", width)
                    data = Uri.parse("attendly://timetable/$id/$width")
                })
                views.setEmptyView(R.id.tt_list, R.id.tt_empty)
                for ((view, step) in listOf(R.id.tt_previous to -1, R.id.tt_date to 0, R.id.tt_next to 1)) {
                    val intent = Intent(c, TimetableWidget::class.java).setAction(NAVIGATE).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id); putExtra("step", step)
                        data = Uri.parse("attendly://timetable/$id/$step")
                    }
                    views.setOnClickPendingIntent(view, PendingIntent.getBroadcast(c, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }
                views.setOnClickPendingIntent(R.id.tt_empty, AttendancePlatform.openIntent(c))
                val style = WidgetStyle(c)
                style.background(views, R.id.tt_root, "surface", "surface")
                style.text(views, R.id.tt_date, "muted")
                style.text(views, R.id.tt_empty, "muted")
                for (button in intArrayOf(R.id.tt_previous, R.id.tt_next)) {
                    style.text(views, button, "accent")
                }
                if (dataOnly) manager.partiallyUpdateAppWidget(id, views) else manager.updateAppWidget(id, views)
                manager.notifyAppWidgetViewDataChanged(id, R.id.tt_list)
            }
        }
    }
}

class TimetableWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1), intent.getIntExtra("width", 280))
    private class Factory(val c: Context, val id: Int, val width: Int) : RemoteViewsFactory {
        private var rows = emptyList<JSONObject>()
        private var use24 = true
        private var first = 8
        private var last = 18
        override fun onCreate() = onDataSetChanged()
        override fun onDataSetChanged() {
            rows = TimetableWidget.rows(c, TimetableWidget.date(c, id))
            use24 = AttendanceWidget.snapshot(c).optBoolean("use24Hour", true)
            first = minOf(8, rows.minOfOrNull { it.optInt("hour") } ?: 8).coerceAtLeast(0)
            last = maxOf(18, rows.maxOfOrNull { (it.optInt("endMinuteOfDay", it.optInt("hour") * 60 + 60) + 59) / 60 } ?: 18).coerceAtMost(24)
        }
        override fun onDestroy() { rows = emptyList() }
        override fun getCount() = if (rows.isEmpty()) 0 else last - first
        override fun getViewTypeCount() = 1
        override fun hasStableIds() = false
        override fun getItemId(position: Int) = position.toLong()
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewAt(position: Int): RemoteViews? {
            if (position !in 0 until getCount()) return null
            val hour = first + position
            val style = WidgetStyle(c)
            return RemoteViews(c.packageName, R.layout.timetable_widget_hour).apply {
                style.image(this, R.id.tt_hour) { night -> TimetableHourRenderer.render(rows, hour, width - 24, use24, style, night) }
                val entries = rows.filter { it.optInt("hour") == hour }.joinToString(". ") {
                    "${it.optString("name")}, ${it.optString("subject")}, ${TimetableHourRenderer.clock(it.optInt("hour") * 60 + it.optInt("minute"), use24)} to ${TimetableHourRenderer.clock(it.optInt("endMinuteOfDay"), use24)}, ${it.optString("kind")}, ${it.optString("group")}."
                }
                setContentDescription(R.id.tt_hour, TimetableHourRenderer.clock(hour * 60, use24) + if (entries.isEmpty()) " time slot" else ". $entries")
            }
        }
    }
}
