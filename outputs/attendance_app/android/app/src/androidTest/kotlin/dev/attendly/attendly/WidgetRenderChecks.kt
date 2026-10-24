package dev.attendly.attendly

import android.app.Instrumentation
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.LinearLayout
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

/** Native rendering checks; never reads or changes the user's records. */
class WidgetRenderChecks : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val result = Bundle()
        try {
            runOnMainSync {
                for (mode in listOf("light", "dark", "system")) {
                    val style = WidgetStyle(targetContext, JSONObject().put("themeMode", mode))
                    val parent = LinearLayout(targetContext).apply { orientation = LinearLayout.VERTICAL }
                    val row = RemoteViews(targetContext.packageName, R.layout.attendance_widget_row)
                    style.background(row, R.id.row_root, "card", "card")
                    style.text(row, R.id.row_name, "text")
                    style.text(row, R.id.row_percent, "positive")
                    for (id in intArrayOf(R.id.row_code, R.id.row_counts, R.id.row_advice)) style.text(row,id,"muted")
                    row.setTextViewText(R.id.row_name,"Example subject")
                    row.setTextViewText(R.id.row_code,"TEST101")
                    row.setTextViewText(R.id.row_percent,"82.5%")
                    row.setTextViewText(R.id.row_counts,"33/40 classes")
                    row.setTextViewText(R.id.row_advice,"3 classes available")
                    style.progress(row,82.5,"positive")
                    parent.addView(row.apply(targetContext,parent))
                    val footer = RemoteViews(targetContext.packageName,R.layout.attendance_widget)
                    style.background(footer,R.id.widget_root,"surface","surface")
                    style.refreshIcon(footer,false)
                    style.text(footer,R.id.widget_updated,"muted")
                    footer.setTextViewText(R.id.widget_updated,"Fetched Friday, 9 Oct 2026 2:35 PM")
                    footer.setViewVisibility(R.id.widget_grid,View.GONE)
                    footer.setViewVisibility(R.id.widget_empty,View.GONE)
                    parent.addView(footer.apply(targetContext,parent),LinearLayout.LayoutParams(-1,140))
                    // Applying RemoteViews verifies all invoked setters on the actual Android runtime.
                    save(parent,"attendance-$mode",720,440)
                    val grid = LinearLayout(targetContext).apply { orientation = LinearLayout.VERTICAL }
                    val entries = listOf(
                        JSONObject("{\"subject\":\"TEST101\",\"name\":\"Example lecture\",\"hour\":9,\"minute\":30,\"endMinuteOfDay\":630,\"kind\":\"lecture\",\"group\":\"all\"}"),
                        JSONObject("{\"subject\":\"TEST102\",\"name\":\"Example lab\",\"hour\":11,\"minute\":0,\"endMinuteOfDay\":780,\"kind\":\"lab\",\"group\":\"G2\"}")
                    )
                    for (hour in 9..12) {
                        val tile=RemoteViews(targetContext.packageName,R.layout.timetable_widget_hour)
                        style.image(tile,R.id.tt_hour) { night -> TimetableHourRenderer.render(entries,hour,320,false,style,night) }
                        grid.addView(tile.apply(targetContext,grid),LinearLayout.LayoutParams(-1,216))
                    }
                    save(grid,"timetable-$mode",720,864)
                }
            }
            result.putString("result","PASS: light, dark and system RemoteViews; waves, refresh icon and partial-hour day-grid rendering")
            finish(-1,result)
        } catch (error: Throwable) {
            result.putString("error",error.stackTraceToString());finish(0,result)
        }
    }
    private fun save(view: View, name: String, width: Int, height: Int) {
        view.measure(View.MeasureSpec.makeMeasureSpec(width,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(height,View.MeasureSpec.EXACTLY))
        view.layout(0,0,width,height)
        val bitmap=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        File(targetContext.cacheDir,"$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
        bitmap.recycle()
    }
}
