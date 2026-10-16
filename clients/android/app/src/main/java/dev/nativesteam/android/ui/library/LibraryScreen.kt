package dev.nativesteam.android.ui.library

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Downloading
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.nativesteam.android.data.Collection
import dev.nativesteam.android.data.LibraryGame
import dev.nativesteam.android.ui.components.BarAction
import dev.nativesteam.android.ui.components.BottomScrim
import dev.nativesteam.android.ui.components.FocusVisualState
import dev.nativesteam.android.ui.components.HomeScaffold
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.Shelf
import dev.nativesteam.android.ui.components.SteamChip
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.components.gamepadActivatable
import dev.nativesteam.android.ui.input.LocalInputState
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import dev.nativesteam.android.ui.shell.AppState
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.shell.Tab
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType
import kotlinx.coroutines.delay

enum class LibrarySort(val label: String) { Alphabetical("Alphabetical"), Recent("Recently played"), Hours("Hours played") }

private fun AppState.gamesIn(collection: Collection?): List<LibraryGame> {
    val all = index.snapshot.library.games
    return when {
        collection == null || collection.id == "all" -> all
        // "Favorites" is dynamic: it follows the star / X toggles.
        collection.id == "favorites" -> all.filter { isFavorite(it.appId) }
        else -> collection.appIds.mapNotNull { index.libraryGame(it) }
    }
}

private fun AppState.countIn(collection: Collection): Int =
    if (collection.id == "favorites") favorites.count { it.value } else collection.appIds.size

@Composable
fun LibraryScreen() {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val library = app.index.snapshot.library
    val collections = library.collections

    var collectionId by rememberSaveable { mutableStateOf(collections.firstOrNull()?.id ?: "all") }
    var sort by rememberSaveable { mutableStateOf(LibrarySort.Alphabetical) }
    var filter by rememberSaveable { mutableStateOf("") }
    val searchFocus = remember { FocusRequester() }
    val firstFocus = remember { FocusRequester() }
    InitialFocus(firstFocus)

    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(app.searchRequest) {
        if (app.searchRequest > 0 && app.searchTab == Tab.Library) {
            delay(150)
            runCatching { searchFocus.requestFocus() }
            keyboard?.show()
        }
    }
    // LT / RT page through collections.
    LaunchedEffect(app) {
        app.pageEvents.collect { delta ->
            if (app.tab != Tab.Library) return@collect
            val i = collections.indexOfFirst { it.id == collectionId }
            collectionId = collections[(i + delta + collections.size) % collections.size].id
            app.requestContentFocus()
        }
    }

    val collection = collections.firstOrNull { it.id == collectionId }
    val games = run {
        val base = app.gamesIn(collection).filter { filter.isBlank() || it.name.contains(filter.trim(), ignoreCase = true) }
        when (sort) {
            LibrarySort.Alphabetical -> base
            LibrarySort.Recent -> base.sortedByDescending { it.lastPlayed ?: "" }
            LibrarySort.Hours -> base.sortedByDescending { it.playtimeMinutes }
        }
    }
    val recent = library.recentAppIds.mapNotNull { app.index.libraryGame(it) }

    if (shell.width.hasSidebar) {
        Row(Modifier.fillMaxSize().background(Steam.libraryBackground)) {
            CollectionsSidebar(
                collections = collections,
                selectedId = collectionId,
                filter = filter,
                onFilter = { filter = it },
                searchFocus = searchFocus,
                onSelect = { collectionId = it },
            )
            LibraryGrid(
                games = games,
                recent = if (filter.isBlank()) recent else emptyList(),
                title = collection?.name ?: "All Games",
                sort = sort,
                onSort = { sort = it },
                firstFocus = firstFocus,
                header = null,
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(top = 12.dp, bottom = shell.bottomInset + 32.dp),
            )
        }
    } else {
        HomeScaffold(
            title = "Library",
            background = Steam.libraryBackground,
            actions = {
                BarAction(Icons.Outlined.Downloading, "Downloads") {}
                BarAction(Icons.Outlined.Tune, "Library settings") {}
            },
        ) { padding ->
            LibraryGrid(
                games = games,
                recent = if (filter.isBlank()) recent else emptyList(),
                title = collection?.name ?: "All Games",
                sort = sort,
                onSort = { sort = it },
                firstFocus = firstFocus,
                header = {
                    Column {
                        LibraryFilterField(
                            filter,
                            { filter = it },
                            searchFocus,
                            Modifier.padding(horizontal = shell.gutter).fillMaxWidth(),
                        )
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = shell.gutter, vertical = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            items(collections, key = { it.id }) { c ->
                                SteamChip(
                                    label = c.name,
                                    trailing = app.countIn(c).toString(),
                                    selected = c.id == collectionId,
                                    onClick = { collectionId = c.id },
                                )
                            }
                        }
                    }
                },
                contentPadding = padding,
            )
        }
    }
}

