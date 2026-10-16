package dev.nativesteam.android.ui.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import dev.nativesteam.android.data.SnapshotIndex
import dev.nativesteam.android.ui.input.LocalInputState
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.serialization.Serializable

enum class Tab { Store, Library, Community, Profile }

// Navigation routes (type-safe Navigation Compose). Each tab owns its own NavHost / back stack.
@Serializable data object StoreHome
@Serializable data object LibraryHome
@Serializable data object CommunityHome
@Serializable data object ProfileHome
@Serializable data class AppRoute(val appId: Int)
@Serializable data class GameRoute(val appId: Int)
@Serializable data object FriendsRoute

/** Width buckets from DESIGN.md §2 (compact < 700 ≤ regular; sidebar ≥ 1000; rail ≥ 1100). */
enum class WidthClass {
    Compact, Regular, Expanded, Wide;

    val isCompact get() = this == Compact
    val hasSidebar get() = this >= Expanded
    val hasRail get() = this == Wide
}

/** Layout facts a screen needs from the adaptive shell. */
data class ShellInfo(
    val width: WidthClass,
    /** Extra bottom padding content should leave (system nav bar / hints bar) on regular layouts. */
    val bottomInset: Dp = 0.dp,
) {
    val compact get() = width.isCompact
    val gutter: Dp get() = if (compact) 16.dp else 28.dp
}

/** Launch options passed as intent extras (screenshot automation). */
data class LaunchRequest(
    val tab: Tab? = null,
    val gameId: Int? = null,
    val appId: Int? = null,
    val gamepad: Boolean = false,
    val nonce: Long = System.nanoTime(),
)

@Stable
class AppState(val index: SnapshotIndex) {
    var tab by mutableStateOf(Tab.Store)

    /** In-memory favourites / wishlist (X button, star buttons). Seeded from the snapshot. */
    val favorites = mutableStateMapOf<Int, Boolean>().apply {
        index.snapshot.library.games.forEach { put(it.appId, it.favorite) }
    }
    val wishlist = mutableStateListOf<Int>()

    /** Bumped to ask the visible screen to put focus on its first item (gamepad / keyboard). */
    var contentFocusRequest by mutableIntStateOf(0)
        private set

    /** Bumped to focus the search field of [searchTab]. */
    var searchRequest by mutableIntStateOf(0)
        private set
    var searchTab by mutableStateOf(Tab.Store)
        private set

    /** LT / RT paging requests (Library collections, Community sections). */
    val pageEvents = MutableSharedFlow<Int>(extraBufferCapacity = 8)

    /** Short confirmations ("Added to your wishlist"). */
    val messages = MutableSharedFlow<String>(extraBufferCapacity = 4)

    /** Routes to push once a tab's NavHost is ready (intent extras). */
    val pendingRoutes = mutableStateMapOf<Tab, Any>()

    lateinit var controllers: Map<Tab, NavHostController>
    val tabFocus: Map<Tab, FocusRequester> = Tab.entries.associateWith { FocusRequester() }

    fun isFavorite(appId: Int) = favorites[appId] == true
    fun isWishlisted(appId: Int) = appId in wishlist

    fun toggleFavorite(appId: Int) {
        val name = index.libraryGame(appId)?.name ?: return
        val now = !isFavorite(appId)
        favorites[appId] = now
        messages.tryEmit(if (now) "Added $name to Favorites" else "Removed $name from Favorites")
    }

    fun toggleWishlist(appId: Int) {
        val name = index.storeItem(appId)?.name ?: return
        if (isWishlisted(appId)) {
            wishlist.remove(appId)
            messages.tryEmit("Removed $name from your wishlist")
        } else {
            wishlist.add(appId)
            messages.tryEmit("Added $name to your wishlist")
        }
    }

    fun requestContentFocus() {
        contentFocusRequest++
    }

    fun requestSearch(tab: Tab) {
        searchTab = tab
        searchRequest++
    }

    fun select(tab: Tab) {
        this.tab = tab
    }
}

val LocalAppState = staticCompositionLocalOf<AppState> { error("AppState not provided") }
val LocalShell = staticCompositionLocalOf { ShellInfo(WidthClass.Compact) }

/** Per-tab navigation actions. */
class Navigator(private val nav: NavHostController, private val app: AppState) {
    fun openApp(appId: Int) = nav.navigate(AppRoute(appId)) { launchSingleTop = true }
    fun openGame(appId: Int) = nav.navigate(GameRoute(appId)) { launchSingleTop = true }

    /** Owned games open their library page, everything else its store page. */
    fun openTitle(appId: Int) = if (app.index.owns(appId)) openGame(appId) else openApp(appId)
    fun openFriends() = nav.navigate(FriendsRoute) { launchSingleTop = true }
    fun back() = nav.popBackStack()
    val canGoBack: Boolean get() = nav.previousBackStackEntry != null
}

val LocalNavigator = staticCompositionLocalOf<Navigator> { error("Navigator not provided") }

/**
 * Puts focus on [requester] whenever the shell asks for it (gamepad launch, tab switch with
 * LB/RB, B to go back) and the user is on keyboard/gamepad.
 */
@Composable
fun InitialFocus(requester: FocusRequester) {
    val app = LocalAppState.current
    val input = LocalInputState.current
    val nonce = app.contentFocusRequest
    LaunchedEffect(nonce) {
        if (nonce == 0 || !input.mode.showsFocus) return@LaunchedEffect
        delay(120)
        repeat(8) {
            if (runCatching { requester.requestFocus() }.getOrDefault(false) == true) return@LaunchedEffect
            delay(120)
        }
    }
}
