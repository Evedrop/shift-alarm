package com.example.shiftalarm

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

enum class ShiftKind { MORNING, AFTERNOON, NIGHT, STUDY, REST }

fun fmtMin(m: Int): String {
    val v = ((m % 1440) + 1440) % 1440
    return String.format("%02d:%02d", v / 60, v % 60)
}

data class ShiftDef(
    val kind: ShiftKind,
    val name: String,
    val short: String,
    val startMinute: Int,
    val hours: Int,
    val leadMinutes: Int,
    val colorHex: String,
    val alarmEnabled: Boolean
) {
    val isRest: Boolean get() = kind == ShiftKind.REST
    val startLabel: String get() = fmtMin(startMinute)
    val endLabel: String get() = fmtMin(startMinute + hours * 60)
    val rangeText: String get() = if (isRest) "—" else "$startLabel – $endLabel"
}

data class PlannedAlarm(
    val id: String,
    val triggerAt: Long,
    val shiftDate: LocalDate,
    val kind: ShiftKind,
    val minutes: Int
)

data class Preset(val name: String, val pattern: List<ShiftKind>, val crews: Int)

val PRESETS = listOf(
    Preset("五班三倒", listOf(ShiftKind.STUDY, ShiftKind.MORNING, ShiftKind.MORNING,
        ShiftKind.AFTERNOON, ShiftKind.AFTERNOON, ShiftKind.REST,
        ShiftKind.NIGHT, ShiftKind.NIGHT, ShiftKind.REST, ShiftKind.REST), 5),
    Preset("做二休二", listOf(ShiftKind.MORNING, ShiftKind.MORNING, ShiftKind.REST, ShiftKind.REST), 1),
    Preset("做一休一", listOf(ShiftKind.MORNING, ShiftKind.REST), 1),
    Preset("做五休二", listOf(ShiftKind.MORNING, ShiftKind.MORNING, ShiftKind.MORNING,
        ShiftKind.MORNING, ShiftKind.MORNING, ShiftKind.REST, ShiftKind.REST), 1),
    Preset("四班三倒", listOf(ShiftKind.MORNING, ShiftKind.MORNING, ShiftKind.AFTERNOON,
        ShiftKind.AFTERNOON, ShiftKind.NIGHT, ShiftKind.NIGHT, ShiftKind.REST, ShiftKind.REST), 4),
    Preset("白夜休休", listOf(ShiftKind.MORNING, ShiftKind.NIGHT, ShiftKind.REST, ShiftKind.REST), 1),
    Preset("三班轮转", listOf(ShiftKind.MORNING, ShiftKind.MORNING, ShiftKind.AFTERNOON,
        ShiftKind.AFTERNOON, ShiftKind.NIGHT, ShiftKind.NIGHT, ShiftKind.REST), 1)
)

