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
    fun monthIsMondayFirstWithItsMostPickedMood() {
        val m = model(
            LocalDate.of(2026, 11, 2) to "😌", LocalDate.of(2026, 11, 3) to "😊",
            LocalDate.of(2026, 11, 4) to "😊", LocalDate.of(2026, 10, 31) to "😌",
        )
        // 1 November 2026 is a Sunday: six blanks lead the first week.
        assertEquals(List(6) { null } + LocalDate.of(2026, 11, 1), m.monthWeeks.first())
        assertEquals(6, m.monthWeeks.size)
        assertTrue(m.monthWeeks.all { it.size == 7 })
        assertEquals(3, m.monthDays)
        assertEquals("😊", m.topMood)
        assertEquals(LocalDate.of(2026, 11, 16), m.week.first())
    }
}
