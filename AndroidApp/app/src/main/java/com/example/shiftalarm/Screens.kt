package com.example.shiftalarm

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

/* ------------------------------ 班组 ------------------------------ */

@Composable
fun CrewsScreen() {
    val plan = Store.plan
    val today = LocalDate.now()
    var weekStart by remember {
        mutableStateOf(today.minusDays((today.dayOfWeek.value - 1).toLong()))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column {
            Text(
                "${plan.patternName()} · ${plan.pattern.size} 天一轮",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text("班组", fontSize = 30.sp, fontWeight = FontWeight.Bold)
        }

        AppCard(modifier = Modifier.fillMaxWidth(), padding = 12) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.ChevronLeft,
                    contentDescription = "上周",
                    modifier = Modifier
                        .size(24.dp)
                        .clickable { weekStart = weekStart.minusDays(7L) }
                )
                Text(
                    "${mdCN(weekStart)} 起这一周",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = "下周",
                    modifier = Modifier
                        .size(24.dp)
                        .clickable { weekStart = weekStart.plusDays(7L) }
                )
            }

            Spacer(Modifier.height(8.dp))
            Row {
                Spacer(Modifier.width(46.dp))
                (0..6).forEach { offset ->
                    val d = weekStart.plusDays(offset.toLong())
                    Text(
                        "${d.dayOfMonth}",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            for (crew in 0 until plan.crews) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(
                            if (crew == plan.myCrew) Brand.copy(alpha = 0.12f) else Color.Transparent
                        )
                        .clickable { Store.update { it.myCrew = crew } }
                        .padding(vertical = 4.dp)
                ) {
                    Text(
                        plan.crewName(crew),
                        fontSize = 11.sp,
                        fontWeight = if (crew == plan.myCrew) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier.width(46.dp)
                    )
                    (0..6).forEach { offset ->
                        val d = weekStart.plusDays(offset.toLong())
                        val def = plan.shiftDef(plan.shift(d, crew))
                        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                            Box(
                                modifier = Modifier
                                    .size(26.dp)
                                    .clip(RoundedCornerShape(7.dp))
                                    .background(
                                        if (def.isRest) MaterialTheme.colorScheme.surfaceVariant
                                        else Color.fromHex(def.colorHex)
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    def.short,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (def.isRest) MaterialTheme.colorScheme.onSurfaceVariant else Color.White
                                )
                            }
                        }
                    }
                }
            }
        }

        Text(
            "点任意一行，把自己切换成那个班组",
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/* ------------------------------ 规律 ------------------------------ */

@Composable
fun RulesScreen() {
    val plan = Store.plan
    var showQuick by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column {
            Text(
                "${plan.patternName()} · ${plan.pattern.size} 天循环",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text("排班规律", fontSize = 30.sp, fontWeight = FontWeight.Bold)
        }

        AppCard(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showQuick = true }
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("🧭", fontSize = 20.sp)
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("快速排班", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        "选班组 → 点一天 → 选那天的班，后面自动往下排",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Text("开始", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Brand)
            }
        }

        SectionTitle("换成别的规律")
        AppCard(modifier = Modifier.fillMaxWidth(), padding = 10) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                PRESETS.chunked(2).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { preset ->
                            val selected = preset.name == plan.patternName()
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(
                                        if (selected) Brand else MaterialTheme.colorScheme.surfaceVariant
                                    )
                                    .clickable {
                                        Store.update {
                                            it.applyPreset(preset)
                                            it.anchorEpochDay = LocalDate.now().toEpochDay()
                                        }
                                    }
                                    .padding(vertical = 10.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    preset.name,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (selected) Color(0xFF1A1206) else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
        }

        SectionTitle("本轮循环")
        AppCard(modifier = Modifier.fillMaxWidth(), padding = 12) {
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                plan.pattern.forEachIndexed { index, kind ->
                    val def = plan.shiftDef(kind)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "第${index + 1}天",
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(3.dp))
                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (def.isRest) MaterialTheme.colorScheme.surfaceVariant
                                    else Color.fromHex(def.colorHex)
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                def.short,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (def.isRest) MaterialTheme.colorScheme.onSurfaceVariant else Color.White
                            )
                        }
                    }
                }
            }
        }
    }

    if (showQuick) {
        QuickStartSheet(onDismiss = { showQuick = false })
    }
}

