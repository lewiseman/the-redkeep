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
import androidx.glance.layout.ContentScale
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
        private val STRIP = DpSize(220.dp, 70.dp)
        private val WIDE = DpSize(220.dp, 150.dp)
        private val SQUARE = DpSize(170.dp, 250.dp)
        private val LARGE = DpSize(300.dp, 300.dp)
    }

    // Exact: the month's discs are sized to the widget's real cells.
    override val sizeMode = SizeMode.Exact
    override val previewSizeMode = SizeMode.Responsive(setOf(SMALL, STRIP, WIDE, SQUARE, LARGE))

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
            .background(ImageProvider(colors.paper), contentScale = ContentScale.Crop)
            .padding(pad),
    ) {
        if (snapshot == null) {
            Welcome(colors)
            return@Box
        }
        val model = DiaryWidgetModel(snapshot, today)
        // Each size shows as much of the diary as fits, never empty paper:
        // 2×1 a line, 2×2 the streak, 4×1 this week, 4×2 two weeks, then the month.
        when {
            size.width < 200.dp && size.height < 100.dp -> StreakLine(model, colors)
            size.width < 200.dp -> StreakFace(model, colors)
            size.height < 140.dp -> WeekFace(model, colors, size, pad, weeks = 1)
            size.height < 240.dp -> WeekFace(model, colors, size, pad, weeks = 2)
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
        LastSevenDots(model, colors)
    }
}

