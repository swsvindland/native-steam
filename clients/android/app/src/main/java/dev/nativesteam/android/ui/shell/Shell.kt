package dev.nativesteam.android.ui.shell

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.foundation.focusable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.InputMode as ComposeInputMode
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import androidx.window.core.layout.WindowSizeClass
import androidx.window.core.layout.computeWindowSizeClass
import dev.nativesteam.android.data.SnapshotIndex
import dev.nativesteam.android.ui.community.CommunityScreen
import dev.nativesteam.android.ui.community.FriendsScreen
import dev.nativesteam.android.ui.components.Avatar
import dev.nativesteam.android.ui.components.Wordmark
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.input.LocalFocusedActions
import dev.nativesteam.android.ui.input.LocalInputState
import dev.nativesteam.android.ui.input.InputMode
import dev.nativesteam.android.ui.input.KeyRouter
import dev.nativesteam.android.ui.library.GameScreen
import dev.nativesteam.android.ui.library.LibraryScreen
import dev.nativesteam.android.ui.profile.ProfileScreen
import dev.nativesteam.android.ui.store.StoreAppScreen
import dev.nativesteam.android.ui.store.StoreScreen
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType
import kotlinx.coroutines.delay

/** Steam breakpoints expressed as a custom set of Jetpack WindowSizeClasses. */
private val SteamBreakpoints = setOf(
    WindowSizeClass(minWidthDp = 0, minHeightDp = 0),
    WindowSizeClass(minWidthDp = 700, minHeightDp = 0),
    WindowSizeClass(minWidthDp = 1000, minHeightDp = 0),
    WindowSizeClass(minWidthDp = 1100, minHeightDp = 0),
)

@Composable
private fun rememberWidthClass(): WidthClass {
    val size = LocalWindowInfo.current.containerSize
    val density = LocalDensity.current
    val widthDp = with(density) { size.width.toDp().value }
    val heightDp = with(density) { size.height.toDp().value }
    val sizeClass = SteamBreakpoints.computeWindowSizeClass(widthDp, heightDp)
    return when {
        sizeClass.isWidthAtLeastBreakpoint(1100) -> WidthClass.Wide
        sizeClass.isWidthAtLeastBreakpoint(1000) -> WidthClass.Expanded
        sizeClass.isWidthAtLeastBreakpoint(700) -> WidthClass.Regular
        else -> WidthClass.Compact
    }
}

