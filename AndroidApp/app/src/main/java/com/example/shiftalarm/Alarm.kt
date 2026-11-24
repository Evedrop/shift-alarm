package com.example.shiftalarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.time.LocalDateTime
import java.time.ZoneId

object Alarms {
    const val CHANNEL_ID = "shift_alarm"
    const val ACTION_ALARM = "com.example.shiftalarm.ALARM"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    private const val PREF_SCHEDULED = "scheduled_ids"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(NotificationManager::class.java) ?: return
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "班次闹钟",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "班次开始前的提醒"
                    enableVibration(true)
                    enableLights(true)
                    setSound(
                        sound,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                }
                mgr.createNotificationChannel(channel)
            }
        }
    }

    fun canExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val mgr = context.getSystemService(AlarmManager::class.java) ?: return false
        return mgr.canScheduleExactAlarms()
    }

    private fun pendingIntent(context: Context, id: String, alarm: PlannedAlarm?): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_ALARM
            data = Uri.parse("shiftalarm://alarm/$id")
            if (alarm != null) {
                putExtra(EXTRA_TITLE, alarmTitle(Store.plan, alarm))
                putExtra(EXTRA_BODY, alarmBody(Store.plan, alarm))
            }
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun alarmTitle(plan: Plan, alarm: PlannedAlarm): String {
        val def = plan.shiftDef(alarm.kind)
        return "${def.name} ${def.rangeText}"
    }

    fun alarmBody(plan: Plan, alarm: PlannedAlarm): String {
        val def = plan.shiftDef(alarm.kind)
        return "${mdCN(alarm.shiftDate)} ${weekdayCN(alarm.shiftDate)} · ${fmtMin(alarm.minutes)} 响铃（提前 ${def.leadMinutes} 分钟）"
    }

    /** 按当前排班重建未来 20 个闹钟 */
    fun reschedule(context: Context, plan: Plan) {
        ensureChannel(context)
        val prefs = context.getSharedPreferences("shiftalarm", Context.MODE_PRIVATE)
        val old = prefs.getStringSet(PREF_SCHEDULED, emptySet()) ?: emptySet()

        val mgr = context.getSystemService(AlarmManager::class.java) ?: return
        old.forEach { id ->
            runCatching { mgr.cancel(pendingIntent(context, id, null)) }
        }

        val upcoming = plan.upcomingAlarms(LocalDateTime.now(), 20)
        val ids = mutableSetOf<String>()
        upcoming.forEach { alarm ->
            val pi = pendingIntent(context, alarm.id, alarm)
            runCatching {
                if (canExact(context)) {
                    mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerAt, pi)
                } else {
                    mgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerAt, pi)
                }
                ids += alarm.id
            }
        }
        prefs.edit().putStringSet(PREF_SCHEDULED, ids).apply()
    }

    /** 试验闹钟：seconds 秒后响一次 */
    fun scheduleTest(context: Context, seconds: Long) {
        ensureChannel(context)
        val mgr = context.getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = System.currentTimeMillis() + seconds * 1000
        val pi = PendingIntent.getBroadcast(
            context,
            999_999,
            Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_ALARM
                data = Uri.parse("shiftalarm://alarm/test")
                putExtra(EXTRA_TITLE, "试验闹钟")
                putExtra(EXTRA_BODY, "如果现在响了，说明闹钟没问题")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        runCatching {
            if (canExact(context)) {
                mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                mgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Alarms.ACTION_ALARM) return
        val title = intent.getStringExtra(Alarms.EXTRA_TITLE) ?: "班表闹钟"
        val body = intent.getStringExtra(Alarms.EXTRA_BODY) ?: ""
        Alarms.ensureChannel(context)

        val full = Intent(context, AlarmActivity::class.java).apply {
            putExtra(Alarms.EXTRA_TITLE, title)
            putExtra(Alarms.EXTRA_BODY, body)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context,
            1,
            full,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, Alarms.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pi, true)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setOngoing(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(context)
                .notify(intent.data?.hashCode() ?: 42, notification)
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Store.init(context)
        Alarms.reschedule(context, Store.plan)
    }
}

class AlarmActivity : ComponentActivity() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)

        val title = intent.getStringExtra(Alarms.EXTRA_TITLE) ?: "班表闹钟"
        val body = intent.getStringExtra(Alarms.EXTRA_BODY) ?: ""

        startSound()
        startVibration()
        NotificationManagerCompat.from(this).cancelAll()

        setContent {
            AlarmScreen(
                title = title,
                body = body,
                onStop = { stopEverything() }
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseSound()
        vibrator?.cancel()
    }

    private fun startSound() {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        runCatching {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmActivity, uri)
                isLooping = true
                prepare()
                start()
            }
        }
    }

    private fun releaseSound() {
        runCatching {
            player?.stop()
            player?.release()
        }
        player = null
    }

    private fun startVibration() {
        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as? Vibrator
        }
        vibrator = v
        val pattern = longArrayOf(0, 700, 600, 700, 600, 700)
        runCatching {
            v?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        }
    }

    private fun stopEverything() {
        releaseSound()
        vibrator?.cancel()
        finish()
    }
}

@Composable
private fun AlarmScreen(title: String, body: String, onStop: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF14100A)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(28.dp)
        ) {
            Text("闹钟", color = Brand, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Text(
                title,
                color = Color.White,
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                body,
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
            Button(
                onClick = onStop,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 26.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Brand, contentColor = Color(0xFF1A1206)),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp)
            ) {
                Text("停止", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

fun nowMillis(): Long = System.currentTimeMillis()

fun millisToLocal(millis: Long): LocalDateTime =
    LocalDateTime.ofInstant(java.time.Instant.ofEpochMilli(millis), ZoneId.systemDefault())
