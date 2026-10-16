package dev.nativesteam.android.ui.store

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.outlined.AddShoppingCart
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.automirrored.outlined.LibraryBooks
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import dev.nativesteam.android.data.StoreItem
import dev.nativesteam.android.ui.components.CollapsedDetailBar
import dev.nativesteam.android.ui.components.DetailBackButton
import dev.nativesteam.android.ui.components.GradientButton
import dev.nativesteam.android.ui.components.InfoPill
import dev.nativesteam.android.ui.components.PlatformIcons
import dev.nativesteam.android.ui.components.PriceBlock
import dev.nativesteam.android.ui.components.SecondaryButton
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.Shelf
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.components.statusBarHeight
import dev.nativesteam.android.ui.components.fadeOutBottom
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.theme.Steam

@Composable
fun StoreAppScreen(appId: Int) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val item = remember(appId) { app.index.storeItem(appId) }
    if (item == null) {
        Box(Modifier.fillMaxSize().background(Steam.storeBackground), contentAlignment = Alignment.Center) {
            Text("This app isn't in the snapshot.", color = Steam.textSecondary)
            DetailBackButton(onBack = { nav.back() })
        }
        return
    }
    StoreAppContent(item)
}

@Composable
private fun StoreAppContent(item: StoreItem) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val scroll = rememberScrollState()
    val primaryFocus = remember { FocusRequester() }
    InitialFocus(primaryFocus)
    val density = LocalDensity.current
    val heroHeight = if (shell.compact) 300.dp else 380.dp
    val collapseRange = with(density) { (heroHeight - 120.dp).toPx() }
    val gutter = shell.gutter

    Box(Modifier.fillMaxSize().background(Steam.storeBackground)) {
        // Backdrop: store page background art (or the library hero), fading into the page.
        val backdrop = item.images.background ?: item.images.hero ?: item.images.capsule
        Box(
            Modifier
                .fillMaxWidth()
                .height(heroHeight)
                .graphicsLayer { translationY = -scroll.value * 0.4f },
        ) {
            Box(Modifier.fillMaxSize().fadeOutBottom(0.35f)) {
                SteamImage(backdrop, Modifier.fillMaxSize(), transparent = true)
                Box(
                    Modifier.fillMaxSize().background(
                        Brush.verticalGradient(
                            0f to Steam.bgStoreTop.copy(alpha = 0.2f),
                            1f to Steam.bgStoreTop.copy(alpha = 0.6f),
                        ),
                    ),
                )
            }
        }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scroll)
                .padding(bottom = shell.bottomInset + 32.dp),
        ) {
            Spacer(Modifier.height(if (shell.compact) statusBarHeight() + 68.dp else 56.dp))
            if (shell.compact) {
                CompactAppBody(item, primaryFocus)
            } else {
                WideAppBody(item, primaryFocus)
            }
        }

        CollapsedDetailBar(item.name, { (scroll.value / collapseRange).coerceIn(0f, 1f) }) { nav.back() }
        DetailBackButton(onBack = { nav.back() })
    }
}


@Composable
private fun CompactAppBody(item: StoreItem, primaryFocus: FocusRequester) {
    val gutter = 16.dp
    Column {
        Column(Modifier.padding(horizontal = gutter)) {
            SteamImage(
                item.images.header,
                Modifier.fillMaxWidth().aspectRatio(460f / 215f).clip(RoundedCornerShape(6.dp)),
                placeholderLabel = item.name,
            )
            Spacer(Modifier.height(14.dp))
            Text(item.name, style = MaterialTheme.typography.headlineSmall, color = Steam.textTitle)
            Spacer(Modifier.height(6.dp))
            ReviewSummaryLine(item)
        }
        Spacer(Modifier.height(16.dp))
        PurchaseBox(item, primaryFocus, Modifier.padding(horizontal = gutter))
        Spacer(Modifier.height(20.dp))
        Screenshots(item)
        Column(Modifier.padding(horizontal = gutter)) {
            Spacer(Modifier.height(12.dp))
            item.shortDescription?.let {
                Text(it, style = MaterialTheme.typography.bodyLarge, color = Steam.textBody)
                Spacer(Modifier.height(18.dp))
            }
            AppFacts(item)
        }
    }
}