@Composable
fun NativeSteamShell(index: SnapshotIndex, launch: LaunchRequest?, keyRouter: KeyRouter) {
    val input = LocalInputState.current
    val actions = LocalFocusedActions.current
    val inputModeManager = LocalInputModeManager.current
    val app = remember(index) { AppState(index) }
    val controllers: Map<Tab, NavHostController> = Tab.entries.associateWith { rememberNavController() }
    app.controllers = controllers
    val width = rememberWidthClass()
    val gamepad = input.mode == InputMode.Gamepad

    // Leave touch mode when keys / a controller take over so every card is focusable.
    LaunchedEffect(input.mode) {
        if (input.mode.showsFocus && inputModeManager.inputMode != ComposeInputMode.Keyboard) {
            inputModeManager.requestInputMode(ComposeInputMode.Keyboard)
        }
    }

    LaunchedEffect(launch?.nonce) {
        val request = launch ?: return@LaunchedEffect
        if (request.gamepad) {
            input.forceGamepad()
            inputModeManager.requestInputMode(ComposeInputMode.Keyboard)
        }
        val tab = request.tab ?: when {
            request.gameId != null -> Tab.Library
            request.appId != null -> Tab.Store
            else -> null
        }
        if (tab != null) app.select(tab)
        request.gameId?.let { app.pendingRoutes[tab ?: Tab.Library] = GameRoute(it) }
        request.appId?.let { app.pendingRoutes[tab ?: Tab.Store] = AppRoute(it) }
        if (request.gamepad) {
            delay(250)
            app.requestContentFocus()
        }
    }

    fun switchTab(delta: Int) {
        val all = Tab.entries
        app.select(all[(all.indexOf(app.tab) + delta + all.size) % all.size])
        app.requestContentFocus()
    }

    fun goBack(): Boolean {
        val nav = controllers.getValue(app.tab)
        if (nav.previousBackStackEntry != null) {
            nav.popBackStack()
            app.requestContentFocus()
        } else {
            // At a tab root: B moves focus up to the tab bar.
            runCatching { app.tabFocus.getValue(app.tab).requestFocus() }
        }
        return true
    }

    fun search() {
        val target = if (app.tab == Tab.Library) Tab.Library else Tab.Store
        if (app.tab != target) app.select(target)
        val nav = controllers.getValue(target)
        while (nav.previousBackStackEntry != null) nav.popBackStack()
        app.requestSearch(target)
    }

    fun onPreviewKey(event: KeyEvent): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        val native = event.nativeKeyEvent
        if (native.repeatCount > 0 && event.key in setOf(Key.ButtonL1, Key.ButtonR1, Key.ButtonB, Key.ButtonY)) return true
        when (event.key) {
            Key.ButtonL1 -> { switchTab(-1); return true }
            Key.ButtonR1 -> { switchTab(1); return true }
            Key.ButtonA -> return actions.activate()
            Key.ButtonB -> return goBack()
            Key.ButtonY -> { search(); return true }
            Key.ButtonX -> return actions.secondary()
            Key.ButtonL2 -> { app.pageEvents.tryEmit(-1); return true }
            Key.ButtonR2 -> { app.pageEvents.tryEmit(1); return true }
        }
        if (event.isCtrlPressed || event.isMetaPressed) {
            when (event.key) {
                Key.One -> { app.select(Tab.Store); return true }
                Key.Two -> { app.select(Tab.Library); return true }
                Key.Three -> { app.select(Tab.Community); return true }
                Key.Four -> { app.select(Tab.Profile); return true }
                Key.F -> { search(); return true }
                Key.LeftBracket -> return goBack()
            }
        }
        return false
    }

    // Esc / Backspace only act as "back" if nothing focused (e.g. a text field) consumed them.
    fun onBubbleKey(event: KeyEvent): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        return when (event.key) {
            Key.Escape, Key.Backspace -> goBack()
            else -> false
        }
    }

    // The root is itself focusable so its key handlers always see events; when focus sits on the
    // root (nothing inside focused) the first D-pad press goes to the page's first card.
    val rootFocus = remember { FocusRequester() }
    var rootFocused by remember { mutableStateOf(false) }
    var anyFocused by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { runCatching { rootFocus.requestFocus() } }
    fun isDirectional(code: Int) = code == android.view.KeyEvent.KEYCODE_DPAD_UP || code == android.view.KeyEvent.KEYCODE_DPAD_DOWN ||
        code == android.view.KeyEvent.KEYCODE_DPAD_LEFT || code == android.view.KeyEvent.KEYCODE_DPAD_RIGHT
    SideEffect {
        keyRouter.beforeCompose = { e ->
            if (e.action == android.view.KeyEvent.ACTION_DOWN && isDirectional(e.keyCode) && (rootFocused || !anyFocused)) {
                if (!anyFocused) runCatching { rootFocus.requestFocus() }
                app.requestContentFocus()
                true
            } else {
                false
            }
        }
        keyRouter.unhandled = { e ->
            val ke = KeyEvent(e)
            onPreviewKey(ke) || onBubbleKey(ke)
        }
    }
    val currentNav = controllers.getValue(app.tab)
    val entry by currentNav.currentBackStackEntryAsState()
    val atRoot = entry != null && currentNav.previousBackStackEntry == null
    // System back at the root of a secondary tab returns to the Store tab first.
    BackHandler(enabled = atRoot && app.tab != Tab.Store) { app.select(Tab.Store) }

    CompositionLocalProvider(LocalAppState provides app) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Steam.bgChrome)
                .onPreviewKeyEvent(::onPreviewKey)
                .onKeyEvent(::onBubbleKey)
                .onFocusChanged {
                    rootFocused = it.isFocused
                    anyFocused = it.hasFocus
                }
                .focusRequester(rootFocus)
                .focusable(),
        ) {
            if (width.isCompact) {
                CompactShell(app, controllers, width, gamepad, input.gamepadConnected || gamepad, !atRoot)
            } else {
                RegularShell(app, controllers, width, gamepad, input.gamepadConnected || gamepad, !atRoot)
            }
            MessageToast(app, Modifier.align(Alignment.BottomCenter).padding(bottom = if (width.isCompact) 140.dp else 96.dp))
        }
    }
}

