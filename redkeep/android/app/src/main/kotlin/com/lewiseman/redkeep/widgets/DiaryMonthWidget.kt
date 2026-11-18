package com.lewiseman.redkeep.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
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
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.lewiseman.redkeep.R
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import java.time.format.TextStyle as DateText

/**
 * The diary's month on the home screen: each written day wears its mood,
 * today wears a wax-seal ring, and the streak sits in the corner.
 */
class DiaryMonthWidget : GlanceAppWidget() {
    companion object {
        private val SMALL = DpSize(110.dp, 110.dp)
        private val WIDE = DpSize(220.dp, 110.dp)
        private val SQUARE = DpSize(170.dp, 250.dp)
        private val LARGE = DpSize(300.dp, 300.dp)
    }

    // Exact: the month's discs are sized to the widget's real cells.
    override val sizeMode = SizeMode.Exact
    override val previewSizeMode = SizeMode.Responsive(setOf(SMALL, WIDE, SQUARE, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        WidgetRefresh.armMidnight(context)
        provideContent { DiaryMonth(WidgetStore.load(context), LocalDate.now()) }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        val today = LocalDate.now()
        provideContent { DiaryMonth(sampleSnapshot(today), today) }
    }
}

class DiaryMonthWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DiaryMonthWidget()
}

@Composable
private fun DiaryMonth(snapshot: WidgetSnapshot?, today: LocalDate) {
    val colors = WidgetColors(snapshot)
    val size = LocalSize.current
    val pad = if (size.width < 200.dp) 12.dp else 14.dp
    Box(
        GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(24.dp)
            .background(ImageProvider(colors.paper))
            .padding(pad),
    ) {
        if (snapshot == null) {
            Welcome(colors)
            return@Box
        }
        val model = DiaryWidgetModel(snapshot, today)
        when {
            size.width < 200.dp -> StreakFace(model, colors)
            size.height < 240.dp -> WeekFace(model, colors, size, pad)
            else -> MonthFace(model, colors, size, pad)
        }
    }
}

