package dev.attendly.attendly
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.util.Locale

class AttendanceWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext, intent.getIntExtra("height", 250))
    private class Factory(val c: Context, val height: Int) : RemoteViewsFactory {
        private var subjects = JSONArray()
        override fun onCreate() { onDataSetChanged() }
        override fun onDataSetChanged() { subjects = AttendanceWidget.snapshot(c).optJSONArray("subjects") ?: JSONArray() }
        override fun onDestroy() { subjects = JSONArray() }
        override fun getCount() = subjects.length()
        override fun getViewTypeCount() = 1
        override fun hasStableIds() = false
        override fun getItemId(position: Int) = position.toLong()
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewAt(position: Int): RemoteViews? {
            val s = subjects.optJSONObject(position) ?: return null
            val held = s.optInt("held")
            val attended = s.optInt("attended")
            val percent = if (held > 0) attended * 100.0 / held else null
            val cellHeight = ((height - 72) / subjects.length().coerceAtLeast(1) - 7).coerceIn(116, 144)
            return RemoteViews(c.packageName, R.layout.attendance_widget_row).apply {
                setInt(R.id.row_root, "setMinimumHeight", (cellHeight * c.resources.displayMetrics.density).toInt())
                setTextViewText(R.id.row_name, s.optString("name").ifBlank { s.optString("code") })
                setTextViewText(R.id.row_code, s.optString("code"))
                setTextViewText(R.id.row_percent, if (percent == null) "—" else String.format(Locale.getDefault(), "%.1f%%", percent))
                val style = WidgetStyle(c)
                val tone = when { percent == null -> "muted"; percent < 75 -> "error"; percent < 80 -> "caution"; else -> "positive" }
                style.background(this, R.id.row_root, "card", "card")
                style.text(this, R.id.row_name, "text")
                for (view in intArrayOf(R.id.row_code, R.id.row_counts, R.id.row_advice)) style.text(this, view, "muted")
                style.text(this, R.id.row_percent, tone)
                style.progress(this, percent, tone)
                setTextViewText(R.id.row_counts, "$attended/$held classes")
                setTextViewText(R.id.row_advice, s.optString("dayAdvice", "Refresh for day estimate"))
                setContentDescription(R.id.row_root, "${s.optString("name")}, ${s.optString("code")}, $attended of $held classes. ${s.optString("dayAdvice")}")
                setOnClickFillInIntent(R.id.row_root, Intent())
            }
        }
    }
}