@Composable
private fun TabContent(app: AppState, controllers: Map<Tab, NavHostController>, modifier: Modifier = Modifier) {
    val holder = rememberSaveableStateHolder()
    AnimatedContent(
        targetState = app.tab,
        transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) },
        modifier = modifier,
        label = "tabs",
    ) { tab ->
        holder.SaveableStateProvider(tab.name) {
            TabHost(tab, controllers.getValue(tab), app)
        }
    }
}

@Composable
private fun TabHost(tab: Tab, nav: NavHostController, app: AppState) {
    val navigator = remember(nav) { Navigator(nav, app) }
    val start: Any = when (tab) {
        Tab.Store -> StoreHome
        Tab.Library -> LibraryHome
        Tab.Community -> CommunityHome
        Tab.Profile -> ProfileHome
    }
    CompositionLocalProvider(LocalNavigator provides navigator) {
        NavHost(
            navController = nav,
            startDestination = start,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { slideInHorizontally(tween(260)) { it / 5 } + fadeIn(tween(200)) },
            exitTransition = { fadeOut(tween(160)) + scaleOut(tween(260), targetScale = 0.97f) },
            popEnterTransition = { fadeIn(tween(200)) + scaleIn(tween(260), initialScale = 0.97f) },
            popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(200)) },
        ) {
            when (tab) {
                Tab.Store -> composable<StoreHome> { StoreScreen() }
                Tab.Library -> composable<LibraryHome> { LibraryScreen() }
                Tab.Community -> composable<CommunityHome> { CommunityScreen() }
                Tab.Profile -> composable<ProfileHome> { ProfileScreen() }
            }
            composable<AppRoute> { StoreAppScreen(it.toRoute<AppRoute>().appId) }
            composable<GameRoute> { GameScreen(it.toRoute<GameRoute>().appId) }
            composable<FriendsRoute> { FriendsScreen() }
        }
    }
    val pending = app.pendingRoutes[tab]
    LaunchedEffect(pending) {
        if (pending != null) {
            nav.navigate(pending)
            app.pendingRoutes.remove(tab)
        }
    }
}

// ---------------------------------------------------------------------------
// Compact: bottom navigation bar
// ---------------------------------------------------------------------------

@Composable
private fun CompactShell(
    app: AppState,
    controllers: Map<Tab, NavHostController>,
    width: WidthClass,
    gamepad: Boolean,
    controllerPresent: Boolean,
    canGoBack: Boolean,
) {
    CompositionLocalProvider(LocalShell provides ShellInfo(width)) {
        Column(Modifier.fillMaxSize()) {
            TabContent(app, controllers, Modifier.weight(1f))
            AnimatedVisibility(gamepad, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                ButtonHintsBar(app.tab, canGoBack, compact = true)
            }
            SteamNavigationBar(app, controllerPresent)
        }
    }
}

@Composable
private fun SteamNavigationBar(app: AppState, controllerPresent: Boolean) {
    val user = app.index.snapshot.user
    val itemColors = NavigationBarItemDefaults.colors(
        selectedIconColor = Steam.textTitle,
        selectedTextColor = Steam.textTitle,
        unselectedIconColor = Steam.textSecondary,
        unselectedTextColor = Steam.textSecondary,
        indicatorColor = Steam.accent.copy(alpha = 0.22f),
    )
    NavigationBar(containerColor = Steam.bgChrome, tonalElevation = 0.dp) {
        if (controllerPresent) ShoulderGlyph("LB", Modifier.align(Alignment.CenterVertically).padding(start = 6.dp))
        Tab.entries.forEach { tab ->
            val selected = app.tab == tab
            NavigationBarItem(
                selected = selected,
                onClick = {
                    if (selected) {
                        val nav = app.controllers.getValue(tab)
                        while (nav.previousBackStackEntry != null) nav.popBackStack()
                    } else {
                        app.select(tab)
                    }
                },
                icon = {
                    when (tab) {
                        Tab.Store -> Icon(if (selected) Icons.Filled.Storefront else Icons.Outlined.Storefront, null)
                        Tab.Library -> Icon(if (selected) Icons.Filled.GridView else Icons.Outlined.GridView, null)
                        Tab.Community -> Icon(if (selected) Icons.Filled.Groups else Icons.Outlined.Groups, null)
                        Tab.Profile -> Box(
                            Modifier
                                .size(24.dp)
                                .border(if (selected) 2.dp else 1.dp, if (selected) Steam.accent else Steam.statusOnline.copy(alpha = 0.7f), RoundedCornerShape(5.dp))
                                .padding(2.dp)
                                .clip(RoundedCornerShape(3.dp)),
                        ) { Avatar(user.avatarUrl, 20.dp) }
                    }
                },
                label = {
                    Text(
                        tabLabel(tab, app),
                        style = SteamType.tabLabel.copy(fontSize = 11.sp, letterSpacing = 0.08.em),
                        maxLines = 1,
                    )
                },
                colors = itemColors,
                modifier = Modifier.focusRequester(app.tabFocus.getValue(tab)),
            )
        }
        if (controllerPresent) ShoulderGlyph("RB", Modifier.align(Alignment.CenterVertically).padding(end = 6.dp))
    }
}