@Composable
private fun WideAppBody(item: StoreItem, primaryFocus: FocusRequester) {
    val gutter = LocalShell.current.gutter
    Column(Modifier.padding(horizontal = gutter).widthIn(max = 1240.dp)) {
        Text(item.name, style = MaterialTheme.typography.headlineLarge, color = Steam.textTitle)
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            // Left ~62%: screenshot viewer.
            Column(Modifier.weight(0.62f)) {
                ScreenshotViewer(item)
            }
            // Right ~38%: header capsule + summary.
            Column(Modifier.weight(0.38f)) {
                SteamImage(
                    item.images.header,
                    Modifier.fillMaxWidth().aspectRatio(460f / 215f).clip(RoundedCornerShape(4.dp)),
                    placeholderLabel = item.name,
                )
                Spacer(Modifier.height(12.dp))
                item.shortDescription?.let {
                    Text(it, style = MaterialTheme.typography.bodyMedium, color = Steam.textBody, maxLines = 6)
                    Spacer(Modifier.height(14.dp))
                }
                ReviewSummaryLine(item)
                Spacer(Modifier.height(14.dp))
                AppFacts(item)
            }
        }
        Spacer(Modifier.height(24.dp))
        PurchaseBox(item, primaryFocus, Modifier.widthIn(max = 760.dp))
    }
}

@Composable
private fun ReviewSummaryLine(item: StoreItem) {
    val review = item.review
    if (review == null) {
        Text("No user reviews yet", style = MaterialTheme.typography.bodyMedium, color = Steam.textSecondary)
        return
    }
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(color = Steam.textSecondary, fontWeight = FontWeight.Medium)) { append("ALL REVIEWS  ") }
            withStyle(SpanStyle(color = Steam.reviewColor(review.tone), fontWeight = FontWeight.SemiBold)) { append(review.label) }
            withStyle(SpanStyle(color = Steam.textSecondary)) { append("  ${review.percentPositive}% · ${review.totalLabel}") }
        },
        style = MaterialTheme.typography.bodyMedium,
    )
}

@Composable
private fun AppFacts(item: StoreItem) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Fact("Release date", item.releaseDate ?: "To be announced")
        if (item.developers.isNotEmpty()) Fact("Developer", item.developers.joinToString(", "), link = true)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("PLATFORMS", style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, modifier = Modifier.width(104.dp))
            PlatformIcons(item.platforms, tint = Steam.textBody)
        }
        if (item.genres.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                item.genres.forEach { InfoPill(it, color = Steam.accentLink) }
            }
        }
        ControllerBadge(item.controllerSupport)
    }
}

@Composable
fun ControllerBadge(support: String?) {
    if (support == null) return
    Row(
        Modifier
            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(4.dp))
            .border(1.dp, Steam.accentLink.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.SportsEsports, null, tint = Steam.accentLink, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            if (support == "full") "Full Controller Support" else "Partial Controller Support",
            style = MaterialTheme.typography.labelLarge,
            color = Steam.textBody,
        )
    }
}

@Composable
private fun Fact(label: String, value: String, link: Boolean = false) {
    Row {
        Text(label.uppercase(), style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, modifier = Modifier.width(104.dp).padding(top = 2.dp))
        Text(value, style = MaterialTheme.typography.bodyMedium, color = if (link) Steam.accentLink else Steam.textBody)
    }
}

