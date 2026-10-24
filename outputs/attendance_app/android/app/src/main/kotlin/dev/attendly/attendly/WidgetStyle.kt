package dev.attendly.attendly

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Path
import android.graphics.Paint
import android.graphics.drawable.Icon
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

/** Keep both palettes in RemoteViews so Android 12+ can reapply system night mode. */
class WidgetStyle(private val c: Context, private val json: JSONObject = AttendanceWidget.snapshot(c)) {
    private val mode = json.optString("themeMode", "system")
    private val dark = mode == "dark" || (mode == "system" && c.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES)
    fun color(key: String, night: Boolean): Int {
        val defaults = if (night) mapOf("surface" to 0xFF191B20, "card" to 0xFF101318, "text" to 0xFFE2E2E9, "muted" to 0xFFC4C6D0, "accent" to 0xFFABC7FF, "container" to 0xFF254777, "onContainer" to 0xFFD6E3FF, "track" to 0xFF34363D, "error" to 0xFFFFB4AB, "caution" to 0xFFFFCF79, "positive" to 0xFF8CD6AB)
        else mapOf("surface" to 0xFFF1F3FA, "card" to 0xFFFFFFFF, "text" to 0xFF191C20, "muted" to 0xFF44474F, "accent" to 0xFF365F98, "container" to 0xFFD6E3FF, "onContainer" to 0xFF0F427C, "track" to 0xFFE1E2E9, "error" to 0xFFBA1A1A, "caution" to 0xFF795900, "positive" to 0xFF246B46)
        return json.optJSONObject(if (night) "darkColors" else "lightColors")?.optLong(key, defaults.getValue(key))?.toInt() ?: defaults.getValue(key).toInt()
    }
    fun text(v: RemoteViews, id: Int, key: String) {
        if (Build.VERSION.SDK_INT >= 31 && mode == "system") v.setColorInt(id, "setTextColor", color(key, false), color(key, true))
        else v.setTextColor(id, color(key, dark))
    }
    fun background(v: RemoteViews, id: Int, key: String, shape: String) {
        if (Build.VERSION.SDK_INT >= 31) {
            v.setColorStateList(id, "setBackgroundTintList", ColorStateList.valueOf(color(key, if (mode == "system") false else dark)), ColorStateList.valueOf(color(key, if (mode == "system") true else dark)))
        } else {
            val resource = when (shape) {
                "card" -> if (dark) R.drawable.widget_card_dark else R.drawable.widget_card_light
                "button" -> if (dark) R.drawable.widget_button_dark else R.drawable.widget_button_light
                else -> if (dark) R.drawable.widget_surface_dark else R.drawable.widget_surface_light
            }
            v.setInt(id, "setBackgroundResource", resource)
        }
    }
    fun image(v: RemoteViews, id: Int, render: (Boolean) -> Bitmap) {
        if (Build.VERSION.SDK_INT >= 31 && mode == "system") v.setIcon(id, "setImageIcon", Icon.createWithBitmap(render(false)), Icon.createWithBitmap(render(true)))
        else v.setImageViewBitmap(id, render(dark))
    }
    fun refreshIcon(v: RemoteViews, running: Boolean) {
        image(v, R.id.widget_refresh) { night ->
            Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888).also { bitmap ->
                val canvas = Canvas(bitmap)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = color("accent", night); style = Paint.Style.STROKE; strokeWidth = 5f; strokeCap = Paint.Cap.ROUND }
                canvas.drawArc(14f, 14f, 50f, 50f, if (running) 30f else 45f, 285f, false, paint)
                paint.style = Paint.Style.FILL
                val arrow = Path().apply { moveTo(50f, 10f); lineTo(50f, 27f); lineTo(34f, 22f); close() }
                canvas.drawPath(arrow, paint)
            }
        }
    }
    fun progress(v: RemoteViews, percent: Double?, key: String) {
        image(v, R.id.row_progress) { night ->
            val bitmap = Bitmap.createBitmap(600, 32, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 6f; strokeCap = Paint.Cap.ROUND }
            val end = 3f + ((percent ?: 0.0).coerceIn(0.0, 100.0) / 100 * 594).toFloat()
            paint.color = color("track", night)
            if (end < 597f) canvas.drawLine(if (end > 3f) (end + 10f).coerceAtMost(597f) else 3f, 16f, 597f, 16f, paint)
            if (percent != null && percent > 0) {
                paint.color = color(key, night)
                val path = Path()
                var x = 3f
                while (x < end) {
                    val y = 16f + 8f * kotlin.math.sin((x - 3f) * Math.PI * 2 / 48).toFloat()
                    if (x == 3f) path.moveTo(x, y) else path.lineTo(x, y)
                    x += 1f
                }
                path.lineTo(end, 16f + 8f * kotlin.math.sin((end - 3f) * Math.PI * 2 / 48).toFloat())
                canvas.drawPath(path, paint)
            }
            bitmap
        }
    }
}