private fun tabLabel(tab: Tab, app: AppState): String = when (tab) {
    Tab.Store -> "STORE"
    Tab.Library -> "LIBRARY"
    Tab.Community -> "COMMUNITY"
    Tab.Profile -> app.index.snapshot.user.personaName.uppercase()
}

// ---------------------------------------------------------------------------
// Regular / expanded: Steam-desktop top nav bar
// ---------------------------------------------------------------------------

@Composable
private fun RegularShell(
    app: AppState,
    controllers: Map<Tab, NavHostController>,
    width: WidthClass,
    gamepad: Boolean,
    controllerPresent: Boolean,
    canGoBack: Boolean,
) {
    val navInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize()) {
        SteamTopBar(app, controllerPresent)
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            CompositionLocalProvider(
                LocalShell provides ShellInfo(width, bottomInset = if (gamepad) 0.dp else navInset),
            ) {
                TabContent(app, controllers, Modifier.widthIn(max = 1600.dp).fillMaxSize())
            }
        }
        AnimatedVisibility(gamepad, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
            ButtonHintsBar(app.tab, canGoBack, compact = false, modifier = Modifier.navigationBarsPadding())
        }
    }
}

@Composable
private fun SteamTopBar(app: AppState, controllerPresent: Boolean) {
    val user = app.index.snapshot.user
    val friends = app.index.snapshot.friends
    val online = friends.count { it.status != "offline" }
    Column(Modifier.fillMaxWidth().background(Steam.bgChrome).statusBarsPadding()) {
        Row(
            Modifier.fillMaxWidth().height(60.dp).padding(horizontal = 24.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.SportsEsports, null, tint = Steam.accentLink, modifier = Modifier.size(26.dp))
            Spacer(Modifier.width(10.dp))
            Wordmark(fontSize = 19)
            Spacer(Modifier.width(36.dp))
            if (controllerPresent) {
                ShoulderGlyph("LB")
                Spacer(Modifier.width(8.dp))
            }
            Tab.entries.forEach { tab -> TopTab(tab, app) }
            if (controllerPresent) {
                Spacer(Modifier.width(8.dp))
                ShoulderGlyph("RB")
            }
            Spacer(Modifier.weight(1f))
            TopIconButton(Icons.Filled.Search, "Search") {
                val target = if (app.tab == Tab.Library) Tab.Library else Tab.Store
                app.select(target)
                app.requestSearch(target)
            }
            Spacer(Modifier.width(8.dp))
            Row(
                Modifier
                    .steamFocusable(onClick = { app.select(Tab.Community) }, corner = 4.dp, focusScale = 1f, hoverLift = false)
                    .height(40.dp)
                    .padding(horizontal = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.People, "Friends", tint = Steam.textBody, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(6.dp))
                Text("$online online", style = MaterialTheme.typography.labelLarge, color = Steam.statusOnline)
            }
            Spacer(Modifier.width(12.dp))
            Row(
                Modifier
                    .steamFocusable(onClick = { app.select(Tab.Profile) }, corner = 4.dp, focusScale = 1f, hoverLift = false)
                    .height(44.dp)
                    .padding(horizontal = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(user.avatarUrl, 34.dp, status = user.status)
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(user.personaName, style = MaterialTheme.typography.labelLarge, color = Steam.statusOnline)
                    Text("Online", style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary)
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Color.Black.copy(alpha = 0.35f)))
    }
}

@Composable
private fun TopTab(tab: Tab, app: AppState) {
    val selected = app.tab == tab
    Box(
        Modifier
            .focusRequester(app.tabFocus.getValue(tab))
            .steamFocusable(
                onClick = {
                    if (selected) {
                        val nav = app.controllers.getValue(tab)
                        while (nav.previousBackStackEntry != null) nav.popBackStack()
                    } else {
                        app.select(tab)
                    }
                },
                corner = 4.dp,
                focusScale = 1f,
                hoverLift = false,
                role = androidx.compose.ui.semantics.Role.Tab,
            )
            .height(60.dp)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Label with the 3 dp accent underline sized to the text.
        Column(Modifier.width(IntrinsicSize.Max), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(9.dp))
            Text(
                tabLabel(tab, app),
                style = SteamType.tabLabel.copy(fontSize = 15.sp),
                color = if (selected) Steam.textTitle else Steam.textSecondary,
                maxLines = 1,
            )
            Spacer(Modifier.height(6.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(if (selected) Steam.accent else Color.Transparent, RoundedCornerShape(2.dp)),
            )
        }
    }
}

@Composable
private fun TopIconButton(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier
            .steamFocusable(onClick = onClick, corner = 20.dp, focusScale = 1.06f, hoverLift = false)
            .size(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, description, tint = Steam.textBody, modifier = Modifier.size(22.dp))
    }
}

