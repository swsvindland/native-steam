package dev.nativesteam.android.ui.input

import android.content.Context
import android.hardware.input.InputManager
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import kotlin.math.abs

/**
 * The last input modality the user touched. The UI adapts to it (DESIGN.md §3):
 * focus rings only for keyboard/gamepad, hover only for mouse, hints bar only for gamepad.
 */
enum class InputMode {
    Touch, Mouse, Keyboard, Gamepad;

    val showsFocus: Boolean get() = this == Keyboard || this == Gamepad
}

/**
 * Tracks the last-used input by inspecting the [InputDevice] source of every event the
 * activity dispatches, and whether a game controller is connected at all.
 */
@Stable
class InputState(context: Context) : InputManager.InputDeviceListener {
    var mode by mutableStateOf(InputMode.Touch)
        private set

    /** True while any physical game controller is attached (or gamepad mode was forced). */
    var gamepadConnected by mutableStateOf(false)
        private set

    private var forced = false
    private val inputManager = context.getSystemService(InputManager::class.java)

    init {
        refreshControllers()
        inputManager?.registerInputDeviceListener(this, null)
    }

    /** Screenshot automation / demo: behave as if a controller was just used. */
    fun forceGamepad() {
        forced = true
        mode = InputMode.Gamepad
        gamepadConnected = true
    }

    fun onKeyEvent(event: KeyEvent) {
        if (event.action != KeyEvent.ACTION_DOWN) return
        mode = when {
            KeyEvent.isGamepadButton(event.keyCode) -> InputMode.Gamepad
            event.isFromSource(InputDevice.SOURCE_GAMEPAD) || event.isFromSource(InputDevice.SOURCE_JOYSTICK) -> InputMode.Gamepad
            // A controller's D-pad reports SOURCE_DPAD; tell it apart from a keyboard's arrows by the device.
            event.isFromSource(InputDevice.SOURCE_DPAD) && event.device.isController() -> InputMode.Gamepad
            else -> InputMode.Keyboard
        }
    }

    fun onMotionEvent(event: MotionEvent) {
        val next = when {
            event.isFromSource(InputDevice.SOURCE_JOYSTICK) || event.isFromSource(InputDevice.SOURCE_GAMEPAD) -> {
                // Ignore stick noise around the dead zone.
                val moved = abs(event.getAxisValue(MotionEvent.AXIS_X)) > 0.4f ||
                    abs(event.getAxisValue(MotionEvent.AXIS_Y)) > 0.4f ||
                    abs(event.getAxisValue(MotionEvent.AXIS_HAT_X)) > 0.5f ||
                    abs(event.getAxisValue(MotionEvent.AXIS_HAT_Y)) > 0.5f
                if (moved) InputMode.Gamepad else null
            }
            event.isFromSource(InputDevice.SOURCE_MOUSE) || event.isFromSource(InputDevice.SOURCE_TOUCHPAD) ||
                event.isFromSource(InputDevice.SOURCE_MOUSE_RELATIVE) -> InputMode.Mouse
            event.isFromSource(InputDevice.SOURCE_STYLUS) -> InputMode.Touch
            event.isFromSource(InputDevice.SOURCE_TOUCHSCREEN) -> {
                if (event.getToolType(0) == MotionEvent.TOOL_TYPE_MOUSE) InputMode.Mouse else InputMode.Touch
            }
            else -> null
        }
        if (next != null) mode = next
    }

    private fun refreshControllers() {
        val ids = InputDevice.getDeviceIds()
        gamepadConnected = forced || ids.any { InputDevice.getDevice(it).isController() }
    }

    override fun onInputDeviceAdded(deviceId: Int) = refreshControllers()
    override fun onInputDeviceRemoved(deviceId: Int) = refreshControllers()
    override fun onInputDeviceChanged(deviceId: Int) = refreshControllers()

    fun dispose() {
        inputManager?.unregisterInputDeviceListener(this)
    }
}

private fun InputDevice?.isController(): Boolean {
    if (this == null || isVirtual) return false
    val s = sources
    return (s and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
        (s and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
}

val LocalInputState = staticCompositionLocalOf<InputState> { error("InputState not provided") }

/**
 * Root-level gamepad activation: the focused card registers what A (activate) and X
 * (secondary: favourite / wishlist) do, and the shell's `onPreviewKeyEvent` invokes it.
 */
class FocusedActions {
    private var owner: Any? = null
    private var activate: (() -> Unit)? = null
    private var secondary: (() -> Unit)? = null

    fun register(owner: Any, activate: () -> Unit, secondary: (() -> Unit)?) {
        this.owner = owner
        this.activate = activate
        this.secondary = secondary
    }

    fun unregister(owner: Any) {
        if (this.owner === owner) {
            this.owner = null
            activate = null
            secondary = null
        }
    }

    fun activate(): Boolean = activate?.let { it(); true } ?: false
    fun secondary(): Boolean = secondary?.let { it(); true } ?: false
    val hasSecondary: Boolean get() = secondary != null
}

val LocalFocusedActions = staticCompositionLocalOf { FocusedActions() }

/**
 * Bridges the activity's key dispatch and the Compose shell so controller buttons work even
 * when nothing inside Compose holds focus (e.g. right after a touch, or after the focused card
 * left the screen):
 * - [beforeCompose] runs first: a D-pad press with nothing focused jumps into the page content
 *   instead of whatever Compose would pick at the top of the window.
 * - [unhandled] gets events no composable consumed (falls back to the shell's root handler).
 */
class KeyRouter {
    var beforeCompose: ((KeyEvent) -> Boolean)? = null
    var unhandled: ((KeyEvent) -> Boolean)? = null
}