data class Plan(
    var pattern: List<ShiftKind> = listOf(
        ShiftKind.STUDY, ShiftKind.MORNING, ShiftKind.MORNING,
        ShiftKind.AFTERNOON, ShiftKind.AFTERNOON, ShiftKind.REST,
        ShiftKind.NIGHT, ShiftKind.NIGHT, ShiftKind.REST, ShiftKind.REST
    ),
    var anchorEpochDay: Long = LocalDate.now().toEpochDay(),
    var crews: Int = 5,
    var myCrew: Int = 0,
    var crewNames: List<String> = listOf("甲班", "乙班", "丙班", "丁班", "戊班", "己班", "庚班", "辛班"),
    var shifts: List<ShiftDef> = defaultShifts(),
    var masterOn: Boolean = true,
    var overrides: MutableMap<String, ShiftKind> = mutableMapOf(),
    var alarmOff: MutableSet<String> = mutableSetOf(),
    var calendarId: Long? = null
) {
    fun crewStride(): Int =
        if (crews > 1 && pattern.isNotEmpty() && pattern.size % crews == 0) pattern.size / crews else 0

    fun crewName(index: Int): String =
        crewNames.getOrNull(index)?.takeIf { it.isNotBlank() } ?: "第${index + 1}班"

    fun shiftDef(kind: ShiftKind): ShiftDef =
        shifts.firstOrNull { it.kind == kind } ?: defaultShifts().first { it.kind == kind }

    fun baseShift(date: LocalDate, crew: Int): ShiftKind {
        if (pattern.isEmpty()) return ShiftKind.REST
        val len = pattern.size
        val n = date.toEpochDay() - anchorEpochDay + crew * crewStride()
        val i = (((n % len) + len) % len).toInt()
        return pattern[i]
    }

    fun shift(date: LocalDate, crew: Int = myCrew): ShiftKind {
        if (crew == myCrew) overrides[date.toString()]?.let { return it }
        return baseShift(date, crew)
    }

    fun isOverridden(date: LocalDate): Boolean = overrides.containsKey(date.toString())

    /** 响铃时刻（可能落在前一天，例如夜班 00:00 提前 45 分 → 前一天 23:15） */
    fun alarmDateTime(date: LocalDate): LocalDateTime? {
        if (!masterOn) return null
        if (alarmOff.contains(date.toString())) return null
        val def = shiftDef(shift(date))
        if (def.isRest || !def.alarmEnabled) return null
        val start = LocalTime.of(def.startMinute / 60, def.startMinute % 60)
        return LocalDateTime.of(date, start).minusMinutes(def.leadMinutes.toLong())
    }

    fun upcomingAlarms(from: LocalDateTime, days: Int = 14): List<PlannedAlarm> {
        if (!masterOn) return emptyList()
        val result = mutableListOf<PlannedAlarm>()
        val today = from.toLocalDate()
        for (offset in -1..days) {
            val d = today.plusDays(offset.toLong())
            val dt = alarmDateTime(d) ?: continue
            if (!dt.isAfter(from)) continue
            val def = shiftDef(shift(d))
            result += PlannedAlarm(
                id = "$d-${def.kind.name}",
                triggerAt = dt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                shiftDate = d,
                kind = def.kind,
                minutes = dt.hour * 60 + dt.minute
            )
        }
        return result.sortedBy { it.triggerAt }.take(days)
    }

    fun patternName(): String {
        PRESETS.firstOrNull { it.pattern == pattern && it.crews == crews }?.let { return it.name }
        return "自定义 ${pattern.size} 天循环"
    }

    /** 让某天正好等于循环里第 index 个位置 */
    fun anchorAligned(to: LocalDate, index: Int): LocalDate? {
        if (index < 0 || index >= pattern.size) return null
        val len = pattern.size
        val offset = ((index - myCrew * crewStride()) % len + len) % len
        return to.minusDays(offset.toLong())
    }

    fun shiftPreview(date: LocalDate, anchor: LocalDate): ShiftKind {
        if (pattern.isEmpty()) return ShiftKind.REST
        val len = pattern.size
        val n = date.toEpochDay() - anchor.toEpochDay() + myCrew * crewStride()
        val i = (((n % len) + len) % len).toInt()
        return pattern[i]
    }

    fun deepCopy(): Plan = copy(
        pattern = pattern.toList(),
        crewNames = crewNames.toList(),
        shifts = shifts.map { it.copy() },
        overrides = overrides.toMutableMap(),
        alarmOff = alarmOff.toMutableSet()
    )

    fun applyPreset(preset: Preset) {
        pattern = preset.pattern
        crews = preset.crews
        if (myCrew >= crews) myCrew = 0
        overrides.clear()
        alarmOff.clear()
    }

    fun normalizeCrews() {
        if (crews > 1 && (pattern.isEmpty() || pattern.size % crews != 0)) {
            crews = 1
            myCrew = 0
        }
        if (myCrew >= crews) myCrew = 0
    }
}

fun defaultShifts(): List<ShiftDef> = listOf(
    ShiftDef(ShiftKind.MORNING, "早班", "早", 8 * 60, 8, 30, "#FF9F0A", true),
    ShiftDef(ShiftKind.AFTERNOON, "中班", "中", 16 * 60, 8, 30, "#0A84FF", true),
    ShiftDef(ShiftKind.NIGHT, "夜班", "夜", 0, 8, 45, "#BF5AF2", true),
    ShiftDef(ShiftKind.STUDY, "学习", "学", 9 * 60, 8, 30, "#0E8A9E", true),
    ShiftDef(ShiftKind.REST, "休息", "休", 0, 0, 0, "#D1D1D6", false)
)

fun weekdayCN(date: LocalDate): String =
    listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")[date.dayOfWeek.value - 1]

fun mdCN(date: LocalDate): String = "${date.monthValue}月${date.dayOfMonth}日"

fun relativeDayCN(date: LocalDate, today: LocalDate = LocalDate.now()): String {
    val diff = date.toEpochDay() - today.toEpochDay()
    return when (diff) {
        0L -> "今天"
        1L -> "明天"
        2L -> "后天"
        else -> mdCN(date)
    }
}
