package dev.nativesteam.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.DesktopWindows
import androidx.compose.material.icons.filled.LaptopMac
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import coil3.compose.AsyncImagePainter
import coil3.request.ImageRequest
import coil3.request.crossfade
import dev.nativesteam.android.data.Platforms
import dev.nativesteam.android.data.Price
import dev.nativesteam.android.data.ReviewSummary
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

private val Grayscale = ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(0f) })

/**
 * Async Steam CDN artwork (Coil, memory + disk cached) with a `surface` placeholder that
 * shows the game's name while loading or when the image fails.
 */
@Composable
fun SteamImage(
    url: String?,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    placeholderLabel: String? = null,
    contentScale: ContentScale = ContentScale.Crop,
    alignment: Alignment = Alignment.Center,
    placeholderColor: Color = Steam.surface,
    transparent: Boolean = false,
    grayscale: Boolean = false,
    alpha: Float = 1f,
) {
    var state by remember(url) { mutableStateOf<AsyncImagePainter.State>(AsyncImagePainter.State.Empty) }
    val loaded = state is AsyncImagePainter.State.Success
    Box(
        modifier.then(if (!transparent && !loaded) Modifier.background(placeholderColor) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        if (!loaded && placeholderLabel != null && !transparent) {
            Text(
                placeholderLabel,
                style = MaterialTheme.typography.labelMedium,
                color = Steam.textMuted,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(8.dp),
            )
        }
        if (url != null) {
            val context = LocalContext.current
            val request = remember(url) {
                ImageRequest.Builder(context).data(url).crossfade(180).build()
            }
            AsyncImage(
                model = request,
                contentDescription = contentDescription,
                contentScale = contentScale,
                alignment = alignment,
                alpha = alpha,
                colorFilter = if (grayscale) Grayscale else null,
                onState = { state = it },
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Typography helpers
// ---------------------------------------------------------------------------

/** UPPERCASE tracked section header with an optional trailing "See all ›". */
@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    count: String? = null,
    seeAllLabel: String = "See all",
    onSeeAll: (() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    Row(
        modifier.fillMaxWidth().heightIn(min = 40.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title.uppercase(), style = SteamType.sectionHeader, maxLines = 1)
        if (count != null) {
            Spacer(Modifier.width(8.dp))
            Text(count, style = SteamType.sectionHeader.copy(color = Steam.textSecondary))
        }
        Spacer(Modifier.weight(1f))
        trailing?.invoke(this)
        if (onSeeAll != null) {
            Row(
                Modifier
                    .steamFocusable(onClick = onSeeAll, corner = 4.dp, focusScale = 1f, hoverLift = false)
                    .heightIn(min = 40.dp)
                    .padding(start = 10.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(seeAllLabel, style = MaterialTheme.typography.labelLarge, color = Steam.accentLink)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Steam.accentLink, modifier = Modifier.size(18.dp))
            }
        }
    }
}

@Composable
fun Wordmark(modifier: Modifier = Modifier, fontSize: Int = 20) {
    Text("STEAM", style = SteamType.wordmark.copy(fontSize = fontSize.sp), modifier = modifier)
}

// ---------------------------------------------------------------------------
// Price & reviews
// ---------------------------------------------------------------------------

/** Steam price block: discount badge + struck original over the final price. */
@Composable
fun PriceBlock(
    price: Price?,
    modifier: Modifier = Modifier,
    comingSoonLabel: String? = null,
    large: Boolean = false,
    onArt: Boolean = false,
) {
    val plainBg = if (onArt) Color.Black.copy(alpha = 0.62f) else Steam.priceBg
    val finalSize = if (large) 16.sp else 13.sp
    val height = if (large) 44.dp else 34.dp
    if (price?.discountLabel == null) {
        Box(
            modifier
                .height(height)
                .background(plainBg, Steam.buttonShape)
                .padding(horizontal = if (large) 12.dp else 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                price?.finalLabel ?: (comingSoonLabel ?: "Coming soon"),
                fontSize = finalSize,
                color = Steam.textBody,
                maxLines = 1,
            )
        }
        return
    }
    Row(modifier.height(height), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .fillMaxHeight()
                .background(Steam.discountBg, RoundedCornerShape(topStart = 3.dp, bottomStart = 3.dp))
                .padding(horizontal = if (large) 9.dp else 6.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                price.discountLabel,
                color = Steam.discountText,
                fontWeight = FontWeight.Bold,
                fontSize = if (large) 22.sp else 15.sp,
                letterSpacing = (-0.02).em,
            )
        }
        Column(
            Modifier
                .fillMaxHeight()
                .background(plainBg, RoundedCornerShape(topEnd = 3.dp, bottomEnd = 3.dp))
                .padding(horizontal = 7.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.End,
        ) {
            Text(
                price.initialLabel,
                color = Steam.priceOriginal,
                fontSize = if (large) 12.sp else 10.sp,
                lineHeight = if (large) 13.sp else 11.sp,
                textDecoration = TextDecoration.LineThrough,
            )
            Text(
                price.finalLabel,
                color = Steam.discountText,
                fontSize = finalSize,
                lineHeight = finalSize,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
fun ReviewLabel(review: ReviewSummary?, modifier: Modifier = Modifier, showCount: Boolean = false) {
    if (review == null) {
        Text("No user reviews", style = MaterialTheme.typography.bodySmall, color = Steam.textMuted, modifier = modifier)
        return
    }
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Text(
            review.label,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = Steam.reviewColor(review.tone),
            maxLines = 1,
        )
        if (showCount) {
            Text(
                "  (${review.totalLabel})",
                style = MaterialTheme.typography.bodySmall,
                color = Steam.textSecondary,
                maxLines = 1,
            )
        }
    }
}

@Composable
fun ToneDot(tone: String?, modifier: Modifier = Modifier) {
    Box(modifier.size(8.dp).background(Steam.reviewColor(tone), CircleShape))
}

/** Green pulsing-style "live" dot used next to player counts. */
@Composable
fun LiveDot(modifier: Modifier = Modifier) {
    Box(modifier.size(8.dp).background(Steam.statusInGame, CircleShape))
}

@Composable
fun PlatformIcons(platforms: Platforms, modifier: Modifier = Modifier, tint: Color = Steam.textSecondary) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        if (platforms.windows) Icon(Icons.Filled.DesktopWindows, "Windows", tint = tint, modifier = Modifier.size(14.dp))
        if (platforms.mac) Icon(Icons.Filled.LaptopMac, "macOS", tint = tint, modifier = Modifier.size(14.dp))
        if (platforms.linux) Icon(Icons.Filled.Terminal, "Linux / SteamOS", tint = tint, modifier = Modifier.size(14.dp))
    }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

/** Big gradient action (PLAY / INSTALL / Add to Cart). Purely visual. */
@Composable
fun GradientButton(
    text: String,
    brush: Brush,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    height: Dp = 48.dp,
    focusRequester: androidx.compose.ui.focus.FocusRequester? = null,
    onSecondary: (() -> Unit)? = null,
) {
    Row(
        modifier
            .steamFocusable(onClick = onClick, corner = 4.dp, focusScale = 1.04f, focusRequester = focusRequester, onSecondary = onSecondary)
            .background(brush)
            .height(height)
            .padding(horizontal = 22.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(26.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
            letterSpacing = 0.06.em,
            maxLines = 1,
        )
    }
}

/** Secondary flat button on a translucent surface. */
@Composable
fun SecondaryButton(
    text: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconTint: Color = Steam.textBody,
    height: Dp = 48.dp,
    contentDescription: String? = text,
    onSecondary: (() -> Unit)? = null,
) {
    Row(
        modifier
            .steamFocusable(onClick = onClick, corner = 4.dp, onSecondary = onSecondary)
            .background(Color.White.copy(alpha = 0.09f))
            .height(height)
            .padding(horizontal = if (text == null) 12.dp else 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription, tint = iconTint, modifier = Modifier.size(22.dp))
            if (text != null) Spacer(Modifier.width(8.dp))
        }
        if (text != null) {
            Text(text, color = Steam.textBody, style = MaterialTheme.typography.labelLarge, maxLines = 1)
        }
    }
}

/** Fully rounded tag chip. */
@Composable
fun SteamChip(
    label: String,
    selected: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    trailing: String? = null,
    focusRequester: androidx.compose.ui.focus.FocusRequester? = null,
) {
    Row(
        modifier
            .steamFocusable(onClick = onClick, corner = 20.dp, focusScale = 1.06f, focusRequester = focusRequester, role = androidx.compose.ui.semantics.Role.Tab)
            .background(if (selected) Steam.accent else Color.White.copy(alpha = 0.08f))
            .height(36.dp)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            color = if (selected) Color.White else Steam.textBody,
            maxLines = 1,
        )
        if (trailing != null) {
            Spacer(Modifier.width(6.dp))
            Text(
                trailing,
                style = MaterialTheme.typography.labelMedium,
                color = if (selected) Color.White.copy(alpha = 0.8f) else Steam.textSecondary,
            )
        }
    }
}

/** Small non-interactive pill (genres, controller support). */
@Composable
fun InfoPill(text: String, modifier: Modifier = Modifier, color: Color = Steam.accentLink, background: Color = Steam.accentLink.copy(alpha = 0.12f)) {
    Box(
        modifier.background(background, Steam.buttonShape).padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelMedium, color = color, maxLines = 1)
    }
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

/** Square Steam avatar with a status-coloured border. */
@Composable
fun Avatar(
    url: String?,
    size: Dp,
    modifier: Modifier = Modifier,
    status: String? = null,
    borderWidth: Dp = 2.dp,
    contentDescription: String? = null,
) {
    val shape = RoundedCornerShape(if (size >= 64.dp) 6.dp else 4.dp)
    Box(
        modifier
            .size(size)
            .then(if (status != null) Modifier.border(borderWidth, Steam.statusColor(status), shape) else Modifier)
            .padding(if (status != null) borderWidth + 1.dp else 0.dp)
            .clip(shape),
    ) {
        SteamImage(url, Modifier.fillMaxSize(), contentDescription = contentDescription, placeholderColor = Steam.surfaceNeutral)
    }
}

/** Steam level ring: circle outlined in the level colour with the number inside. */
@Composable
fun LevelRing(level: Int, colorHex: String, modifier: Modifier = Modifier, size: Dp = 40.dp) {
    val color = Steam.parseHex(colorHex)
    Box(
        modifier
            .size(size)
            .border(if (size > 44.dp) 3.dp else 2.dp, color, CircleShape)
            .background(Color.Black.copy(alpha = 0.25f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            level.toString(),
            color = Steam.textTitle,
            fontWeight = FontWeight.SemiBold,
            fontSize = if (size > 44.dp) 18.sp else 14.sp,
        )
    }
}

/** Thin progress bar (achievements, XP). */
@Composable
fun ProgressLine(
    fraction: Float,
    modifier: Modifier = Modifier,
    color: Color = Steam.accent,
    track: Color = Color.White.copy(alpha = 0.1f),
    height: Dp = 4.dp,
) {
    Canvas(modifier.fillMaxWidth().height(height)) {
        val y = size.height / 2f
        drawLine(track, Offset(0f, y), Offset(size.width, y), strokeWidth = size.height, cap = StrokeCap.Round)
        val f = fraction.coerceIn(0f, 1f)
        if (f > 0f) {
            drawLine(color, Offset(0f, y), Offset(size.width * f, y), strokeWidth = size.height, cap = StrokeCap.Round)
        }
    }
}

/** Circular progress (badges / achievements). */
@Composable
fun RingProgress(fraction: Float, color: Color, modifier: Modifier = Modifier, stroke: Dp = 3.dp) {
    Canvas(modifier) {
        val s = stroke.toPx()
        drawArc(Color.White.copy(alpha = 0.1f), 0f, 360f, false, style = Stroke(s), topLeft = Offset(s / 2, s / 2), size = androidx.compose.ui.geometry.Size(size.width - s, size.height - s))
        drawArc(color, -90f, 360f * fraction.coerceIn(0f, 1f), false, style = Stroke(s, cap = StrokeCap.Round), topLeft = Offset(s / 2, s / 2), size = androidx.compose.ui.geometry.Size(size.width - s, size.height - s))
    }
}

// ---------------------------------------------------------------------------
// Shelves
// ---------------------------------------------------------------------------

/**
 * Horizontal shelf: snaps to card starts on fling (touch) and keeps the focused card in view
 * with a card of lookahead (keyboard / gamepad). Vertical padding leaves room for the focus glow.
 */
@Composable
fun Shelf(
    modifier: Modifier = Modifier,
    gutter: Dp = 16.dp,
    spacing: Dp = 12.dp,
    state: LazyListState = rememberLazyListState(),
    content: LazyListScope.() -> Unit,
) {
    val spec = remember { ShelfBringIntoViewSpec() }
    CompositionLocalProvider(LocalBringIntoViewSpec provides spec) {
        LazyRow(
            modifier = modifier.fillMaxWidth(),
            state = state,
            contentPadding = PaddingValues(horizontal = gutter, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(spacing),
            flingBehavior = rememberSnapFlingBehavior(state, SnapPosition.Start),
            content = content,
        )
    }
}

/** Bottom-up scrim for text over artwork. */
val BottomScrim = Brush.verticalGradient(
    0f to Color.Transparent,
    0.45f to Color.Black.copy(alpha = 0.15f),
    1f to Color.Black.copy(alpha = 0.85f),
)

@Composable
fun StatBlock(value: String, caption: String, modifier: Modifier = Modifier, valueColor: Color = Steam.textTitle) {
    Column(modifier) {
        Text(caption.uppercase(), style = SteamType.caption)
        Spacer(Modifier.height(2.dp))
        Text(value, color = valueColor, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
fun Hairline(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(1.dp).background(Steam.divider))
}
