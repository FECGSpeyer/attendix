package de.attendix.attendix.liveplan

import android.content.Context
import android.content.SharedPreferences

/**
 * DB_REVIEW_REST (F2): port of Ionic LivePlanTitles.java. Remembers the header
 * of each shown plan notification, so updates without a title keep it.
 */
object LivePlanTitles {

    private const val PREFS = "live_plan_titles"

    data class Entry(val attendanceId: Int, val planKey: String)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun put(context: Context, attendanceId: Int, planKey: String, title: String) {
        prefs(context).edit().putString("$attendanceId:$planKey", title).apply()
    }

    fun get(context: Context, attendanceId: Int, planKey: String, fallback: String): String =
        prefs(context).getString("$attendanceId:$planKey", null) ?: fallback

    fun has(context: Context, attendanceId: Int, planKey: String): Boolean =
        prefs(context).contains("$attendanceId:$planKey")

    fun remove(context: Context, attendanceId: Int, planKey: String) {
        prefs(context).edit().remove("$attendanceId:$planKey").apply()
    }

    fun all(context: Context): List<Entry> {
        val entries = mutableListOf<Entry>()
        for (key in prefs(context).all.keys) {
            val sep = key.indexOf(':')
            if (sep <= 0) continue
            val id = key.substring(0, sep).toIntOrNull() ?: continue
            entries.add(Entry(id, key.substring(sep + 1)))
        }
        return entries
    }
}
