package com.example.shiftalarm

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import java.time.LocalDate
import java.time.ZoneId

data class CalOption(val id: Long, val name: String)

/** 把班表写进系统日历里「你选的那个」日历 */
object CalendarSync {
    private const val MARK = "shiftalarm"

    fun hasPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    fun calendars(context: Context): List<CalOption> {
        val out = mutableListOf<CalOption>()
        runCatching {
            val projection = arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME
            )
            context.contentResolver.query(
                CalendarContract.Calendars.CONTENT_URI,
                projection,
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?",
                arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
                null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    out += CalOption(cursor.getLong(0), cursor.getString(1) ?: "未命名日历")
                }
            }
        }
        return out
    }

    fun sync(context: Context, plan: Plan, calendarId: Long, days: Int = 30): Int {
        val resolver = context.contentResolver
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val from = today.atStartOfDay(zone).toInstant().toEpochMilli()
        val to = today.plusDays(days.toLong()).atStartOfDay(zone).toInstant().toEpochMilli()

        // 只删自己上次写的（DESCRIPTION 打标记）
        runCatching {
            resolver.delete(
                CalendarContract.Events.CONTENT_URI,
                "${CalendarContract.Events.CALENDAR_ID} = ? AND ${CalendarContract.Events.DESCRIPTION} = ? " +
                    "AND ${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTSTART} < ?",
                arrayOf(calendarId.toString(), MARK, from.toString(), to.toString())
            )
        }

        var written = 0
        for (offset in 0 until days) {
            val day = today.plusDays(offset.toLong())
            val def = plan.shiftDef(plan.shift(day))
            if (def.isRest) continue

            val startMillis = day.atStartOfDay(zone).plusMinutes(def.startMinute.toLong())
                .toInstant().toEpochMilli()
            val endMillis = startMillis + def.hours * 3_600_000L

            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, "${def.name} ${def.rangeText}")
                put(CalendarContract.Events.DESCRIPTION, MARK)
                put(CalendarContract.Events.DTSTART, startMillis)
                put(CalendarContract.Events.DTEND, endMillis)
                put(CalendarContract.Events.EVENT_TIMEZONE, zone.id)
                put(CalendarContract.Events.HAS_ALARM, 0)
            }
            runCatching { resolver.insert(CalendarContract.Events.CONTENT_URI, values) }
                .onSuccess { if (it != null) written++ }
        }
        return written
    }
}