/** Purchase box: "Buy X", price block, Add to Cart (install gradient) and Wishlist. Visual only. */
@Composable
private fun PurchaseBox(item: StoreItem, primaryFocus: FocusRequester, modifier: Modifier = Modifier) {
    val app = LocalAppState.current
    val wishlisted = app.isWishlisted(item.appId)
    val owned = app.index.owns(item.appId)
    val nav = LocalNavigator.current
    Column(
        modifier
            .fillMaxWidth()
            .background(
                Brush.horizontalGradient(listOf(Color(0xFF2A4560), Color(0xFF1C3046))),
                RoundedCornerShape(6.dp),
            )
            .padding(16.dp),
    ) {
        Text(
            when {
                owned -> "${item.name} is in your library"
                item.price?.isFree == true -> "Play ${item.name}"
                item.price == null -> "${item.name} is coming soon"
                else -> "Buy ${item.name}"
            },
            style = MaterialTheme.typography.titleMedium,
            color = Steam.textTitle,
        )
        Spacer(Modifier.height(14.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (!owned) {
                PriceBlock(item.price, large = true, comingSoonLabel = item.releaseDate)
                Spacer(Modifier.width(12.dp))
            }
            if (owned) {
                GradientButton(
                    "In Library",
                    Steam.playGradient,
                    onClick = { nav.openGame(item.appId) },
                    icon = Icons.AutoMirrored.Outlined.LibraryBooks,
                    focusRequester = primaryFocus,
                    onSecondary = { app.toggleWishlist(item.appId) },
                    modifier = Modifier.weight(1f),
                )
            } else {
                GradientButton(
                    when {
                        item.price == null -> "Wishlist"
                        item.price.isFree -> "Play Game"
                        else -> "Add to Cart"
                    },
                    Steam.installGradient,
                    onClick = { if (item.price == null) app.toggleWishlist(item.appId) },
                    icon = if (item.price == null) null else Icons.Outlined.AddShoppingCart,
                    focusRequester = primaryFocus,
                    onSecondary = { app.toggleWishlist(item.appId) },
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(Modifier.width(10.dp))
            SecondaryButton(
                text = null,
                icon = if (wishlisted) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                iconTint = if (wishlisted) Steam.accentLink else Steam.textBody,
                contentDescription = "Wishlist",
                onClick = { app.toggleWishlist(item.appId) },
            )
        }
    }
}

@Composable
private fun Screenshots(item: StoreItem) {
    if (item.screenshots.isEmpty()) return
    val shell = LocalShell.current
    SectionHeader("Screenshots", Modifier.padding(horizontal = shell.gutter))
    Shelf(gutter = shell.gutter) {
        itemsIndexed(item.screenshots, key = { i, s -> "$i-${s.thumbnail}" }) { _, shot ->
            Box(
                Modifier
                    .width(300.dp)
                    .aspectRatio(16f / 9f)
                    .steamFocusable(onClick = {}, corner = 6.dp),
            ) {
                SteamImage(shot.full, Modifier.fillMaxSize())
            }
        }
    }
}

/** Big screenshot + thumbnail strip (regular widths). */
@Composable
private fun ScreenshotViewer(item: StoreItem) {
    var selected by remember(item.appId) { mutableIntStateOf(0) }
    val shots = item.screenshots
    if (shots.isEmpty()) {
        SteamImage(item.images.capsule, Modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(4.dp)))
        return
    }
    SteamImage(
        shots[selected.coerceIn(0, shots.lastIndex)].full,
        Modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(4.dp)),
    )
    Spacer(Modifier.height(4.dp))
    Shelf(gutter = 0.dp, spacing = 8.dp) {
        itemsIndexed(shots, key = { i, s -> "$i-${s.thumbnail}" }) { i, shot ->
            Box(
                Modifier
                    .width(132.dp)
                    .aspectRatio(16f / 9f)
                    .steamFocusable(onClick = { selected = i }, corner = 3.dp, focusScale = 1.06f)
                    .then(if (i == selected) Modifier.border(2.dp, Color.White, RoundedCornerShape(3.dp)) else Modifier),
            ) {
                SteamImage(shot.thumbnail, Modifier.fillMaxSize(), alpha = if (i == selected) 1f else 0.7f)
            }
        }
    }
}