// ---------------------------------------------------------------------------
// Gamepad hints (Big Picture style)
// ---------------------------------------------------------------------------

@Composable
fun ButtonHintsBar(tab: Tab, canGoBack: Boolean, compact: Boolean, modifier: Modifier = Modifier) {
    val actions = LocalFocusedActions.current
    Row(
        Modifier
            .fillMaxWidth()
            .background(Steam.bgChrome.copy(alpha = 0.95f))
            .then(modifier)
            .height(if (compact) 44.dp else 48.dp)
            .padding(horizontal = if (compact) 12.dp else 28.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 16.dp else 26.dp),
    ) {
        Hint(FaceButton.A, "Select")
        Hint(FaceButton.B, "Back")
        if (tab == Tab.Store || tab == Tab.Library) Hint(FaceButton.Y, "Search")
        when (tab) {
            Tab.Library -> Hint(FaceButton.X, "Favorite")
            Tab.Store -> Hint(FaceButton.X, "Wishlist")
            else -> {}
        }
        // On compact the LB / RB glyphs already flank the bottom tab bar right below.
        if (!compact) {
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically) {
                ShoulderGlyph("LB")
                Spacer(Modifier.width(4.dp))
                ShoulderGlyph("RB")
                Spacer(Modifier.width(8.dp))
                Text("Switch tab", style = MaterialTheme.typography.labelLarge, color = Steam.textBody)
            }
        }
    }
}

enum class FaceButton(val letter: String, val color: Color, val letterColor: Color) {
    A("A", Color(0xFF5FAF38), Color.White),
    B("B", Color(0xFFD9453D), Color.White),
    X("X", Color(0xFF2F7FD6), Color.White),
    Y("Y", Color(0xFFE8B923), Color(0xFF1B1B1B)),
}

@Composable
private fun Hint(button: FaceButton, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        FaceGlyph(button)
        Spacer(Modifier.width(6.dp))
        Text(label, style = MaterialTheme.typography.labelLarge, color = Steam.textBody, maxLines = 1)
    }
}

@Composable
fun FaceGlyph(button: FaceButton, modifier: Modifier = Modifier) {
    Box(
        modifier.size(22.dp).background(button.color, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(button.letter, color = button.letterColor, fontSize = 12.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
fun ShoulderGlyph(label: String, modifier: Modifier = Modifier) {
    Box(
        modifier
            .height(20.dp)
            .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp, bottomStart = 4.dp, bottomEnd = 4.dp))
            .padding(horizontal = 7.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, color = Steam.textTitle, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.04.em)
    }
}

// ---------------------------------------------------------------------------
// Transient confirmation toast
// ---------------------------------------------------------------------------

@Composable
private fun MessageToast(app: AppState, modifier: Modifier = Modifier) {
    var message by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(app) {
        app.messages.collect {
            message = it
            delay(2200)
            message = null
        }
    }
    AnimatedVisibility(message != null, modifier = modifier, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
        Box(
            Modifier
                .background(Steam.surfaceHover, RoundedCornerShape(6.dp))
                .border(1.dp, Steam.accent.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Text(message.orEmpty(), color = Steam.textTitle, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