/* ---------------------------- 快速排班 ---------------------------- */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickStartSheet(onDismiss: () -> Unit) {
    val plan = Store.plan
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var month by remember { mutableStateOf(YearMonth.from(LocalDate.now())) }
    var picked by remember { mutableStateOf(LocalDate.now()) }
    var kind by remember { mutableStateOf(ShiftKind.MORNING) }
    var patternIndex by remember { mutableStateOf<Int?>(null) }
    var edits by remember { mutableStateOf(mapOf<String, ShiftKind>()) }

    val indices = plan.pattern.indices.filter { plan.pattern[it] == kind }
    val selectedIndex = patternIndex?.takeIf { indices.contains(it) } ?: indices.firstOrNull()
    val anchor = selectedIndex?.let { plan.anchorAligned(picked, it) }

    fun baseKind(day: LocalDate): ShiftKind =
        if (anchor != null) plan.shiftPreview(day, anchor) else plan.shift(day)

    fun shownKind(day: LocalDate): ShiftKind = edits[day.toString()] ?: baseKind(day)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp)
                .padding(bottom = 26.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("快速排班", fontSize = 20.sp, fontWeight = FontWeight.Bold)

            if (plan.crews > 1) {
                Text("我是哪个班", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0 until plan.crews).forEach { crew ->
                        val on = crew == plan.myCrew
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(9.dp))
                                .background(if (on) Brand else MaterialTheme.colorScheme.surfaceVariant)
                                .clickable { Store.update { it.myCrew = crew } }
                                .padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                plan.crewName(crew),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (on) Color(0xFF1A1206) else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            Text("① 从哪天开始", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant)

            AppCard(modifier = Modifier.fillMaxWidth(), padding = 10) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.ChevronLeft,
                        contentDescription = "上月",
                        modifier = Modifier
                            .size(22.dp)
                            .clickable { month = month.minusMonths(1) }
                    )
                    Text(
                        "${month.year}年${month.monthValue}月",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        Icons.Filled.ChevronRight,
                        contentDescription = "下月",
                        modifier = Modifier
                            .size(22.dp)
                            .clickable { month = month.plusMonths(1) }
                    )
                }
                Spacer(Modifier.height(4.dp))
                val lead = (month.atDay(1).dayOfWeek.value + 6) % 7
                val days = month.lengthOfMonth()
                val rows = (lead + days + 6) / 7
                for (r in 0 until rows) {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        for (c in 0..6) {
                            val dayNumber = r * 7 + c - lead + 1
                            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                                if (dayNumber in 1..days) {
                                    val d = month.atDay(dayNumber)
                                    val on = d == picked
                                    Box(
                                        modifier = Modifier
                                            .size(30.dp)
                                            .clip(CircleShape)
                                            .background(if (on) Brand else Color.Transparent)
                                            .clickable {
                                                picked = d
                                                edits = emptyMap()
                                                patternIndex = null
                                            },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            "$dayNumber",
                                            fontSize = 13.sp,
                                            fontWeight = if (on) FontWeight.Bold else FontWeight.Normal,
                                            color = if (on) Color(0xFF1A1206) else MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                } else {
                                    Spacer(Modifier.height(30.dp))
                                }
                            }
                        }
                    }
                }
            }

            Text(
                "② ${mdCN(picked)} ${weekdayCN(picked)} 上什么班",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                ShiftKind.entries.forEach { item ->
                    val def = plan.shiftDef(item)
                    val on = item == kind
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(
                                if (on) Color.fromHex(def.colorHex)
                                else MaterialTheme.colorScheme.surfaceVariant
                            )
                            .clickable {
                                kind = item
                                patternIndex = null
                            }
                            .padding(vertical = 9.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            def.name,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (on) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            if (indices.size > 1) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    indices.forEachIndexed { order, idxValue ->
                        val on = idxValue == selectedIndex
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(9.dp))
                                .background(if (on) Brand else MaterialTheme.colorScheme.surfaceVariant)
                                .clickable { patternIndex = idxValue }
                                .padding(vertical = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    "第 ${order + 1} 个${plan.shiftDef(kind).short}",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (on) Color(0xFF1A1206) else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    "循环第 ${idxValue + 1} 天",
                                    fontSize = 8.5.sp,
                                    color = if (on) Color(0xFF1A1206).copy(alpha = 0.7f)
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            Text(
                "③ 后面这样排（可逐天改）",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            AppCard(modifier = Modifier.fillMaxWidth(), padding = 8) {
                (0..6).forEach { offset ->
                    val day = picked.plusDays(offset.toLong())
                    val shown = shownKind(day)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.padding(vertical = 2.dp)
                    ) {
                        Text(
                            "${day.monthValue}/${day.dayOfMonth} ${weekdayCN(day).removePrefix("周")}",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (edits.containsKey(day.toString())) Brand
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.width(56.dp)
                        )
                        ShiftKind.entries.forEach { item ->
                            val def = plan.shiftDef(item)
                            val on = item == shown
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(7.dp))
                                    .background(
                                        if (on) {
                                            if (def.isRest) MaterialTheme.colorScheme.surfaceVariant
                                            else Color.fromHex(def.colorHex)
                                        } else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
                                    )
                                    .clickable {
                                        val key = day.toString()
                                        edits = if (item == baseKind(day)) {
                                            edits - key
                                        } else {
                                            edits + (key to item)
                                        }
                                    }
                                    .padding(vertical = 6.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    def.short,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (on && !def.isRest) Color.White
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            Text(
                if (anchor != null) "已对齐：循环起点 ${mdCN(anchor)} ${weekdayCN(anchor)}"
                else "「${plan.patternName()}」里没有「${plan.shiftDef(kind).name}」，这天会作为单日调整",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (edits.isNotEmpty()) {
                TextButton(onClick = { edits = emptyMap() }) { Text("清除逐天修改") }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brand)
                    .clickable {
                        Store.update { p ->
                            if (anchor != null) {
                                p.anchorEpochDay = anchor.toEpochDay()
                                p.overrides.remove(picked.toString())
                            } else {
                                p.overrides[picked.toString()] = kind
                            }
                            edits.forEach { (key, value) -> p.overrides[key] = value }
                        }
                        onDismiss()
                    }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("就从这天开始", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A1206))
            }
        }
    }
}

/* ------------------------------ 闹钟 ------------------------------ */

@Composable
fun AlarmsScreen(onRequestCalendar: () -> Unit) {
    val plan = Store.plan
    val context = LocalContext.current
    var calStatus by remember { mutableStateOf("") }
    var calendars by remember { mutableStateOf<List<CalOption>>(emptyList()) }
    var showPicker by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(0) }

    val upcoming = remember(plan, refreshing) { plan.upcomingAlarms(LocalDateTime.now(), 12) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column {
            Text(
                "${upcoming.size} 个待响闹钟",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text("闹钟", fontSize = 30.sp, fontWeight = FontWeight.Bold)
        }

        AppCard(modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("总开关", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        if (plan.masterOn) "按班次自动响铃" else "全部关闭",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = plan.masterOn,
                    onCheckedChange = { on -> Store.update { it.masterOn = on } }
                )
            }
        }

        val exact = Alarms.canExact(context)
        if (!exact) {
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Text("精确闹钟未授权", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.error)
                Text(
                    "去系统设置里允许「闹钟和提醒」，否则可能延迟响铃",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        AppCard(modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("试验闹钟", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        "点一下，20 秒后响 —— 用来确认三星的省电策略没拦住",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                TextButton(onClick = { Alarms.scheduleTest(context, 20) }) { Text("试一下") }
            }
        }

        AppCard(modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("写入系统日历", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        calStatus.ifBlank { "把未来 30 天班次写进你选的日历" },
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                TextButton(onClick = {
                    if (!CalendarSync.hasPermission(context)) {
                        onRequestCalendar()
                        calStatus = "已请求日历权限，请允许后再点一次"
                    } else {
                        calendars = CalendarSync.calendars(context)
                        if (calendars.isEmpty()) calStatus = "没有可写入的日历"
                        else showPicker = true
                    }
                }) { Text("选择日历") }
            }
        }

        SectionTitle("接下来的闹钟")
        AppCard(modifier = Modifier.fillMaxWidth(), padding = 8) {
            if (upcoming.isEmpty()) {
                Text(
                    "暂时没有闹钟",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(8.dp)
                )
            }
            upcoming.forEach { alarm ->
                val def = plan.shiftDef(alarm.kind)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 7.dp, horizontal = 6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(30.dp)
                            .clip(RoundedCornerShape(9.dp))
                            .background(Color.fromHex(def.colorHex)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(def.short, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "${relativeDayCN(alarm.shiftDate)} ${mdCN(alarm.shiftDate)}",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            "${def.name} ${def.startLabel} 开始",
                            fontSize = 10.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Text(
                        fmtMin(alarm.minutes),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }

    if (showPicker) {
        CalendarPickerSheet(
            calendars = calendars,
            onDismiss = { showPicker = false },
            onPick = { option ->
                val written = CalendarSync.sync(context, Store.plan, option.id, 30)
                Store.update { it.calendarId = option.id }
                calStatus = "已写入 $written 个班次到「${option.name}」"
                refreshing++
                showPicker = false
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarPickerSheet(
    calendars: List<CalOption>,
    onDismiss: () -> Unit,
    onPick: (CalOption) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 26.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("选择要写入的日历", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            calendars.forEach { option ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable { onPick(option) }
                        .padding(14.dp)
                ) {
                    Text(option.name, fontSize = 14.sp)
                }
            }
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("取消") }
        }
    }
}
