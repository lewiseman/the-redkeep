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
import androidx.glance.action.Action
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
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.unit.ColorProvider
import com.lewiseman.redkeep.R
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * One tap into writing: today's date and how the diary stands, a prompt (or a
 * raven's letter from a year ago), and buttons for a page, a note and more.
 */
class QuickCaptureWidget : GlanceAppWidget() {
    companion object {
        private val BAR = DpSize(110.dp, 40.dp)
        private val WIDE_BAR = DpSize(220.dp, 40.dp)
        private val SQUARE = DpSize(110.dp, 110.dp)
        private val WIDE = DpSize(220.dp, 110.dp)
        private val TALL = DpSize(220.dp, 180.dp)
    }

    override val sizeMode = SizeMode.Exact
    override val previewSizeMode = SizeMode.Responsive(setOf(WIDE_BAR, WIDE, TALL))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        WidgetRefresh.armMidnight(context)
        provideContent { QuickCapture(WidgetStore.load(context), LocalDate.now()) }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        val today = LocalDate.now()
        provideContent { QuickCapture(sampleSnapshot(today), today) }
    }
}

class QuickCaptureWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuickCaptureWidget()
}

private class Shortcut(val icon: Int, val label: String, val path: String, val primary: Boolean = false)

private val shortcuts = listOf(
    Shortcut(R.drawable.ic_widget_quill, "Write", WidgetLinks.WRITE, primary = true),
    Shortcut(R.drawable.ic_widget_note, "Note", WidgetLinks.NEW_NOTE),
    Shortcut(R.drawable.ic_widget_film, "Watchlist", WidgetLinks.WATCHLIST),
    Shortcut(R.drawable.ic_widget_search, "Search", WidgetLinks.SEARCH),
)

@Composable
private fun QuickCapture(snapshot: WidgetSnapshot?, today: LocalDate) {
    val colors = WidgetColors(snapshot)
    val model = snapshot?.let { DiaryWidgetModel(it, today) }
    val size = LocalSize.current
    val wide = size.width >= 200.dp
    val bar = size.height < 100.dp
    Box(
        GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(24.dp)
            .background(ImageProvider(colors.paper))
            .padding(if (bar) 6.dp else 12.dp),
    ) {
        val visible = if (wide) shortcuts else shortcuts.take(2)
        if (bar) {
            Tiles(visible, colors, vertical = false)
            return@Box
        }
        Column(GlanceModifier.fillMaxSize()) {
            Header(model, today, colors, wide)
            if (size.height >= 170.dp) {
                Spacer(GlanceModifier.height(10.dp))
                Prompt(model, today, colors, GlanceModifier.fillMaxWidth().defaultWeight())
                Spacer(GlanceModifier.height(10.dp))
            } else {
                Spacer(GlanceModifier.defaultWeight())
            }
            Box(GlanceModifier.fillMaxWidth().height(if (wide) 58.dp else 50.dp)) {
                Tiles(visible, colors, vertical = wide)
            }
        }
    }
}

@Composable
private fun Header(model: DiaryWidgetModel?, today: LocalDate, colors: WidgetColors, wide: Boolean) {
    val context = LocalContext.current
    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(GlanceModifier.defaultWeight().clickable(openApp(context, WidgetLinks.TODAY))) {
            Text(
                today.format(DateTimeFormatter.ofPattern("EEEE", Locale.getDefault())),
                maxLines = 1,
                style = serif(if (wide) 20.sp else 16.sp, colors.ink),
            )
            Text(
                today.format(DateTimeFormatter.ofPattern("d MMMM", Locale.getDefault())),
                maxLines = 1,
                style = sans(11.sp, colors.muted),
            )
        }
        if (model == null) return@Row
        when {
            model.writtenToday -> Pill(
                "${model.todayMood ?: "✓"}${if (wide) "  Written" else ""}",
                colors.accentSoft, colors.accent, openApp(context, WidgetLinks.TODAY),
                size = 12.sp, horizontal = 10.dp, vertical = 5.dp,
            )
            model.streak > 0 -> Pill(
                "🔥 ${model.streak}", colors.sealSoft, colors.seal, openApp(context, WidgetLinks.WRITE),
                size = 12.sp, horizontal = 10.dp, vertical = 5.dp,
            )
        }
    }
}

/** A raven's letter when an earlier day echoes today; otherwise a prompt. */
@Composable
private fun Prompt(model: DiaryWidgetModel?, today: LocalDate, colors: WidgetColors, modifier: GlanceModifier) {
    val context = LocalContext.current
    val raven = model?.raven
    val (eyebrow, line, action) = if (raven != null) {
        Triple(
            "🪶  ${raven.echo}",
            "You wrote on ${raven.date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))}. Read it again?",
            openApp(context, WidgetLinks.day(raven.date)),
        )
    } else {
        Triple(
            if (model?.writtenToday == true) "✏️  For tomorrow" else "✏️  Today's prompt",
            dailyPrompt(if (model?.writtenToday == true) today.plusDays(1) else today),
            openApp(context, WidgetLinks.WRITE),
        )
    }
    Column(
        modifier.shape(R.drawable.widget_tile, colors.accentSoft).padding(horizontal = 12.dp, vertical = 10.dp).clickable(action),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(eyebrow, maxLines = 1, style = sans(11.sp, colors.accent, FontWeight.Bold))
        Spacer(GlanceModifier.height(3.dp))
        Text(line, maxLines = 2, style = serif(14.sp, colors.ink, bold = false))
    }
}

@Composable
private fun Tiles(items: List<Shortcut>, colors: WidgetColors, vertical: Boolean) {
    Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        items.forEachIndexed { index, item ->
            if (index > 0) Spacer(GlanceModifier.width(6.dp))
            Tile(item, colors, vertical)
        }
    }
}

@Composable
private fun RowScope.Tile(item: Shortcut, colors: WidgetColors, vertical: Boolean) {
    val context = LocalContext.current
    val fill: ColorProvider = if (item.primary) colors.seal else colors.tile
    val ink: ColorProvider = if (item.primary) colors.onSeal else colors.ink
    val action: Action = openApp(context, item.path)
    Box(
        GlanceModifier.defaultWeight().fillMaxHeight()
            .shape(R.drawable.widget_tile, fill)
            .clickable(action)
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
        if (vertical) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                icon(20)
                Spacer(GlanceModifier.height(3.dp))
                Text(item.label, maxLines = 1, style = sans(11.sp, ink, FontWeight.Medium, TextAlign.Center))
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                icon(18)
                Spacer(GlanceModifier.width(6.dp))
                Text(item.label, maxLines = 1, style = sans(12.sp, ink, FontWeight.Medium))
            }
        }
    }
}

private val prompts = listOf(
    "What made you smile today?",
    "What is one thing you want to remember about today?",
    "Who did you think about today, and why?",
    "What surprised you today?",
    "What felt heavy today, and what felt light?",
    "Describe a small moment you nearly missed.",
    "What are you looking forward to this week?",
    "What would you tell yourself from a year ago?",
    "What did you learn today, however small?",
    "Where did your mind wander most today?",
    "What are you grateful for right now?",
    "What did you eat, hear or read that stayed with you?",
    "What is something you want to let go of?",
    "Which conversation today mattered most?",
    "What did today ask of you?",
    "If today had a title, what would it be?",
    "What made you feel at home today?",
    "What is a question you keep coming back to?",
    "What gave you energy today, and what took it?",
    "Write about a place you saw today.",
    "What would make tomorrow a good day?",
)

private fun dailyPrompt(date: LocalDate) = prompts[(date.toEpochDay() % prompts.size).toInt()]