@Composable
private fun LibraryGrid(
    games: List<LibraryGame>,
    recent: List<LibraryGame>,
    title: String,
    sort: LibrarySort,
    onSort: (LibrarySort) -> Unit,
    firstFocus: FocusRequester,
    header: (@Composable () -> Unit)?,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues,
) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val gutter = shell.gutter
    LazyVerticalGrid(
        columns = if (shell.compact) GridCells.Fixed(3) else GridCells.Adaptive(136.dp),
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = gutter,
            end = gutter,
            top = contentPadding.calculateTopPadding(),
            bottom = contentPadding.calculateBottomPadding(),
        ),
        horizontalArrangement = Arrangement.spacedBy(if (shell.compact) 10.dp else 16.dp),
        verticalArrangement = Arrangement.spacedBy(if (shell.compact) 12.dp else 18.dp),
    ) {
        if (header != null) {
            item(key = "header", span = { GridItemSpan(maxLineSpan) }) {
                // Header content manages its own gutters; undo the grid's.
                Box(Modifier.padding(horizontal = 0.dp).layoutBleed(gutter)) { header() }
            }
        }
        if (recent.isNotEmpty()) {
            item(key = "recent", span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.layoutBleed(gutter)) {
                    SectionHeader("Recent Games", Modifier.padding(horizontal = gutter))
                    Shelf(gutter = gutter, spacing = 14.dp) {
                        itemsIndexed(recent, key = { _, g -> g.appId }) { i, g ->
                            val compact = shell.compact
                            val w = if (compact) 280.dp else 300.dp
                            val h = if (compact) 158.dp else 200.dp
                            RecentGameCard(
                                game = g,
                                width = if (!compact && i == 0) w * 2 + 14.dp else w,
                                height = h,
                                focusRequester = if (i == 0) firstFocus else null,
                                onClick = { nav.openGame(g.appId) },
                                onSecondary = { app.toggleFavorite(g.appId) },
                            )
                        }
                    }
                }
            }
        }
        item(key = "all-header", span = { GridItemSpan(maxLineSpan) }) {
            SectionHeader(
                title,
                count = "(${games.size})",
                modifier = Modifier.padding(top = 8.dp),
                trailing = { SortControl(sort, onSort) },
            )
        }
        if (games.isEmpty()) {
            item(key = "empty", span = { GridItemSpan(maxLineSpan) }) {
                Text(
                    "No games here yet.",
                    color = Steam.textSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(vertical = 24.dp),
                )
            }
        }
        items(games, key = { it.appId }) { game ->
            PortraitCard(
                game = game,
                favorite = app.isFavorite(game.appId),
                focusRequester = if (recent.isEmpty() && game == games.first()) firstFocus else null,
                onClick = { nav.openGame(game.appId) },
                onSecondary = { app.toggleFavorite(game.appId) },
            )
        }
    }
}

/** Lets a full-span grid item draw edge to edge, ignoring the grid's horizontal content padding. */
private fun Modifier.layoutBleed(gutter: Dp): Modifier = this.layout { measurable, constraints ->
    val extra = gutter.roundToPx() * 2
    val placeable = measurable.measure(
        constraints.copy(
            minWidth = constraints.minWidth + extra,
            maxWidth = if (constraints.hasBoundedWidth) constraints.maxWidth + extra else constraints.maxWidth,
        ),
    )
    layout(constraints.maxWidth, placeable.height) { placeable.place(-gutter.roundToPx(), 0) }
}