@Composable
private fun Welcome(colors: WidgetColors) {
    val context = LocalContext.current
    Column(
        GlanceModifier.fillMaxSize().clickable(openApp(context, WidgetLinks.DIARY)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        QuillSeal(colors, 48.dp)
        Spacer(GlanceModifier.height(10.dp))
        Text("Your diary, at a glance", maxLines = 2, style = serif(15.sp, colors.ink).copy(textAlign = TextAlign.Center))
        Spacer(GlanceModifier.height(2.dp))
        Text("Open Redkeep to begin", maxLines = 1, style = sans(11.sp, colors.muted, align = TextAlign.Center))
    }
}

/** 2×2: the streak, today's mood or quill, and the last seven days. */
@Composable
private fun StreakFace(model: DiaryWidgetModel, colors: WidgetColors) {
    val context = LocalContext.current
    val action = openApp(context, if (model.writtenToday) WidgetLinks.TODAY else WidgetLinks.WRITE)
    Column(
        GlanceModifier.fillMaxSize().clickable(action),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(monthName(model.today).uppercase(), maxLines = 1, style = sans(10.sp, colors.muted, FontWeight.Bold))
            Spacer(GlanceModifier.defaultWeight())
            if (model.streak > 0) {
                Text("🔥 ${model.streak}", maxLines = 1, style = sans(12.sp, colors.seal, FontWeight.Bold))
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        val mood = model.todayMood
        when {
            mood != null -> Text(mood, style = TextStyle(fontSize = fitSp(context, 34f)))
            model.writtenToday -> Text("✓", style = serif(fitSp(context, 30f), colors.accent))
            else -> QuillSeal(colors, 42.dp)
        }
        Spacer(GlanceModifier.height(4.dp))
        Text(
            when {
                model.streak > 1 -> "${model.streak}-day streak"
                model.writtenToday -> "Today is written"
                else -> "Today's page"
            },
            maxLines = 1,
            style = serif(13.sp, colors.ink).copy(textAlign = TextAlign.Center),
        )
        Spacer(GlanceModifier.defaultWeight())
        Row(verticalAlignment = Alignment.CenterVertically) {
            for (back in 6 downTo 0) {
                val day = model.today.minusDays(back.toLong())
                val tint = when {
                    model.written(day) -> colors.accent
                    back == 0 -> colors.seal
                    else -> colors.faint
                }
                Box(
                    GlanceModifier.size(9.dp).shape(
                        if (back == 0 && !model.written(day)) R.drawable.widget_ring else R.drawable.widget_circle,
                        tint,
                    ),
                ) {}
                if (back > 0) Spacer(GlanceModifier.width(4.dp))
            }
        }
    }
}

/** 4×2 (under 240dp tall): this week's days with their moods; tapping today writes. */
@Composable
private fun WeekFace(model: DiaryWidgetModel, colors: WidgetColors, size: DpSize, pad: Dp) {
    val context = LocalContext.current
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(GlanceModifier.defaultWeight()) {
                Text(
                    model.today.format(DateTimeFormatter.ofPattern("EEEE d MMM", Locale.getDefault())),
                    maxLines = 1,
                    style = serif(16.sp, colors.ink),
                )
                Text(
                    when {
                        model.writtenToday && model.streak > 1 -> "🔥 ${model.streak}-day streak"
                        model.writtenToday -> "Today's page is written"
                        model.streak > 0 -> "Keep your ${model.streak}-day streak going"
                        else -> "A blank page is waiting"
                    },
                    maxLines = 1,
                    style = sans(11.sp, colors.muted),
                )
            }
        }
        Spacer(GlanceModifier.height(6.dp))
        val byHeight = size.height - pad * 2 - 58.dp
        val cell = minOf((size.width - pad * 2) / 7 * .82f, byHeight).coerceIn(18.dp, 40.dp)
        Row(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
            for (day in model.week) {
                Column(
                    GlanceModifier.defaultWeight().fillMaxHeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        day.dayOfWeek.getDisplayName(DateText.NARROW_STANDALONE, Locale.getDefault()),
                        maxLines = 1,
                        style = sans(10.sp, if (day == model.today) colors.seal else colors.muted, FontWeight.Medium),
                    )
                    Spacer(GlanceModifier.height(3.dp))
                    Day(day, model, colors, cell, context)
                }
            }
        }
    }
}

/** 4×3 and up: the whole month; tapping today writes today's page. */
@Composable
private fun MonthFace(model: DiaryWidgetModel, colors: WidgetColors, size: DpSize, pad: Dp) {
    val context = LocalContext.current
    val weeks = model.monthWeeks
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(GlanceModifier.defaultWeight().clickable(openApp(context, WidgetLinks.DIARY))) {
                Text(monthName(model.today), maxLines = 1, style = serif(18.sp, colors.ink))
                Text(monthLine(model), maxLines = 1, style = sans(11.sp, colors.muted))
            }
            if (model.streak > 0) {
                Pill(
                    "🔥 ${model.streak}", colors.sealSoft, colors.seal,
                    openApp(context, WidgetLinks.TODAY),
                    size = 12.sp, horizontal = 10.dp, vertical = 5.dp,
                    modifier = GlanceModifier.semantics { contentDescription = "${model.streak} day streak" },
                )
            }
        }
        Spacer(GlanceModifier.height(6.dp))
        Row(GlanceModifier.fillMaxWidth()) {
            for (day in model.week) {
                Text(
                    day.dayOfWeek.getDisplayName(DateText.NARROW_STANDALONE, Locale.getDefault()),
                    maxLines = 1,
                    modifier = GlanceModifier.defaultWeight(),
                    style = sans(10.sp, colors.muted, FontWeight.Medium, TextAlign.Center),
                )
            }
        }
        Spacer(GlanceModifier.height(2.dp))
        val chrome = 48.dp + 20.dp
        val byWidth = (size.width - pad * 2) / 7
        val byHeight = (size.height - pad * 2 - chrome) / weeks.size
        val cell = (minOf(byWidth * .86f, byHeight - 4.dp)).coerceIn(16.dp, 44.dp)
        // Glance rows and columns hold at most ten children: the weeks get
        // a column of their own.
        Column(GlanceModifier.fillMaxWidth().defaultWeight()) {
            for (week in weeks) {
                Row(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
                    for (day in week) {
                        Box(GlanceModifier.defaultWeight().fillMaxHeight(), contentAlignment = Alignment.Center) {
                            if (day != null) Day(day, model, colors, cell, context)
                        }
                    }
                }
            }
        }
    }
}

