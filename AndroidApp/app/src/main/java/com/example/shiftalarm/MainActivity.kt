package com.example.shiftalarm

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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

class MainActivity : ComponentActivity() {
    private val notificationLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { }

    private var calendarRequest: (() -> Unit)? = null

    private val calendarLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Store.init(this)
        Alarms.ensureChannel(this)
        Alarms.reschedule(this, Store.plan)
        requestNotifications()

        calendarRequest = {
            calendarLauncher.launch(
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
            )
        }

        setContent {
            ShiftAlarmTheme {
                AppRoot(onRequestCalendar = { calendarRequest?.invoke() })
            }
        }
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        notificationLauncher.launch(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
    }
}

@Composable
fun AppRoot(onRequestCalendar: () -> Unit = {}) {
    var tab by remember { mutableIntStateOf(0) }
    val plan = Store.plan
    val context = LocalContext.current

    LaunchedEffect(plan) {
        Alarms.reschedule(context, plan)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == 0,
                    onClick = { tab = 0 },
                    icon = { Icon(Icons.Filled.CalendarMonth, contentDescription = null) },
                    label = { Text("班表") }
                )
                NavigationBarItem(
                    selected = tab == 1,
                    onClick = { tab = 1 },
                    icon = { Icon(Icons.Filled.Groups, contentDescription = null) },
                    label = { Text("班组") }
                )
                NavigationBarItem(
                    selected = tab == 2,
                    onClick = { tab = 2 },
                    icon = { Icon(Icons.Filled.Tune, contentDescription = null) },
                    label = { Text("规律") }
                )
                NavigationBarItem(
                    selected = tab == 3,
                    onClick = { tab = 3 },
                    icon = { Icon(Icons.Filled.Alarm, contentDescription = null) },
                    label = { Text("闹钟") }
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when (tab) {
                0 -> ScheduleScreen()
                1 -> CrewsScreen()
                2 -> RulesScreen()
                else -> AlarmsScreen(onRequestCalendar)
            }
        }
    }
}

@Composable
fun ScheduleScreen() {
    val plan = Store.plan
    val today = LocalDate.now()
    var month by remember { mutableStateOf(YearMonth.from(today)) }
    var sheetDate by remember { mutableStateOf<LocalDate?>(null) }
    var showSettings by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${plan.crewName(plan.myCrew)} · ${mdCN(today)} ${weekdayCN(today)}",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text("班表", fontSize = 30.sp, fontWeight = FontWeight.Bold)
            }
            TextButton(onClick = { month = YearMonth.from(today) }) { Text("今天") }
            Icon(
                imageVector = Icons.Filled.Settings,
                contentDescription = "设置",
                modifier = Modifier
                    .size(28.dp)
                    .clickable { showSettings = true }
            )
        }

        NextAlarmHero(plan)

        MonthCard(
            plan = plan,
            month = month,
            today = today,
            onMonthChange = { month = month.plusMonths(it.toLong()) },
            onPick = { date -> sheetDate = date }
        )

        StatsRow(plan, month)
        Spacer(Modifier.height(8.dp))
    }

    sheetDate?.let { date ->
        DaySheet(date = date, onDismiss = { sheetDate = null })
    }
    if (showSettings) {
        SettingsSheet(onDismiss = { showSettings = false })
    }
}