@Composable
private fun SortControl(sort: LibrarySort, onSort: (LibrarySort) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .steamFocusable(onClick = { open = true }, corner = 4.dp, focusScale = 1f, hoverLift = false)
                .heightIn(min = 40.dp)
                .padding(start = 10.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("SORT BY ", style = SteamType.caption)
            Text(sort.label, style = MaterialTheme.typography.labelLarge, color = Steam.textBody)
            Icon(Icons.Filled.ArrowDropDown, null, tint = Steam.textSecondary)
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            containerColor = Steam.surfaceNeutral,
        ) {
            LibrarySort.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label, color = if (option == sort) Steam.textTitle else Steam.textBody) },
                    trailingIcon = { if (option == sort) Icon(Icons.Filled.Check, null, tint = Steam.accent) },
                    onClick = {
                        onSort(option)
                        open = false
                    },
                    colors = MenuDefaults.itemColors(),
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/** 2:3 library cover. Not installed = dimmed + download glyph; favorite = star; update = blue dot. */
@Composable
fun PortraitCard(
    game: LibraryGame,
    favorite: Boolean,
    focusRequester: FocusRequester?,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state = remember { FocusVisualState() }
    Box(
        modifier
            .fillMaxWidth()
            .aspectRatio(2f / 3f)
            .steamFocusable(
                onClick = onClick,
                onSecondary = onSecondary,
                focusRequester = focusRequester,
                state = state,
                corner = 6.dp,
            ),
    ) {
        SteamImage(
            game.images.portrait ?: game.images.capsule,
            Modifier.fillMaxSize(),
            contentDescription = game.name,
            placeholderLabel = game.name,
            placeholderColor = Steam.surfaceNeutral,
            alpha = if (game.installed) 1f else 0.62f,
        )
        if (favorite) {
            Box(
                Modifier.align(Alignment.TopStart).padding(6.dp).size(22.dp).background(Color.Black.copy(alpha = 0.55f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Star, "Favorite", tint = Color(0xFFFFD34E), modifier = Modifier.size(14.dp))
            }
        }
        if (game.updateAvailable) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .size(11.dp)
                    .background(Steam.accent, CircleShape)
                    .border(2.dp, Color.Black.copy(alpha = 0.5f), CircleShape),
            )
        }
        if (!game.installed) {
            Box(
                Modifier.align(Alignment.BottomEnd).padding(6.dp).size(22.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Download, "Not installed", tint = Steam.textBody, modifier = Modifier.size(14.dp))
            }
        }
        AnimatedVisibility(
            state.emphasised,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomStart).fillMaxWidth(),
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.9f))))
                    .padding(start = 8.dp, end = 8.dp, top = 24.dp, bottom = 8.dp),
            ) {
                Text(
                    game.name,
                    color = Steam.textTitle,
                    style = MaterialTheme.typography.labelLarge,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Landscape "recent games" card: library hero with the title logo overlaid. */
@Composable
fun RecentGameCard(
    game: LibraryGame,
    width: Dp,
    height: Dp,
    focusRequester: FocusRequester?,
    onClick: () -> Unit,
    onSecondary: () -> Unit,
) {
    Column(Modifier.width(width)) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(height)
                .steamFocusable(onClick = onClick, onSecondary = onSecondary, focusRequester = focusRequester, corner = 6.dp),
        ) {
            SteamImage(
                game.images.hero ?: game.images.capsule,
                Modifier.fillMaxSize(),
                placeholderLabel = game.name,
                placeholderColor = Steam.surfaceNeutral,
            )
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.4f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.55f))))
            GameLogo(
                game.images.logo,
                game.name,
                Modifier
                    .align(Alignment.BottomStart)
                    .padding(12.dp)
                    .fillMaxWidth(0.62f)
                    .height(height * 0.42f),
            )
            if (game.playtimeTwoWeeksLabel != null) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 3.dp),
                ) {
                    Text(game.playtimeTwoWeeksLabel, style = MaterialTheme.typography.labelSmall, color = Steam.textBody)
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                game.name,
                style = MaterialTheme.typography.labelLarge,
                color = Steam.textBody,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Text(
                "  ·  ${game.lastPlayedLabel}",
                style = MaterialTheme.typography.labelMedium,
                color = Steam.textSecondary,
                maxLines = 1,
            )
        }
    }
}