/** 2×1: the streak and a dot for each of the last seven days. */
@Composable
private fun StreakLine(model: DiaryWidgetModel, colors: WidgetColors) {
    val context = LocalContext.current
    Row(
        GlanceModifier.fillMaxSize()
            .clickable(openApp(context, if (model.writtenToday) WidgetLinks.TODAY else WidgetLinks.WRITE)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (model.streak > 0) {
            Text("🔥 ${model.streak}", maxLines = 1, style = sans(13.sp, colors.seal, FontWeight.Bold))
            Spacer(GlanceModifier.width(8.dp))
        }
        LastSevenDots(model, colors)
    }
}

/** A dot per day for the last week: inked if written, today ringed if blank. */
@Composable
private fun LastSevenDots(model: DiaryWidgetModel, colors: WidgetColors) {
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

/** The 🔥 streak; tapping it opens today's page. */
@Composable
private fun StreakChip(model: DiaryWidgetModel, colors: WidgetColors) {
    Pill(
        "🔥 ${model.streak}", colors.sealSoft, colors.seal,
        openApp(LocalContext.current, WidgetLinks.TODAY),
        size = 12.sp, horizontal = 10.dp, vertical = 5.dp,
        modifier = GlanceModifier.semantics { contentDescription = "${model.streak} day streak" },
    )
}

/** The streak chip, laid in a run of blank squares [width] wide. */
@Composable
private fun BlankStreak(model: DiaryWidgetModel, colors: WidgetColors, width: Dp, align: Alignment) {
    Box(GlanceModifier.width(width).fillMaxHeight().padding(horizontal = 4.dp), contentAlignment = align) {
        StreakChip(model, colors)
    }
}

/**
 * 4×1 this week, 4×2 the last two: days with their moods, weekdays above,
 * and the streak as a badge on today.
 */
@Composable
private fun WeekFace(model: DiaryWidgetModel, colors: WidgetColors, size: DpSize, pad: Dp, weeks: Int) {
    val context = LocalContext.current
    val rows = model.recentWeeks(weeks)
    // Each day's box fits its column and its row; the ring leaves the badge room.
    val box = minOf((size.width - pad * 2) / 7, (size.height - pad * 2 - 18.dp) / weeks).coerceIn(30.dp, 64.dp)
    Column(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        WeekdayLabels(rows.last(), model, colors)
        for (week in rows) {
            Row(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
                for (day in week) {
                    Box(GlanceModifier.defaultWeight().fillMaxHeight(), contentAlignment = Alignment.Center) {
                        Box(GlanceModifier.size(box), contentAlignment = Alignment.Center) {
                            if (day == model.today) Day(day, model, colors, box, context, badge = true)
                            else Day(day, model, colors, box - BADGE_ROOM, context)
                        }
                    }
                }
            }
        }
    }
}

/** "Mon … Sun" over the grid; today's in red. */
@Composable
private fun WeekdayLabels(week: List<LocalDate>, model: DiaryWidgetModel, colors: WidgetColors) {
    Row(GlanceModifier.fillMaxWidth()) {
        for (day in week) {
            Text(
                weekday(day),
                maxLines = 1,
                modifier = GlanceModifier.defaultWeight(),
                style = sans(11.sp, if (day == model.today) colors.seal else colors.ink, FontWeight.Bold, TextAlign.Center),
            )
        }
    }
}

/** 4×3 and up: the whole month; tapping today writes today's page. */
@Composable
private fun MonthFace(model: DiaryWidgetModel, colors: WidgetColors, size: DpSize, pad: Dp) {
    val context = LocalContext.current
    val weeks = model.monthWeeks
    Column(GlanceModifier.fillMaxSize()) {
        WeekdayLabels(model.week, model, colors)
        Spacer(GlanceModifier.height(2.dp))
        val chrome = 20.dp
        val byWidth = (size.width - pad * 2) / 7
        val byHeight = (size.height - pad * 2 - chrome) / weeks.size
        val cell = (minOf(byWidth * .86f, byHeight - 4.dp)).coerceIn(16.dp, 44.dp)
        // Glance rows and columns hold at most ten children: the weeks get
        // a column of their own.
        // The streak takes the month's blank squares, so it costs no row.
        // With none free, it badges today instead.
        val slot = model.streakSlot.takeIf { model.streak > 0 }
        Column(GlanceModifier.fillMaxWidth().defaultWeight()) {
            weeks.forEachIndexed { w, week ->
                val here = slot?.takeIf { it.week == w }
                Row(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
                    if (here != null && here.first == 0) BlankStreak(model, colors, byWidth * here.count, Alignment.CenterStart)
                    week.forEachIndexed { i, day ->
                        if (here == null || i !in here.first until here.first + here.count) {
                            Box(GlanceModifier.defaultWeight().fillMaxHeight(), contentAlignment = Alignment.Center) {
                                if (day != null) Day(day, model, colors, cell, context, badge = slot == null && day == model.today)
                            }
                        }
                    }
                    if (here != null && here.first > 0) BlankStreak(model, colors, byWidth * here.count, Alignment.CenterEnd)
                }
            }
        }
    }
}

/**
 * One day: its mood emoji on bare paper, an inked disc if written without one.
 * With [badge], a small 🔥 streak sits on its top-right edge.
 */
@Composable
private fun Day(
    day: LocalDate,
    model: DiaryWidgetModel,
    colors: WidgetColors,
    size: Dp,
    context: Context,
    badge: Boolean = false,
) {
    if (badge && model.streak > 0) {
        // [size] is the whole box: the ring shrinks so the badge overhangs
        // it inside the box, where nothing clips it.
        Box(GlanceModifier.size(size), contentAlignment = Alignment.Center) {
            Day(day, model, colors, size - BADGE_ROOM, context)
            Box(GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopEnd) {
                Box(
                    GlanceModifier.shape(R.drawable.widget_pill, colors.seal)
                        .padding(horizontal = 4.dp, vertical = 1.dp)
                        .clickable(openApp(context, WidgetLinks.TODAY))
                        .semantics { contentDescription = "${model.streak} day streak" },
                ) {
                    Text("🔥${model.streak}", maxLines = 1, style = sans(fitSp(context, 11f), colors.onSeal, FontWeight.Bold))
                }
            }
        }
        return
    }
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
            mood != null -> GlanceModifier.size(inner)
            written -> GlanceModifier.size(inner).shape(R.drawable.widget_circle, colors.accent)
            today -> GlanceModifier.size(inner).shape(R.drawable.widget_circle, colors.sealSoft)
            else -> GlanceModifier.size(inner)
        }
        Box(disc, contentAlignment = Alignment.Center) {
            if (mood != null) {
                Text(mood, maxLines = 1, style = TextStyle(fontSize = fitSp(context, inner.value * .78f), textAlign = TextAlign.Center))
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

/** "Mon", "Tue"… in the reader's language. */
private fun weekday(day: LocalDate) =
    day.dayOfWeek.getDisplayName(DateText.SHORT_STANDALONE, Locale.getDefault())

/** Space around a day for the streak badge to overhang its ring. */
private val BADGE_ROOM = 14.dp

/** Glyphs sized to their disc, whatever the font scale: the grid is fixed. */
internal fun fitSp(context: Context, dp: Float) =
    (dp / context.resources.configuration.fontScale.coerceAtLeast(.5f)).sp
