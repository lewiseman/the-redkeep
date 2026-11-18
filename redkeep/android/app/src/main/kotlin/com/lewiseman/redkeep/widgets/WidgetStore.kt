package com.lewiseman.redkeep.widgets

import android.content.Context
import android.graphics.Color
import org.json.JSONObject
import java.time.LocalDate

/** The app's last widget snapshot, kept for the widgets to read at any time. */
object WidgetStore {
    private const val PREFS = "redkeep_home_widgets"
    private const val KEY = "snapshot"

    /** Stores [json] if it parses; returns whether it did. */
    fun save(context: Context, json: String): Boolean {
        if (parse(json) == null) return false
        prefs(context).edit().putString(KEY, json).apply()
        return true
    }

    fun load(context: Context): WidgetSnapshot? =
        prefs(context).getString(KEY, null)?.let(::parse)

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun parse(json: String): WidgetSnapshot? = runCatching {
        val root = JSONObject(json)
        val days = root.getJSONObject("days")
        val map = HashMap<LocalDate, String>(days.length())
        for (key in days.keys()) map[LocalDate.parse(key)] = days.optString(key, "")
        WidgetSnapshot(
            theme = root.optString("theme", "system"),
            accent = Color.parseColor(root.optString("accent", "#161658")),
            accentDark = Color.parseColor(root.optString("accentDark", "#B9B7FF")),
            days = map,
        )
    }.getOrNull()
}
