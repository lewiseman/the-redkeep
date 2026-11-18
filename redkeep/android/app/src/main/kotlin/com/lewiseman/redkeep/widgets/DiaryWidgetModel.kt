package com.lewiseman.redkeep.widgets

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.TemporalAdjusters

/** What the app last published: written days (mood emoji, or "" for none). */
data class WidgetSnapshot(
    val theme: String,
    val accent: Int,
    val accentDark: Int,
    val days: Map<LocalDate, String>,
)

/**
 * Everything the widgets draw, worked out from the real date so they stay
 * right after midnight even when the app has not run.
 */
class DiaryWidgetModel(private val snapshot: WidgetSnapshot, val today: LocalDate) {
    fun written(date: LocalDate) = snapshot.days.containsKey(date)
    fun mood(date: LocalDate): String? = snapshot.days[date]?.takeIf { it.isNotEmpty() }

    val writtenToday get() = written(today)
    val todayMood get() = mood(today)

    /** Consecutive written days up to today; a blank today keeps yesterday's. */
    val streak: Int by lazy {
        var day = if (written(today)) today else today.minusDays(1)
        var count = 0
        while (written(day)) { count++; day = day.minusDays(1) }
        count
    }

    val month: YearMonth get() = YearMonth.from(today)
    val monthDays: Int by lazy { (1..month.lengthOfMonth()).count { written(month.atDay(it)) } }

    /** The month's most picked mood, earliest-picked on a tie. */
    val topMood: String? by lazy {
        (1..month.lengthOfMonth()).mapNotNull { mood(month.atDay(it)) }
            .groupingBy { it }.eachCount().maxByOrNull { it.value }?.key
    }

    /** Monday-first weeks covering the month; null pads the edges. */
    val monthWeeks: List<List<LocalDate?>> by lazy {
        val lead = month.atDay(1).dayOfWeek.value - 1
        val cells = List(lead) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
        cells.chunked(7).map { it + List(7 - it.size) { null } }
    }

    val week: List<LocalDate> by lazy {
        val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        (0L..6L).map { monday.plusDays(it) }
    }
}
