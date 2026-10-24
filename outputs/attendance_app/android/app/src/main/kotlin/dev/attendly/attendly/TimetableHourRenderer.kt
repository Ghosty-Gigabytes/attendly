package dev.attendly.attendly

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import org.json.JSONObject
import java.util.Locale

/** One bounded bitmap per hour keeps long timetables scrollable without a huge RemoteViews payload. */
object TimetableHourRenderer {
    fun clock(minutes: Int, use24: Boolean): String {
        val hour = (minutes / 60) % 24
        return if (use24) String.format(Locale.ENGLISH, "%02d:%02d", minutes / 60, minutes % 60)
        else String.format(Locale.ENGLISH, "%d:%02d %s", if (hour % 12 == 0) 12 else hour % 12, minutes % 60, if (hour < 12) "AM" else "PM")
    }
    fun render(rows: List<JSONObject>, hour: Int, availableWidth: Int, use24: Boolean, style: WidgetStyle, night: Boolean): Bitmap {
        val width = availableWidth.coerceIn(176, 800).toFloat()
        val bitmap = Bitmap.createBitmap((width * 2).toInt().coerceAtMost(520), 192, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(bitmap.width / width, 2f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val gutter = if (use24) 48f else 62f
        paint.color = style.color("track", night)
        paint.strokeWidth = .6f
        canvas.drawLine(gutter, 0f, width, 0f, paint)
        canvas.drawLine(gutter, 0f, gutter, 96f, paint)
        paint.color = style.color("muted", night)
        paint.textSize = 10f
        canvas.drawText(clock(hour * 60, use24), 0f, 14f, paint)
        val laneEnds = mutableListOf<Int>()
        val lanes = rows.map { row ->
            val start = row.optInt("hour") * 60 + row.optInt("minute")
            var lane = laneEnds.indexOfFirst { it <= start }
            if (lane == -1) { lane = laneEnds.size; laneEnds.add(0) }
            laneEnds[lane] = row.optInt("endMinuteOfDay", start + 60)
            lane
        }
        val laneWidth = (width - gutter) / laneEnds.size.coerceAtLeast(1)
        for ((index, row) in rows.withIndex()) {
            val start = row.optInt("hour") * 60 + row.optInt("minute")
            val end = row.optInt("endMinuteOfDay", start + 60)
            if (end <= hour * 60 || start >= (hour + 1) * 60) continue
            val top = (start - hour * 60) * 1.6f + 2f
            val bottom = (end - hour * 60) * 1.6f - 2f
            val left = gutter + lanes[index] * laneWidth + 4f
            val right = left + laneWidth - 8f
            if (right <= left) continue
            paint.color = style.color("container", night)
            canvas.drawRoundRect(RectF(left, top, right, bottom), 12f, 12f, paint)
            canvas.save()
            canvas.clipRect(left + 7, top + 6, right - 7, bottom - 5)
            val textWidth = (right - left - 14).toInt().coerceAtLeast(1)
            fun text(value: String, y: Float, size: Float, bold: Boolean, lines: Int): Float {
                val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = style.color("onContainer", night); textSize = size; isFakeBoldText = bold }
                val layout = StaticLayout.Builder.obtain(value, 0, value.length, tp, textWidth)
                    .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false)
                    .setMaxLines(lines).setEllipsize(TextUtils.TruncateAt.END).build()
                canvas.save(); canvas.translate(left + 7, y); layout.draw(canvas); canvas.restore()
                return layout.height.toFloat()
            }
            var y = top + 8
            y += text(row.optString("name", row.optString("subject")), y, 12f, true, if (bottom - top < 65) 1 else 2) + 4
            if (bottom - top >= 70) {
                y += text("${row.optString("subject")} · ${row.optString("kind", "lecture")}${if (row.optString("group", "all") == "all") "" else " · " + row.optString("group")}", y, 10f, false, 1) + 3
            }
            text("${clock(start, use24)}–${clock(end, use24)}", y, 10f, false, 1)
            canvas.restore()
        }
        return bitmap
    }
}
