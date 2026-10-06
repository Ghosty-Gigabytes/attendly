package dev.attendly.attendly
import android.content.Context
import android.content.Intent
import android.view.View
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
            val cellHeight = ((height - 46) / subjects.length().coerceAtLeast(1) - 7).coerceIn(96, 124)
            return RemoteViews(c.packageName, R.layout.attendance_widget_row).apply {
                setInt(R.id.row_root, "setMinimumHeight", (cellHeight * c.resources.displayMetrics.density).toInt())
                setTextViewText(R.id.row_name, s.optString("name").ifBlank { s.optString("code") })
                setTextViewText(R.id.row_code, s.optString("code"))
                setTextViewText(R.id.row_percent, if (percent == null) "—" else String.format(Locale.getDefault(), "%.1f%%", percent))
                val color = when { percent == null -> R.color.widget_muted; percent < 75 -> R.color.widget_error; percent < 80 -> R.color.widget_caution; else -> R.color.widget_positive }
                setTextColor(R.id.row_percent, c.getColor(color))
                val selectedBar = when { percent != null && percent < 75 -> R.id.row_progress_low; percent != null && percent < 80 -> R.id.row_progress_caution; else -> R.id.row_progress_good }
                for (bar in intArrayOf(R.id.row_progress_low, R.id.row_progress_caution, R.id.row_progress_good)) {
                    setViewVisibility(bar, if (bar == selectedBar) View.VISIBLE else View.GONE)
                    setProgressBar(bar, 1000, ((percent ?: 0.0) * 10).toInt().coerceIn(0,1000), false)
                }
                setTextViewText(R.id.row_counts, "$attended/$held classes")
                setTextViewText(R.id.row_advice, s.optString("dayAdvice", "Refresh for day estimate"))
                setContentDescription(R.id.row_root, "${s.optString("name")}, ${s.optString("code")}, $attended of $held classes. ${s.optString("dayAdvice")}")
                setOnClickFillInIntent(R.id.row_root, Intent())
            }
        }
    }
}
