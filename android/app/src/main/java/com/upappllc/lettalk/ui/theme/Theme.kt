package com.upappllc.lettalk.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/** Let Talk brand colors, matched to the iPhone app. */
object LT {
    val Blue = Color(0xFF2F7CF6)
    val Green = Color(0xFF34C759)
    val Red = Color(0xFFFF3B30)
    val Orange = Color(0xFFFF9500)
    val Purple = Color(0xFF8E44D9)

    /** Sign-in / sign-up background: blue -> purple -> plum, like the iPhone app. */
    val AuthGradient = Brush.linearGradient(
        listOf(Color(0xFF4A72E0), Color(0xFF8A2FC4), Color(0xFF7A2A6E))
    )

    /** Call screen background: deep blue at the top fading to amber at the bottom. */
    val CallGradient = Brush.verticalGradient(
        listOf(Color(0xFF1F4C8C), Color(0xFF0E1A33), Color(0xFF8A5A12), Color(0xFF6E2A12))
    )

    /** Avatar colors, picked from the person's name so each contact keeps the same color. */
    val AvatarColors = listOf(
        Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
        Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF06B6D4)
    )

    fun avatarColor(name: String): Color =
        AvatarColors[(name.hashCode() and 0x7fffffff) % AvatarColors.size]
}

private val Light = lightColorScheme(
    primary = LT.Blue,
    secondary = LT.Purple,
    background = Color(0xFFF2F2F7),
    surface = Color.White,
    surfaceVariant = Color(0xFFE9E9EF),
)

private val Dark = darkColorScheme(
    primary = Color(0xFF4C8DF8),
    secondary = Color(0xFFB07CF0),
    background = Color(0xFF000000),
    surface = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFF2C2C2E),
)

@Composable
fun LetTalkTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) Dark else Light,
        content = content
    )
}