/** One day: its mood on a soft disc, an inked disc if written without one. */
@Composable
private fun Day(day: LocalDate, model: DiaryWidgetModel, colors: WidgetColors, size: Dp, context: Context) {
    val today = day == model.today
    val written = model.written(day)
    val mood = model.mood(day)
    val future = day.isAfter(model.today)
    val inner = if (today) size - 6.dp else size
    val described = buildString {
        append(day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)))
        if (today) append(if (written) ", today" else ", today, tap to write")
        if (written) append(", written") else if (!future) append(", not written")
        if (mood != null) append(", mood $mood")
    }
    var outer = GlanceModifier.size(size)
        // Today writes today's page until it has writing, then opens it.
        .clickable(openApp(context, if (today && !written) WidgetLinks.WRITE else WidgetLinks.day(day)))
        .semantics { contentDescription = described }
    if (today) outer = outer.shape(R.drawable.widget_ring, colors.seal)
    Box(outer, contentAlignment = Alignment.Center) {
        val disc = when {
            mood != null -> GlanceModifier.size(inner).shape(R.drawable.widget_circle, colors.accentSoft)
            written -> GlanceModifier.size(inner).shape(R.drawable.widget_circle, colors.accent)
            today -> GlanceModifier.size(inner).shape(R.drawable.widget_circle, colors.sealSoft)
            else -> GlanceModifier.size(inner)
        }
        Box(disc, contentAlignment = Alignment.Center) {
            if (mood != null) {
                Text(mood, maxLines = 1, style = TextStyle(fontSize = fitSp(context, inner.value * .56f), textAlign = TextAlign.Center))
            } else {
                Text(
                    "${day.dayOfMonth}",
                    maxLines = 1,
                    style = sans(
                        fitSp(context, inner.value * (if (today) .5f else .42f)),
                        when {
                            written -> colors.onAccent
                            today -> colors.seal
                            future -> colors.faint
                            else -> colors.muted
                        },
                        if (written || today) FontWeight.Bold else FontWeight.Normal,
                        TextAlign.Center,
                    ),
                )
            }
        }
    }
}

/** A quill on a wax-seal disc. */
@Composable
private fun QuillSeal(colors: WidgetColors, size: Dp) {
    Box(GlanceModifier.size(size).shape(R.drawable.widget_circle, colors.seal), contentAlignment = Alignment.Center) {
        Image(
            ImageProvider(R.drawable.ic_widget_quill),
            contentDescription = null,
            colorFilter = ColorFilter.tint(colors.onSeal),
            modifier = GlanceModifier.size(size * .5f),
        )
    }
}

private fun monthName(date: LocalDate) =
    date.month.getDisplayName(DateText.FULL_STANDALONE, Locale.getDefault())

private fun monthLine(model: DiaryWidgetModel): String {
    val pages = model.monthDays
    if (pages == 0) return "A fresh month"
    val line = "$pages ${if (pages == 1) "day" else "days"} written"
    return model.topMood?.let { "$line · mostly $it" } ?: line
}

/** Glyphs sized to their disc, whatever the font scale: the grid is fixed. */
internal fun fitSp(context: Context, dp: Float) =
    (dp / context.resources.configuration.fontScale.coerceAtLeast(.5f)).sp
