package com.lewiseman.redkeep.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.RowScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import com.lewiseman.redkeep.R

/** Three doors into the app: today's diary page, a new note, the watchlist. */
class QuickCaptureWidget : GlanceAppWidget() {
    companion object {
        private val BAR = DpSize(110.dp, 40.dp)
        private val WIDE_BAR = DpSize(220.dp, 40.dp)
        private val WIDE = DpSize(220.dp, 100.dp)
    }

    override val sizeMode = SizeMode.Exact
    override val previewSizeMode = SizeMode.Responsive(setOf(BAR, WIDE_BAR, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { QuickCapture(WidgetStore.load(context)) }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { QuickCapture(null) }
    }
}

class QuickCaptureWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuickCaptureWidget()
}

private class Shortcut(val icon: Int, val label: String, val path: String, val primary: Boolean = false)

private val shortcuts = listOf(
    Shortcut(R.drawable.ic_widget_quill, "Diary", WidgetLinks.WRITE, primary = true),
    Shortcut(R.drawable.ic_widget_note, "Note", WidgetLinks.NEW_NOTE),
    Shortcut(R.drawable.ic_widget_film, "Watchlist", WidgetLinks.WATCHLIST),
)

@Composable
private fun QuickCapture(snapshot: WidgetSnapshot?) {
    val colors = WidgetColors(snapshot)
    val size = LocalSize.current
    // Too narrow for words beside three icons: show the icons alone.
    val labels = size.width >= 200.dp
    val stacked = size.height >= 90.dp
    Box(
        GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(24.dp)
            .background(ImageProvider(colors.paper))
            .padding(if (stacked) 10.dp else 6.dp),
    ) {
        Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            shortcuts.forEachIndexed { index, item ->
                if (index > 0) Spacer(GlanceModifier.width(6.dp))
                Tile(item, colors, labels, stacked)
            }
        }
    }
}

@Composable
private fun RowScope.Tile(item: Shortcut, colors: WidgetColors, labels: Boolean, stacked: Boolean) {
    val context = LocalContext.current
    val fill = if (item.primary) colors.seal else colors.tile
    val ink = if (item.primary) colors.onSeal else colors.ink
    Box(
        GlanceModifier.defaultWeight().fillMaxHeight()
            .shape(R.drawable.widget_tile, fill)
            .clickable(openApp(context, item.path))
            .semantics { contentDescription = item.label }
            .padding(horizontal = 6.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        val icon = @Composable { dp: Int ->
            Image(
                ImageProvider(item.icon),
                contentDescription = null,
                colorFilter = ColorFilter.tint(if (item.primary) ink else colors.accent),
                modifier = GlanceModifier.size(dp.dp),
            )
        }
        when {
            !labels -> icon(22)
            stacked -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                icon(26)
                Spacer(GlanceModifier.height(4.dp))
                Text(item.label, maxLines = 1, style = sans(13.sp, ink, FontWeight.Medium, TextAlign.Center))
            }
            else -> Row(verticalAlignment = Alignment.CenterVertically) {
                icon(18)
                Spacer(GlanceModifier.width(6.dp))
                Text(item.label, maxLines = 1, style = sans(12.sp, ink, FontWeight.Medium))
            }
        }
    }
}
