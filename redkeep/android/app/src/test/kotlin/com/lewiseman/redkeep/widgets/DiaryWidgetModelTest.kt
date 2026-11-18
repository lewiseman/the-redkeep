package com.lewiseman.redkeep.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class DiaryWidgetModelTest {
    private val today = LocalDate.of(2026, 11, 18)
    private fun model(vararg days: Pair<LocalDate, String>) =
        DiaryWidgetModel(WidgetSnapshot("system", 0, 0, days.toMap()), today)

    @Test
    fun streakCountsBackFromToday() {
        val m = model(today to "😊", today.minusDays(1) to "", today.minusDays(2) to "😌", today.minusDays(4) to "")
        assertTrue(m.writtenToday)
        assertEquals("😊", m.todayMood)
        assertEquals(3, m.streak)
    }

    @Test
    fun blankTodayKeepsYesterdaysStreakAlive() {
        val m = model(today.minusDays(1) to "", today.minusDays(2) to "")
        assertFalse(m.writtenToday)
        assertEquals(2, m.streak)
        assertEquals(0, model(today.minusDays(2) to "").streak)
    }

    @Test
    fun monthIsMondayFirst() {
        val m = model(
            LocalDate.of(2026, 11, 2) to "😌", LocalDate.of(2026, 11, 3) to "😊",
            LocalDate.of(2026, 11, 4) to "😊", LocalDate.of(2026, 10, 31) to "😌",
        )
        // 1 November 2026 is a Sunday: six blanks lead the first week.
        assertEquals(List(6) { null } + LocalDate.of(2026, 11, 1), m.monthWeeks.first())
        assertEquals(6, m.monthWeeks.size)
        assertTrue(m.monthWeeks.all { it.size == 7 })
        assertEquals(LocalDate.of(2026, 11, 16), m.week.first())
    }

    @Test
    fun streakSitsInTheMonthsBlankSquares() {
        fun slot(date: LocalDate) = DiaryWidgetModel(WidgetSnapshot("system", 0, 0, emptyMap()), date).streakSlot
        // November 2026 starts on a Sunday: six blanks lead.
        assertEquals(StreakSlot(0, 0, 6), slot(today))
        // December 2026 starts on a Tuesday: one blank leads, three trail.
        assertEquals(StreakSlot(4, 4, 3), slot(LocalDate.of(2026, 12, 9)))
        // February 2027 starts on a Monday and fills four whole weeks.
        assertEquals(null, slot(LocalDate.of(2027, 2, 14)))
    }

    @Test
    fun twoWeeksEndWithThisOne() {
        val weeks = model().recentWeeks(2)
        assertEquals(LocalDate.of(2026, 11, 9), weeks[0].first())
        assertEquals(LocalDate.of(2026, 11, 22), weeks[1].last())
        assertEquals(listOf(7, 7), weeks.map { it.size })
    }
}
