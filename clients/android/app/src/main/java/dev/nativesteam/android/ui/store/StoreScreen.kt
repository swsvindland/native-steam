package dev.nativesteam.android.ui.store

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.nativesteam.android.data.ChartEntry
import dev.nativesteam.android.data.StoreItem
import dev.nativesteam.android.ui.components.BarAction
import dev.nativesteam.android.ui.components.BottomScrim
import dev.nativesteam.android.ui.components.HomeScaffold
import dev.nativesteam.android.ui.components.InfoPill
import dev.nativesteam.android.ui.components.LiveDot
import dev.nativesteam.android.ui.components.PlatformIcons
import dev.nativesteam.android.ui.components.PriceBlock
import dev.nativesteam.android.ui.components.ReviewLabel
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.Shelf
import dev.nativesteam.android.ui.components.SteamCard
import dev.nativesteam.android.ui.components.SteamChip
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.ToneDot
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.components.gamepadActivatable
import dev.nativesteam.android.ui.input.LocalInputState
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.shell.Tab
import dev.nativesteam.android.ui.theme.Steam
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun StoreScreen() {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val store = app.index.snapshot.store
    val gutter = shell.gutter

    var query by rememberSaveable { mutableStateOf("") }
    var tag by rememberSaveable { mutableStateOf<String?>(null) }
    val searchFocus = remember { FocusRequester() }
    val firstFocus = remember { FocusRequester() }
    var mostPlayedExpanded by rememberSaveable { mutableStateOf(false) }

    InitialFocus(firstFocus)
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(app.searchRequest) {
        if (app.searchRequest > 0 && app.searchTab == Tab.Store) {
            delay(150)
            runCatching { searchFocus.requestFocus() }
            keyboard?.show()
        }
    }

    val searching = query.isNotBlank() || tag != null
    val results = remember(query, tag) {
        app.index.allStoreItems.filter { item ->
            (query.isBlank() || item.name.contains(query.trim(), ignoreCase = true) ||
                item.genres.any { it.equals(query.trim(), ignoreCase = true) }) &&
                (tag == null || item.genres.any { it.equals(tag, ignoreCase = true) })
        }
    }

    HomeScaffold(
        title = "Store",
        background = Steam.storeBackground,
        actions = {
            BarAction(Icons.Outlined.FavoriteBorder, "Wishlist") {}
            BarAction(Icons.Outlined.ShoppingCart, "Cart") {}
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            val tagsRow: @Composable (Modifier, PaddingValues) -> Unit = { modifier, contentPadding ->
                LazyRow(
                    modifier,
                    contentPadding = contentPadding,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(store.popularTags, key = { it.id }) { t ->
                        SteamChip(
                            label = t.name,
                            selected = tag == t.name,
                            onClick = { tag = if (tag == t.name) null else t.name },
                        )
                    }
                }
            }
            if (shell.compact) {
                item(key = "search") {
                    StoreSearchField(
                        query = query,
                        onQuery = { query = it },
                        focusRequester = searchFocus,
                        modifier = Modifier.padding(horizontal = gutter).fillMaxWidth(),
                    )
                }
                item(key = "tags") { tagsRow(Modifier, PaddingValues(horizontal = gutter, vertical = 12.dp)) }
            } else {
                // Steam-desktop store bar: search, tag chips, wishlist + cart.
                item(key = "search") {
                    Row(
                        Modifier.padding(start = gutter, end = gutter - 4.dp, bottom = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        StoreSearchField(
                            query = query,
                            onQuery = { query = it },
                            focusRequester = searchFocus,
                            modifier = Modifier.width(360.dp),
                        )
                        tagsRow(Modifier.weight(1f), PaddingValues(horizontal = 12.dp, vertical = 8.dp))
                        BarAction(Icons.Outlined.FavoriteBorder, "Wishlist") {}
                        BarAction(Icons.Outlined.ShoppingCart, "Cart") {}
                    }
                }
            }

            if (searching) {
                item(key = "results-header") {
                    SectionHeader(
                        title = if (tag != null && query.isBlank()) "Tagged: ${tag}" else "Search results",
                        count = "${results.size}",
                        modifier = Modifier.padding(horizontal = gutter),
                        seeAllLabel = "Clear",
                        onSeeAll = { query = ""; tag = null },
                    )
                }
                if (results.isEmpty()) {
                    item(key = "empty") {
                        Text(
                            "Nothing in this snapshot matches. Try another tag or title.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Steam.textSecondary,
                            modifier = Modifier.padding(horizontal = gutter, vertical = 24.dp),
                        )
                    }
                }
                items(results, key = { "r-${it.appId}" }) { item ->
                    StoreListRow(
                        item = item,
                        onClick = { nav.openApp(item.appId) },
                        onSecondary = { app.toggleWishlist(item.appId) },
                        modifier = Modifier.padding(horizontal = gutter, vertical = 5.dp),
                    )
                }
                return@LazyColumn
            }

            // FEATURED & RECOMMENDED
            item(key = "featured") {
                Column {
                    SectionHeader("Featured & Recommended", Modifier.padding(horizontal = gutter))
                    FeaturedCarousel(store.featured, firstFocus) { nav.openApp(it) }
                }
            }

            // SPECIAL OFFERS
            item(key = "specials") {
                StoreShelf("Special Offers", store.specials, onSeeAll = { tag = null; query = "" }) { nav.openApp(it) }
            }

            // TOP SELLERS
            item(key = "top-sellers-header") {
                if (shell.compact) {
                    StoreShelf("Top Sellers", store.topSellers) { nav.openApp(it) }
                } else {
                    Column(Modifier.padding(horizontal = gutter)) {
                        Spacer(Modifier.height(20.dp))
                        SectionHeader("Top Sellers", onSeeAll = {})
                        Spacer(Modifier.height(6.dp))
                        store.topSellers.chunked(2).forEach { pair ->
                            Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                pair.forEach { item ->
                                    StoreListRow(
                                        item = item,
                                        onClick = { nav.openApp(item.appId) },
                                        onSecondary = { app.toggleWishlist(item.appId) },
                                        modifier = Modifier.weight(1f),
                                    )
                                }
                                if (pair.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // NEW & TRENDING
            item(key = "new") {
                StoreShelf("New & Trending", store.newReleases) { nav.openApp(it) }
            }

            // MOST PLAYED
            item(key = "most-played-header") {
                Column(Modifier.padding(horizontal = gutter)) {
                    Spacer(Modifier.height(20.dp))
                    SectionHeader(
                        "Most Played",
                        seeAllLabel = if (mostPlayedExpanded) "Show less" else "See all",
                        onSeeAll = { mostPlayedExpanded = !mostPlayedExpanded },
                    )
                    Spacer(Modifier.height(4.dp))
                }
            }
            val charts = if (mostPlayedExpanded) store.mostPlayed else store.mostPlayed.take(if (shell.compact) 5 else 6)
            if (shell.compact) {
                items(charts, key = { "mp-${it.rank}" }) { entry ->
                    MostPlayedRow(entry, Modifier.padding(horizontal = gutter, vertical = 4.dp)) { nav.openTitle(entry.appId) }
                }
            } else {
                items(charts.chunked(2), key = { "mp-${it.first().rank}" }) { pair ->
                    Row(Modifier.padding(horizontal = gutter, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        pair.forEach { entry ->
                            MostPlayedRow(entry, Modifier.weight(1f)) { nav.openTitle(entry.appId) }
                        }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }

            // POPULAR UPCOMING
            item(key = "upcoming") {
                StoreShelf("Popular Upcoming", store.comingSoon, upcoming = true) { nav.openApp(it) }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

@Composable
private fun StoreSearchField(
    query: String,
    onQuery: (String) -> Unit,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    placeholder: String = "Search the store",
) {
    var focused by remember { mutableStateOf(false) }
    val input = LocalInputState.current
    val keyboard = LocalSoftwareKeyboardController.current
    BasicTextField(
        value = query,
        onValueChange = onQuery,
        singleLine = true,
        textStyle = MaterialTheme.typography.bodyLarge.copy(color = Steam.textTitle),
        cursorBrush = SolidColor(Steam.accent),
        // With a controller / keys, moving focus onto the field must not pop the IME; A (or Y) does.
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search, showKeyboardOnFocus = !input.mode.showsFocus),
        keyboardActions = KeyboardActions(onSearch = { keyboard?.hide() }),
        modifier = modifier
            .focusRequester(focusRequester)
            .gamepadActivatable { keyboard?.show() }
            .onFocusChanged { focused = it.isFocused },
        decorationBox = { inner ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .background(Color(0xFF233A52), RoundedCornerShape(6.dp))
                    .border(
                        width = if (focused) 2.dp else 1.dp,
                        color = if (focused) Steam.accent else Color.White.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(6.dp),
                    )
                    .padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Search, null, tint = Steam.accentLink, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Box(Modifier.weight(1f)) {
                    if (query.isEmpty()) {
                        Text(placeholder, style = MaterialTheme.typography.bodyLarge, color = Steam.textSecondary)
                    }
                    inner()
                }
                if (query.isNotEmpty()) {
                    Icon(
                        Icons.Filled.Close,
                        "Clear",
                        tint = Steam.textSecondary,
                        modifier = Modifier
                            .size(36.dp)
                            .steamFocusable(onClick = { onQuery("") }, corner = 18.dp, focusScale = 1f)
                            .padding(8.dp),
                    )
                }
            }
        },
    )
}

// ---------------------------------------------------------------------------
// Featured carousel
// ---------------------------------------------------------------------------

@Composable
private fun FeaturedCarousel(items: List<StoreItem>, firstFocus: FocusRequester, onOpen: (Int) -> Unit) {
    if (items.isEmpty()) return
    val shell = LocalShell.current
    val app = LocalAppState.current
    val pager = rememberPagerState { items.size }
    val scope = rememberCoroutineScope()
    val hover = remember { MutableInteractionSource() }
    val hovered by hover.collectIsHoveredAsState()
    val dragged by pager.interactionSource.collectIsDraggedAsState()
    var focusInside by remember { mutableStateOf(false) }
    val paused = hovered || dragged || focusInside

    // Auto-advance every 6 s, paused while focused / hovered / being swiped.
    LaunchedEffect(paused) {
        if (paused) return@LaunchedEffect
        while (true) {
            delay(6000)
            pager.animateScrollToPage((pager.currentPage + 1) % items.size)
        }
    }

    Column(
        Modifier
            .fillMaxWidth()
            .hoverable(hover)
            .onFocusChanged { focusInside = it.hasFocus },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (shell.compact) {
            HorizontalPager(
                state = pager,
                contentPadding = PaddingValues(horizontal = shell.gutter),
                pageSpacing = 12.dp,
                modifier = Modifier.padding(vertical = 8.dp),
            ) { page ->
                val item = items[page]
                FeaturedCompactCard(
                    item,
                    focusRequester = if (page == 0) firstFocus else null,
                    onClick = { onOpen(item.appId) },
                    onSecondary = { app.toggleWishlist(item.appId) },
                )
            }
        } else {
            Row(
                Modifier.widthIn(max = 1120.dp).fillMaxWidth().padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CarouselArrow(left = true) { scope.launch { pager.animateScrollToPage((pager.currentPage - 1 + items.size) % items.size) } }
                HorizontalPager(
                    state = pager,
                    pageSpacing = 24.dp,
                    modifier = Modifier.weight(1f).padding(vertical = 10.dp),
                ) { page ->
                    val item = items[page]
                    FeaturedWideCard(
                        item,
                        focusRequester = if (page == 0) firstFocus else null,
                        onClick = { onOpen(item.appId) },
                        onSecondary = { app.toggleWishlist(item.appId) },
                    )
                }
                CarouselArrow(left = false) { scope.launch { pager.animateScrollToPage((pager.currentPage + 1) % items.size) } }
            }
        }
        PagerDots(pager, items.size)
    }
}

@Composable
private fun PagerDots(pager: PagerState, count: Int) {
    Row(
        Modifier.padding(top = 6.dp, bottom = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { i ->
            val selected = pager.currentPage == i
            Box(
                Modifier
                    .size(width = if (selected) 18.dp else 12.dp, height = 6.dp)
                    .background(if (selected) Steam.accentLink else Color.White.copy(alpha = 0.18f), RoundedCornerShape(3.dp)),
            )
        }
    }
}

@Composable
private fun CarouselArrow(left: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .padding(horizontal = 6.dp)
            .steamFocusable(onClick = onClick, corner = 6.dp, focusScale = 1.06f)
            .background(Color.Black.copy(alpha = 0.25f))
            .size(width = 44.dp, height = 96.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            if (left) Icons.AutoMirrored.Filled.KeyboardArrowLeft else Icons.AutoMirrored.Filled.KeyboardArrowRight,
            if (left) "Previous" else "Next",
            tint = Steam.textBody,
            modifier = Modifier.size(32.dp),
        )
    }
}

@Composable
private fun FeaturedCompactCard(
    item: StoreItem,
    focusRequester: FocusRequester?,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
) {
    val app = LocalAppState.current
    SteamCard(
        onClick = onClick,
        onSecondary = onSecondary,
        focusRequester = focusRequester,
        focusScale = 1.02f,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            Box(Modifier.fillMaxWidth().aspectRatio(616f / 353f)) {
                SteamImage(item.images.capsule, Modifier.fillMaxSize(), placeholderLabel = item.name)
                Box(Modifier.fillMaxSize().background(BottomScrim))
                if (app.isWishlisted(item.appId)) WishlistBadge(Modifier.align(Alignment.TopEnd).padding(10.dp))
                Row(
                    Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.Bottom,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            item.name,
                            style = MaterialTheme.typography.titleLarge,
                            color = Steam.textTitle,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Spacer(Modifier.height(2.dp))
                        ReviewLabel(item.review)
                    }
                    Spacer(Modifier.width(12.dp))
                    PriceBlock(item.price, comingSoonLabel = item.releaseDate, onArt = true)
                }
            }
        }
    }
}

@Composable
private fun FeaturedWideCard(
    item: StoreItem,
    focusRequester: FocusRequester?,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
) {
    val app = LocalAppState.current
    SteamCard(
        onClick = onClick,
        onSecondary = onSecondary,
        focusRequester = focusRequester,
        focusScale = 1.015f,
        color = Steam.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.fillMaxWidth().height(IntrinsicCapsuleHeight)) {
            Box(Modifier.weight(0.62f).fillMaxHeight()) {
                SteamImage(item.images.capsule, Modifier.fillMaxSize(), placeholderLabel = item.name)
                if (app.isWishlisted(item.appId)) WishlistBadge(Modifier.align(Alignment.TopEnd).padding(12.dp))
            }
            Column(
                Modifier
                    .weight(0.38f)
                    .fillMaxHeight()
                    .background(Brush_panel)
                    .padding(16.dp),
            ) {
                Text(
                    item.name,
                    style = MaterialTheme.typography.titleLarge,
                    color = Steam.textTitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(10.dp))
                // 2×2 screenshots fill whatever height the panel has left.
                val shots = item.screenshots.take(4)
                Column(Modifier.weight(1f).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    shots.chunked(2).forEach { row ->
                        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            row.forEach { s ->
                                SteamImage(
                                    s.thumbnail,
                                    Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(3.dp)),
                                )
                            }
                            if (row.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    if (item.comingSoon) "Coming soon" else "Now available",
                    style = MaterialTheme.typography.titleSmall,
                    color = Steam.textTitle,
                )
                Spacer(Modifier.height(2.dp))
                ReviewLabel(item.review, showCount = true)
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        item.genres.take(3).forEach { InfoPill(it, color = Steam.textBody, background = Color.White.copy(alpha = 0.08f)) }
                    }
                    Spacer(Modifier.width(8.dp))
                    PriceBlock(item.price, comingSoonLabel = item.releaseDate)
                }
            }
        }
    }
}

private val IntrinsicCapsuleHeight = 320.dp
private val Brush_panel = androidx.compose.ui.graphics.Brush.horizontalGradient(
    listOf(Color(0xFF0F1922), Color(0xFF16202D)),
)

@Composable
fun WishlistBadge(modifier: Modifier = Modifier) {
    Box(
        modifier.size(30.dp).background(Color.Black.copy(alpha = 0.55f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Filled.Favorite, "On your wishlist", tint = Steam.accentLink, modifier = Modifier.size(16.dp))
    }
}

// ---------------------------------------------------------------------------
// Shelves & rows
// ---------------------------------------------------------------------------

@Composable
private fun StoreShelf(
    title: String,
    items: List<StoreItem>,
    upcoming: Boolean = false,
    onSeeAll: (() -> Unit)? = {},
    onOpen: (Int) -> Unit,
) {
    val shell = LocalShell.current
    val app = LocalAppState.current
    Column {
        Spacer(Modifier.height(20.dp))
        SectionHeader(title, Modifier.padding(horizontal = shell.gutter), onSeeAll = onSeeAll)
        Shelf(gutter = shell.gutter) {
            items(items, key = { it.appId }) { item ->
                StoreCapsuleCard(
                    item = item,
                    width = if (shell.compact) 236.dp else 292.dp,
                    upcoming = upcoming,
                    onClick = { onOpen(item.appId) },
                    onSecondary = { app.toggleWishlist(item.appId) },
                )
            }
        }
    }
}

@Composable
fun StoreCapsuleCard(
    item: StoreItem,
    width: Dp,
    upcoming: Boolean,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
    focusRequester: FocusRequester? = null,
) {
    val app = LocalAppState.current
    SteamCard(
        onClick = onClick,
        onSecondary = onSecondary,
        focusRequester = focusRequester,
        modifier = Modifier.width(width),
    ) {
        Column {
            Box(Modifier.fillMaxWidth().aspectRatio(460f / 215f)) {
                SteamImage(item.images.header, Modifier.fillMaxSize(), placeholderLabel = item.name)
                if (app.isWishlisted(item.appId)) WishlistBadge(Modifier.align(Alignment.TopEnd).padding(6.dp))
            }
            Column(Modifier.padding(start = 10.dp, end = 10.dp, top = 9.dp, bottom = 10.dp)) {
                Text(
                    item.name,
                    style = MaterialTheme.typography.titleSmall,
                    color = Steam.textTitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(2.dp))
                val meta = when {
                    upcoming -> item.releaseDate?.let { "Coming $it" } ?: "Coming soon"
                    item.discountEndsLabel != null -> item.discountEndsLabel
                    else -> item.genres.take(2).joinToString(" · ").ifEmpty { item.releaseDate.orEmpty() }
                }
                Text(
                    meta,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (item.discountEndsLabel != null && !upcoming) Steam.accentLink else Steam.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    PlatformIcons(item.platforms)
                    Spacer(Modifier.weight(1f))
                    PriceBlock(item.price, comingSoonLabel = if (upcoming) "Wishlist" else null)
                }
            }
        }
    }
}

/** Steam desktop "tab" row: small capsule, name, platforms, review tone, price. */
@Composable
fun StoreListRow(
    item: StoreItem,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
    modifier: Modifier = Modifier,
) {
    SteamCard(
        onClick = onClick,
        onSecondary = onSecondary,
        focusScale = 1.02f,
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(Modifier.fillMaxWidth().height(72.dp), verticalAlignment = Alignment.CenterVertically) {
            SteamImage(
                item.images.smallCapsule,
                Modifier.fillMaxHeight().aspectRatio(231f / 87f),
                placeholderLabel = item.name,
            )
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(
                    item.name,
                    style = MaterialTheme.typography.titleSmall,
                    color = Steam.textTitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    PlatformIcons(item.platforms)
                    if (item.review != null) {
                        Spacer(Modifier.width(10.dp))
                        ToneDot(item.review.tone)
                        Spacer(Modifier.width(5.dp))
                        Text(
                            item.review.label,
                            style = MaterialTheme.typography.labelSmall,
                            color = Steam.reviewColor(item.review.tone),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
            PriceBlock(item.price, comingSoonLabel = item.releaseDate, modifier = Modifier.padding(end = 12.dp))
        }
    }
}

@Composable
private fun MostPlayedRow(entry: ChartEntry, modifier: Modifier = Modifier, onClick: () -> Unit) {
    SteamCard(onClick = onClick, focusScale = 1.02f, modifier = modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 72.dp).padding(end = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "#${entry.rank}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = if (entry.rank <= 3) Steam.textTitle else Steam.textSecondary,
                modifier = Modifier.width(48.dp).padding(start = 12.dp),
            )
            SteamImage(
                entry.images.header,
                Modifier.width(128.dp).aspectRatio(460f / 215f).clip(RoundedCornerShape(3.dp)),
                placeholderLabel = entry.name,
            )
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(
                    entry.name,
                    style = MaterialTheme.typography.titleSmall,
                    color = Steam.textTitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(3.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LiveDot()
                    Spacer(Modifier.width(6.dp))
                    Text(entry.currentPlayersLabel, style = MaterialTheme.typography.bodySmall, color = Steam.statusInGame, maxLines = 1)
                }
                Text(entry.peakTodayLabel, style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, maxLines = 1)
            }
            PriceBlock(entry.price)
        }
    }
}
