package com.example.shiftalarm

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONArray
import org.json.JSONObject

object Store {
    private const val PREFS = "shiftalarm"
    private const val KEY = "plan_v1"

    private var appContext: Context? = null

    var plan by mutableStateOf(Plan())
        private set

    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        plan = load()
    }

    fun update(block: (Plan) -> Unit) {
        val next = plan.deepCopy()
        block(next)
        plan = next
        save()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun load(): Plan {
        val ctx = appContext ?: return Plan()
        val raw = prefs(ctx).getString(KEY, null) ?: return Plan()
        return runCatching { decode(raw) }.getOrElse { Plan() }
    }

    private fun save() {
        val ctx = appContext ?: return
        runCatching { prefs(ctx).edit().putString(KEY, encode(plan)).apply() }
    }

    private fun encode(p: Plan): String {
        val o = JSONObject()
        o.put("pattern", JSONArray(p.pattern.map { it.name }))
        o.put("anchor", p.anchorEpochDay)
        o.put("crews", p.crews)
        o.put("myCrew", p.myCrew)
        o.put("crewNames", JSONArray(p.crewNames))
        o.put("masterOn", p.masterOn)
        p.calendarId?.let { o.put("calendarId", it) }

        val shifts = JSONArray()
        p.shifts.forEach { s ->
            shifts.put(JSONObject().apply {
                put("kind", s.kind.name)
                put("name", s.name)
                put("short", s.short)
                put("start", s.startMinute)
                put("hours", s.hours)
                put("lead", s.leadMinutes)
                put("color", s.colorHex)
                put("alarm", s.alarmEnabled)
            })
        }
        o.put("shifts", shifts)

        val ov = JSONObject()
        p.overrides.forEach { (k, v) -> ov.put(k, v.name) }
        o.put("overrides", ov)
        o.put("alarmOff", JSONArray(p.alarmOff.toList()))
        return o.toString()
    }

    private fun decode(raw: String): Plan {
        val o = JSONObject(raw)
        val p = Plan()

        o.optJSONArray("pattern")?.let { arr ->
            p.pattern = (0 until arr.length()).mapNotNull { i ->
                runCatching { ShiftKind.valueOf(arr.getString(i)) }.getOrNull()
            }.ifEmpty { p.pattern }
        }
        p.anchorEpochDay = o.optLong("anchor", p.anchorEpochDay)
        p.crews = o.optInt("crews", p.crews).coerceAtLeast(1)
        p.myCrew = o.optInt("myCrew", 0).coerceIn(0, p.crews - 1)
        o.optJSONArray("crewNames")?.let { arr ->
            p.crewNames = (0 until arr.length()).map { arr.optString(it) }
        }
        p.masterOn = o.optBoolean("masterOn", true)
        if (o.has("calendarId")) p.calendarId = o.optLong("calendarId")

        o.optJSONArray("shifts")?.let { arr ->
            val list = (0 until arr.length()).mapNotNull { i ->
                val s = arr.optJSONObject(i) ?: return@mapNotNull null
                val kind = runCatching { ShiftKind.valueOf(s.getString("kind")) }.getOrNull()
                    ?: return@mapNotNull null
                ShiftDef(
                    kind = kind,
                    name = s.optString("name", kind.name),
                    short = s.optString("short", kind.name.take(1)),
                    startMinute = s.optInt("start", 0),
                    hours = s.optInt("hours", 0),
                    leadMinutes = s.optInt("lead", 0),
                    colorHex = s.optString("color", "#D1D1D6"),
                    alarmEnabled = s.optBoolean("alarm", kind != ShiftKind.REST)
                )
            }
            if (list.size == ShiftKind.entries.size) p.shifts = list
        }

        o.optJSONObject("overrides")?.let { ov ->
            val map = mutableMapOf<String, ShiftKind>()
            ov.keys().forEach { key ->
                runCatching { ShiftKind.valueOf(ov.getString(key)) }.getOrNull()?.let { map[key] = it }
            }
            p.overrides = map
        }
        o.optJSONArray("alarmOff")?.let { arr ->
            p.alarmOff = (0 until arr.length()).map { arr.optString(it) }.toMutableSet()
        }
        return p
    }
}
