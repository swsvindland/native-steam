package dev.nativesteam.android

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import dev.nativesteam.android.data.SnapshotIndex
import dev.nativesteam.android.data.SnapshotRepository
import dev.nativesteam.android.ui.input.FocusedActions
import dev.nativesteam.android.ui.input.InputState
import dev.nativesteam.android.ui.input.KeyRouter
import dev.nativesteam.android.ui.input.LocalFocusedActions
import dev.nativesteam.android.ui.input.LocalInputState
import dev.nativesteam.android.ui.shell.LaunchRequest
import dev.nativesteam.android.ui.shell.NativeSteamShell
import dev.nativesteam.android.ui.shell.Tab
import dev.nativesteam.android.ui.theme.NativeSteamTheme
import dev.nativesteam.android.ui.theme.Steam

/**
 * Single activity. Intent extras (used by the screenshot scripts):
 *  --es tab store|library|community|profile
 *  --ei game <appId>   open the library game page
 *  --ei app <appId>    open the store app page
 *  --es input gamepad  pretend a controller is in use (hints bar + focus on the first item)
 */
class MainActivity : ComponentActivity() {
    private lateinit var input: InputState
    private val keyRouter = KeyRouter()
    private var launch by mutableStateOf<LaunchRequest?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        input = InputState(this)
        if (savedInstanceState == null) launch = intent.toLaunchRequest()

        setContent {
            NativeSteamTheme {
                val actions = remember { FocusedActions() }
                CompositionLocalProvider(LocalInputState provides input, LocalFocusedActions provides actions) {
                    val index by produceState<SnapshotIndex?>(null) {
                        value = SnapshotIndex(SnapshotRepository.load(applicationContext))
                    }
                    Box(Modifier.fillMaxSize().background(Steam.bgChrome)) {
                        index?.let { NativeSteamShell(it, launch, keyRouter) }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launch = intent.toLaunchRequest()
    }

    override fun onDestroy() {
        input.dispose()
        super.onDestroy()
    }

    // Every event passes through here first: remember which kind of device the user last used.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        input.onKeyEvent(event)
        if (keyRouter.beforeCompose?.invoke(event) == true) return true
        if (super.dispatchKeyEvent(event)) return true
        return keyRouter.unhandled?.invoke(event) ?: false
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        input.onMotionEvent(event)
        return super.dispatchGenericMotionEvent(event)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        input.onMotionEvent(event)
        return super.dispatchTouchEvent(event)
    }
}

private fun Intent.toLaunchRequest(): LaunchRequest? {
    val tab = when (getStringExtra("tab")?.lowercase()) {
        "store" -> Tab.Store
        "library" -> Tab.Library
        "community" -> Tab.Community
        "profile", "user", "kestrel" -> Tab.Profile
        else -> null
    }
    val game = getIntExtra("game", -1).takeIf { it > 0 }
    val app = getIntExtra("app", -1).takeIf { it > 0 }
    val gamepad = getStringExtra("input")?.lowercase() == "gamepad"
    if (tab == null && game == null && app == null && !gamepad) return null
    return LaunchRequest(tab = tab, gameId = game, appId = app, gamepad = gamepad)
}
