package dev.nativesteam.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/** Brand tokens from docs/DESIGN.md §1. */
object Steam {
    val bgChrome = Color(0xFF171A21)
    val bgStoreTop = Color(0xFF1B2838)
    val bgStoreBottom = Color(0xFF0E1620)
    val bgLibraryTop = Color(0xFF1E2329)
    val bgLibraryBottom = Color(0xFF0E1014)
    val surface = Color(0xFF16202D)
    val surfaceNeutral = Color(0xFF23262E)
    val surfaceHover = Color(0xFF2A475E)
    val divider = Color.White.copy(alpha = 0.08f)
    val textTitle = Color(0xFFFFFFFF)
    val textBody = Color(0xFFC7D5E0)
    val textSecondary = Color(0xFF8F98A0)
    val textMuted = Color(0xFF67707B)
    val accent = Color(0xFF1A9FFF)
    val accentLink = Color(0xFF66C0F4)
    val playTop = Color(0xFF75B022)
    val playBottom = Color(0xFF588A1B)
    val installTop = Color(0xFF47BFFF)
    val installBottom = Color(0xFF1A44C2)
    val discountBg = Color(0xFF4C6B22)
    val discountText = Color(0xFFBEEE11)
    val priceBg = Color.Black.copy(alpha = 0.25f)
    val priceOriginal = Color(0xFF738895)
    val reviewPositive = Color(0xFF66C0F4)
    val reviewMixed = Color(0xFFB9A074)
    val reviewNegative = Color(0xFFA34C25)
    val statusInGame = Color(0xFF90BA3C)
    val statusOnline = Color(0xFF57CBDE)
    val statusAway = Color(0xFF57CBDE).copy(alpha = 0.5f)
    val statusOffline = Color(0xFF898989)

    val storeBackground = Brush.verticalGradient(listOf(bgStoreTop, bgStoreBottom))
    val libraryBackground = Brush.verticalGradient(listOf(bgLibraryTop, bgLibraryBottom))
    val playGradient = Brush.verticalGradient(listOf(playTop, playBottom))
    val installGradient = Brush.horizontalGradient(listOf(installTop, installBottom))

    val cardShape = RoundedCornerShape(6.dp)
    val buttonShape = RoundedCornerShape(4.dp)
    val avatarShape = RoundedCornerShape(4.dp)
    val pillShape = RoundedCornerShape(percent = 50)

    fun reviewColor(tone: String?): Color = when (tone) {
        "positive" -> reviewPositive
        "mixed" -> reviewMixed
        "negative" -> reviewNegative
        else -> textSecondary
    }

    fun statusColor(status: String?): Color = when (status) {
        "inGame" -> statusInGame
        "online" -> statusOnline
        "away" -> statusAway
        else -> statusOffline
    }

    fun parseHex(hex: String?, fallback: Color = accent): Color = runCatching {
        Color(android.graphics.Color.parseColor(hex))
    }.getOrDefault(fallback)
}

/** Steam's voice: tracked uppercase headers and tab labels on top of the platform font. */
object SteamType {
    val sectionHeader = TextStyle(
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.07.em,
        color = Steam.textTitle.copy(alpha = 0.9f),
    )
    val tabLabel = TextStyle(
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.08.em,
    )
    val wordmark = TextStyle(
        fontSize = 20.sp,
        fontWeight = FontWeight.Black,
        letterSpacing = 0.18.em,
        color = Steam.textTitle,
    )
    val caption = TextStyle(
        fontSize = 10.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.08.em,
        color = Steam.textSecondary,
    )
}

private val SteamColors = darkColorScheme(
    primary = Steam.accent,
    onPrimary = Color.White,
    primaryContainer = Steam.surfaceHover,
    onPrimaryContainer = Steam.textTitle,
    secondary = Steam.accentLink,
    onSecondary = Steam.bgChrome,
    secondaryContainer = Steam.accent.copy(alpha = 0.22f),
    onSecondaryContainer = Steam.textTitle,
    tertiary = Steam.statusInGame,
    background = Steam.bgStoreTop,
    onBackground = Steam.textBody,
    surface = Steam.bgChrome,
    onSurface = Steam.textBody,
    surfaceVariant = Steam.surfaceNeutral,
    onSurfaceVariant = Steam.textSecondary,
    surfaceContainerLowest = Steam.bgStoreBottom,
    surfaceContainerLow = Steam.surface,
    surfaceContainer = Steam.bgChrome,
    surfaceContainerHigh = Steam.surfaceNeutral,
    surfaceContainerHighest = Steam.surfaceHover,
    inverseSurface = Steam.textBody,
    inverseOnSurface = Steam.bgChrome,
    outline = Color.White.copy(alpha = 0.16f),
    outlineVariant = Steam.divider,
    error = Color(0xFFE5534B),
    scrim = Color.Black,
)

private val base = Typography()
private val Roboto = FontFamily.Default

private val SteamTypography = Typography(
    displaySmall = base.displaySmall.copy(fontFamily = Roboto, fontWeight = FontWeight.Bold, color = Steam.textTitle),
    headlineLarge = base.headlineLarge.copy(fontWeight = FontWeight.Bold, letterSpacing = (-0.01).em),
    headlineMedium = base.headlineMedium.copy(fontWeight = FontWeight.Bold, letterSpacing = (-0.01).em),
    headlineSmall = base.headlineSmall.copy(fontWeight = FontWeight.SemiBold),
    titleLarge = base.titleLarge.copy(fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 16.sp),
    titleSmall = base.titleSmall.copy(fontWeight = FontWeight.SemiBold),
    bodyLarge = base.bodyLarge.copy(lineHeight = 24.sp),
    bodyMedium = base.bodyMedium.copy(lineHeight = 20.sp),
    bodySmall = base.bodySmall,
    labelLarge = base.labelLarge.copy(fontWeight = FontWeight.SemiBold, letterSpacing = 0.04.em),
    labelMedium = base.labelMedium.copy(fontWeight = FontWeight.Medium),
    labelSmall = base.labelSmall.copy(fontWeight = FontWeight.Medium),
)

private val SteamShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(4.dp),
    medium = RoundedCornerShape(6.dp),
    large = RoundedCornerShape(8.dp),
    extraLarge = RoundedCornerShape(12.dp),
)

@Composable
fun NativeSteamTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = SteamColors,
        typography = SteamTypography,
        shapes = SteamShapes,
        content = content,
    )
}