@Composable
private fun NextAlarmHero(plan: Plan) {
    val next = plan.upcomingAlarms(LocalDateTime.now(), 1).firstOrNull()
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "下一个闹钟",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(2.dp))
                if (next != null) {
                    Text(
                        fmtMin(next.minutes),
                        fontSize = 40.sp,
                        fontWeight = FontWeight.Bold
                    )
                    val def = plan.shiftDef(next.kind)
                    Text(
                        "${relativeDayCN(next.shiftDate)} ${weekdayCN(next.shiftDate)} · ${def.name} ${def.startLabel} 开始",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    Text("没有安排", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Text(
                        if (plan.masterOn) "休息日不设闹钟" else "总开关已关闭",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            if (next != null) {
                val def = plan.shiftDef(next.kind)
                Box(
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(Color.fromHex(def.colorHex)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(def.short, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                }
            }
        }
    }
}

@Composable
private fun MonthCard(
    plan: Plan,
    month: YearMonth,
    today: LocalDate,
    onPick: (LocalDate) -> Unit,
    onMonthChange: (Int) -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth(), padding = 12) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "${month.year}年${month.monthValue}月",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            Text(plan.patternName(), fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Icon(
                Icons.Filled.ChevronLeft,
                contentDescription = "上月",
                modifier = Modifier
                    .padding(start = 6.dp)
                    .size(22.dp)
                    .clickable { onMonthChange(-1) }
            )
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = "下月",
                modifier = Modifier
                    .size(22.dp)
                    .clickable { onMonthChange(1) }
            )
        }

        Spacer(Modifier.height(8.dp))
        Row {
            listOf("一", "二", "三", "四", "五", "六", "日").forEach { label ->
                Text(
                    label,
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        val first = month.atDay(1)
        val lead = (first.dayOfWeek.value + 6) % 7
        val days = month.lengthOfMonth()
        val cells = lead + days
        val rows = (cells + 6) / 7

        for (r in 0 until rows) {
            Row(modifier = Modifier.fillMaxWidth()) {
                for (c in 0..6) {
                    val dayNumber = r * 7 + c - lead + 1
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        if (dayNumber in 1..days) {
                            val date = month.atDay(dayNumber)
                            DayCell(date, plan, date == today) { onPick(date) }
                        } else {
                            Spacer(Modifier.height(46.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(date: LocalDate, plan: Plan, isToday: Boolean, onClick: () -> Unit) {
    val kind = plan.shift(date)
    val def = plan.shiftDef(kind)
    val overridden = plan.isOverridden(date)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(vertical = 3.dp, horizontal = 2.dp)
    ) {
        Text(
            "${date.dayOfMonth}",
            fontSize = 13.sp,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = if (isToday) Brand else MaterialTheme.colorScheme.onSurface
        )
        Box(
            modifier = Modifier
                .padding(top = 1.dp)
                .size(24.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(if (def.isRest) MaterialTheme.colorScheme.surfaceVariant else Color.fromHex(def.colorHex))
                ,
            contentAlignment = Alignment.Center
        ) {
            Text(
                def.short,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = if (def.isRest) MaterialTheme.colorScheme.onSurfaceVariant else Color.White
            )
        }
    }
}

@Composable
private fun StatsRow(plan: Plan, month: YearMonth) {
    var work = 0
    var rest = 0
    for (d in 1..month.lengthOfMonth()) {
        val def = plan.shiftDef(plan.shift(month.atDay(d)))
        if (def.isRest) rest++ else work++
    }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        AppCard(modifier = Modifier.weight(1f)) {
            Text("出勤", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("$work 天", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        AppCard(modifier = Modifier.weight(1f)) {
            Text("休息", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("$rest 天", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        AppCard(modifier = Modifier.weight(1f)) {
            Text("班组", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(plan.crewName(plan.myCrew), fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DaySheet(date: LocalDate, onDismiss: () -> Unit) {
    val plan = Store.plan
    var current by remember { mutableStateOf(date) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(
                    Icons.Filled.ChevronLeft,
                    contentDescription = "前一天",
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .clickable { current = current.minusDays(1L) }
                )
                Text(
                    "${mdCN(current)} ${weekdayCN(current)}",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = "后一天",
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .clickable { current = current.plusDays(1L) }
                )
            }

            val kind = plan.shift(current)
            val def = plan.shiftDef(kind)

            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                ShiftKind.entries.forEach { item ->
                    val itemDef = plan.shiftDef(item)
                    val on = item == kind
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(9.dp))
                            .background(
                                if (on) Color.fromHex(itemDef.colorHex)
                                else MaterialTheme.colorScheme.surfaceVariant
                            )
                            .clickable {
                                Store.update { it.overrides[current.toString()] = item }
                            }
                            .padding(vertical = 9.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            itemDef.name,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (on) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            AppCard(modifier = Modifier.fillMaxWidth()) {
                InfoRow("班次时间", def.rangeText)
                InfoRow("闹钟时间", plan.alarmDateTime(current)?.let {
                    fmtMin(it.hour * 60 + it.minute)
                } ?: "—")
                InfoRow("提前提醒", if (def.isRest) "—" else "${def.leadMinutes} 分钟")
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("该日闹钟", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        when {
                            def.isRest -> "休息日不设闹钟"
                            !plan.masterOn -> "总开关已关闭"
                            plan.alarmOff.contains(current.toString()) -> "已关闭"
                            else -> "会响铃并全屏提醒"
                        },
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = !plan.alarmOff.contains(current.toString()),
                    enabled = !def.isRest && plan.masterOn,
                    onCheckedChange = {
                        Store.update { p ->
                            val key = current.toString()
                            if (p.alarmOff.contains(key)) p.alarmOff.remove(key) else p.alarmOff.add(key)
                        }
                    }
                )
            }

            if (plan.isOverridden(current)) {
                TextButton(onClick = {
                    Store.update { it.overrides.remove(current.toString()) }
                }) {
                    Text("恢复为循环规律", color = MaterialTheme.colorScheme.error)
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brand)
                    .clickable { onDismiss() }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("完成", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A1206))
            }
        }
    }
}

@Composable
fun InfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
        Text(label, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(onDismiss: () -> Unit) {
    val plan = Store.plan
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text("班次时间", fontSize = 18.sp, fontWeight = FontWeight.Bold)

            ShiftKind.entries.filter { !plan.shiftDef(it).isRest }.forEach { kind ->
                val def = plan.shiftDef(kind)
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(Color.fromHex(def.colorHex))
                        )
                        Spacer(Modifier.width(8.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(def.name, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            Text(def.rangeText, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        TextButton(onClick = {
                            Store.update { p ->
                                p.shifts = p.shifts.map {
                                    if (it.kind == kind) it.copy(startMinute = (it.startMinute + 60) % 1440)
                                    else it
                                }
                            }
                        }) { Text("+1 小时") }
                        TextButton(onClick = {
                            Store.update { p ->
                                p.shifts = p.shifts.map {
                                    if (it.kind == kind) it.copy(leadMinutes = (it.leadMinutes + 15) % 120)
                                    else it
                                }
                            }
                        }) { Text("提前 ${def.leadMinutes} 分") }
                    }
                }
            }

            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                Text("完成")
            }
        }
    }
}
