package com.lewiseman.redkeep.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.padding
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.lewiseman.redkeep.MainActivity
import com.lewiseman.redkeep.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import androidx.glance.color.ColorProvider as DayNight

/** The diary's parchment and ink, tinted by the reader's chosen accent. */
class WidgetColors(snapshot: WidgetSnapshot?) {
    private val theme = snapshot?.theme ?: "system"
    private fun tone(day: Long, night: Long) = tone(Color(day), Color(night))
    private fun tone(day: Color, night: Color): ColorProvider = when (theme) {
        "light" -> ColorProvider(day)
        "dark" -> ColorProvider(night)
        else -> DayNight(day = day, night = night)
    }
    private val accentDay = Color(snapshot?.accent ?: 0xFF161658.toInt())
    private val accentNight = Color(snapshot?.accentDark ?: 0xFFB9B7FF.toInt())

    val paper = when (theme) {
        "light" -> R.drawable.widget_paper_light
        "dark" -> R.drawable.widget_paper_dark
        else -> R.drawable.widget_paper
    }
    val ink = tone(0xFF2B2118, 0xFFF1E6CE)
    val muted = tone(0xFF85704F, 0xFFA89B84)
    val faint = tone(0x6685704F, 0x55A89B84)
    val accent = tone(accentDay, accentNight)
    val accentSoft = tone(accentDay.copy(alpha = .14f), accentNight.copy(alpha = .20f))
    val onAccent = tone(0xFFFBF3E1, 0xFF15121A)
    val seal = tone(0xFF9E1B17, 0xFFE0574A)
    val sealSoft = tone(0x229E1B17, 0x2EE0574A)
    val onSeal = tone(0xFFFFF6E6, 0xFF1C0907)
    val tile = tone(0x14000000, 0x14FFFFFF)
}

/** Opens [path] in the app; Flutter reads the path as its route. */
fun openApp(context: Context, path: String): Action = actionStartActivity(
    Intent(context, MainActivity::class.java)
        .setAction(Intent.ACTION_VIEW)
        .setData(Uri.parse("redkeep://app$path"))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
)

object WidgetLinks {
    const val WRITE = "/diary/write"
    const val TODAY = "/diary/today"
    const val DIARY = "/diary"
    const val NEW_NOTE = "/notes/write"
    const val WATCHLIST = "/watchlist"
    const val SEARCH = "/diary/search"
    fun day(date: LocalDate) = "/diary/day/$date"
}

/** A shape drawable behind content, tinted to [color]. */
fun GlanceModifier.shape(drawable: Int, color: ColorProvider) =
    background(ImageProvider(drawable), colorFilter = ColorFilter.tint(color))

fun serif(size: TextUnit, color: ColorProvider, bold: Boolean = true) = TextStyle(
    color = color,
    fontSize = size,
    fontFamily = FontFamily.Serif,
    fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
)

fun sans(
    size: TextUnit,
    color: ColorProvider,
    weight: FontWeight = FontWeight.Normal,
    align: TextAlign = TextAlign.Start,
) = TextStyle(color = color, fontSize = size, fontWeight = weight, textAlign = align)

/** A pill: the seal for the main call, accent-soft for the rest. */
@Composable
fun Pill(
    text: String,
    background: ColorProvider,
    color: ColorProvider,
    action: Action,
    size: TextUnit = 13.sp,
    horizontal: Dp = 14.dp,
    vertical: Dp = 8.dp,
    modifier: GlanceModifier = GlanceModifier,
) {
    Box(
        modifier = modifier
            .shape(R.drawable.widget_pill, background)
            .padding(horizontal = horizontal, vertical = vertical)
            .clickable(action),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, maxLines = 1, style = sans(size, color, FontWeight.Medium, TextAlign.Center))
    }
}

/** A month of sample writing, for the widget picker's previews. */
fun sampleSnapshot(today: LocalDate): WidgetSnapshot {
    val moods = listOf("😊", "", "😌", "🤩", "😊", "", "😴", "😌", "😊", "🤩", "", "😌")
    val days = (1L..40L).filter { it % 7L != 5L }
        .associate { back -> today.minusDays(back) to moods[(back % moods.size).toInt()] }
    return WidgetSnapshot("system", 0xFF161658.toInt(), 0xFFB9B7FF.toInt(), days)
}

/** Redraws every widget, and keeps one wake-up armed for the next midnight. */
object WidgetRefresh {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private const val PREVIEWS_VERSION = 2

    fun all(context: Context) {
        val app = context.applicationContext
        scope.launch {
            runCatching { DiaryMonthWidget().updateAll(app) }
            runCatching { QuickCaptureWidget().updateAll(app) }
        }
        armMidnight(app)
    }

    /**
     * Generated previews for the widget picker (Android 15+). An app update
     * clears them, so they are published again once per install or update.
     */
    fun publishPreviews(context: Context) {
        if (Build.VERSION.SDK_INT < 35) return
        val app = context.applicationContext
        val prefs = app.getSharedPreferences("redkeep_home_widgets", Context.MODE_PRIVATE)
        val installed = runCatching {
            app.packageManager.getPackageInfo(app.packageName, 0).lastUpdateTime
        }.getOrDefault(0L)
        val key = "$PREVIEWS_VERSION:$installed"
        if (prefs.getString("previewsFor", null) == key) return
        scope.launch {
            runCatching {
                val manager = GlanceAppWidgetManager(app)
                val ok = GlanceAppWidgetManager.SET_WIDGET_PREVIEWS_RESULT_SUCCESS
                // Android rate-limits previews; a refused publish retries next launch.
                val month = manager.setWidgetPreviews(DiaryMonthWidgetReceiver::class)
                val capture = manager.setWidgetPreviews(QuickCaptureWidgetReceiver::class)
                if (month == ok && capture == ok) {
                    prefs.edit().putString("previewsFor", key).apply()
                }
            }
        }
    }

    fun armMidnight(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val zone = ZoneId.systemDefault()
        val next = LocalDate.now(zone).plusDays(1).atStartOfDay(zone).plusMinutes(1)
        val intent = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, WidgetClockReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        // Inexact is fine: the widgets only need the new day soon after midnight.
        alarms.set(AlarmManager.RTC, next.toInstant().toEpochMilli(), intent)
    }
}

/** Midnight, a new time zone or a changed clock: turn the widgets' page. */
class WidgetClockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetRefresh.all(context)
    }
}
