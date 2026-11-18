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

/** Blank squares in the month grid: [count] of them in [week], from [first]. */
data class StreakSlot(val week: Int, val first: Int, val count: Int)

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

    /** Monday-first weeks covering the month; null pads the edges. */
    val monthWeeks: List<List<LocalDate?>> by lazy {
        val lead = month.atDay(1).dayOfWeek.value - 1
        val cells = List(lead) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
        cells.chunked(7).map { it + List(7 - it.size) { null } }
    }

    /**
     * Where the month view tucks the streak: the blank squares before the 1st,
     * else those after the last day. Null when neither run has room for it
     * (two squares); only a 28-day February starting on a Monday has none.
     */
    val streakSlot: StreakSlot? by lazy {
        val lead = monthWeeks.first().takeWhile { it == null }.size
        val trail = monthWeeks.last().takeLastWhile { it == null }.size
        when {
            lead >= 2 -> StreakSlot(0, 0, lead)
            trail >= 2 -> StreakSlot(monthWeeks.lastIndex, 7 - trail, trail)
            else -> null
        }
    }

    val week: List<LocalDate> get() = recentWeeks(1).single()

    /** The last [count] Monday-first weeks, oldest first, ending with this one. */
    fun recentWeeks(count: Int): List<List<LocalDate>> {
        val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        return (count - 1 downTo 0).map { back ->
            val start = monday.minusWeeks(back.toLong())
            (0L..6L).map { start.plusDays(it) }
        }
    }
}
