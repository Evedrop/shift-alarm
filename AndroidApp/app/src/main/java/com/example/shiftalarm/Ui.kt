package com.example.shiftalarm

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val Brand = Color(0xFFFF9F0A)
private val PageLight = Color(0xFFF2F2F7)
private val PageDark = Color(0xFF0E0E10)
val RestGrayLight = Color(0xFFE9E9EE)
val RestGrayDark = Color(0xFF2C2C2E)

private val LightScheme = lightColorScheme(
    primary = Brand,
    onPrimary = Color(0xFF1A1206),
    background = PageLight,
    surface = Color.White,
    surfaceVariant = RestGrayLight,
    onSurface = Color(0xFF111114),
    onSurfaceVariant = Color(0xFF8A8A8E)
)

private val DarkScheme = darkColorScheme(
    primary = Brand,
    onPrimary = Color(0xFF1A1206),
    background = PageDark,
    surface = Color(0xFF1C1C1E),
    surfaceVariant = RestGrayDark,
    onSurface = Color(0xFFF2F2F7),
    onSurfaceVariant = Color(0xFF9A9AA0)
)

fun Color.Companion.fromHex(hex: String): Color {
    val cleaned = hex.trimStart('#')
    val value = cleaned.toLongOrNull(16) ?: 0xD1D1D6
    return Color(
        red = ((value shr 16) and 0xFF) / 255f,
        green = ((value shr 8) and 0xFF) / 255f,
        blue = (value and 0xFF) / 255f
    )
}

@Composable
fun ShiftAlarmTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = if (dark) DarkScheme else LightScheme,
        typography = Typography(bodyMedium = Typography().bodyMedium.copy(fontSize = 15.sp)),
        content = content
    )
}

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    padding: Int = 14,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.padding(padding.dp), content = content)
    }
}

@Composable
fun SectionTitle(text: String, trailing: String? = null) {
    Column(modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp)) {
        androidx.compose.material3.Text(
            text = text,
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold
        )
    }
}