/** Transparent title logo, or the name when the game has no logo art. */
@Composable
fun GameLogo(url: String?, name: String, modifier: Modifier = Modifier, fontSize: Int = 20) {
    if (url != null) {
        SteamImage(
            url,
            modifier,
            contentDescription = name,
            contentScale = ContentScale.Fit,
            alignment = Alignment.BottomStart,
            transparent = true,
        )
    } else {
        Box(modifier, contentAlignment = Alignment.BottomStart) {
            Text(name, color = Steam.textTitle, fontSize = fontSize.sp, fontWeight = FontWeight.Bold, maxLines = 2)
        }
    }
}

// ---------------------------------------------------------------------------
// Sidebar & filter
// ---------------------------------------------------------------------------

@Composable
private fun CollectionsSidebar(
    collections: List<Collection>,
    selectedId: String,
    filter: String,
    onFilter: (String) -> Unit,
    searchFocus: FocusRequester,
    onSelect: (String) -> Unit,
) {
    val app = LocalAppState.current
    val shell = LocalShell.current
    Column(
        Modifier
            .width(280.dp)
            .fillMaxHeight()
            .background(Steam.bgChrome.copy(alpha = 0.92f)),
    ) {
        LibraryFilterField(filter, onFilter, searchFocus, Modifier.padding(16.dp).fillMaxWidth(), placeholder = "Filter by name")
        LazyColumn(
            contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = shell.bottomInset + 16.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            item {
                Text("COLLECTIONS", style = SteamType.caption, modifier = Modifier.padding(start = 10.dp, top = 4.dp, bottom = 8.dp))
            }
            items(collections, key = { it.id }) { c ->
                val selected = c.id == selectedId
                if (c.kind == "user" && collections.first { it.kind == "user" } == c) {
                    Text("YOUR COLLECTIONS", style = SteamType.caption, modifier = Modifier.padding(start = 10.dp, top = 16.dp, bottom = 8.dp))
                }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .steamFocusable(onClick = { onSelect(c.id) }, corner = 4.dp, focusScale = 1.02f, hoverLift = false)
                        .background(if (selected) Steam.accent.copy(alpha = 0.2f) else Color.Transparent)
                        .heightIn(min = 44.dp)
                        .padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier
                            .width(3.dp)
                            .height(18.dp)
                            .background(if (selected) Steam.accent else Color.Transparent, RoundedCornerShape(2.dp)),
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        c.name,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (selected) Steam.textTitle else Steam.textBody,
                        modifier = Modifier.weight(1f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(app.countIn(c).toString(), style = MaterialTheme.typography.labelMedium, color = Steam.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun LibraryFilterField(
    value: String,
    onValue: (String) -> Unit,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    placeholder: String = "Search your library",
) {
    var focused by remember { mutableStateOf(false) }
    val input = LocalInputState.current
    val keyboard = LocalSoftwareKeyboardController.current
    BasicTextField(
        value = value,
        onValueChange = onValue,
        singleLine = true,
        textStyle = MaterialTheme.typography.bodyMedium.copy(color = Steam.textTitle),
        cursorBrush = SolidColor(Steam.accent),
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
                    .height(44.dp)
                    .background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(6.dp))
                    .border(if (focused) 2.dp else 0.dp, if (focused) Steam.accent else Color.Transparent, RoundedCornerShape(6.dp))
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Search, null, tint = Steam.textSecondary, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (value.isEmpty()) Text(placeholder, style = MaterialTheme.typography.bodyMedium, color = Steam.textSecondary)
                    inner()
                }
                Icon(Icons.Filled.FilterList, null, tint = Steam.textSecondary, modifier = Modifier.size(20.dp))
            }
        },
    )
}
