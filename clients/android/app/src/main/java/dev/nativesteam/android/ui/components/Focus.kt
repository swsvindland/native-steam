package dev.nativesteam.android.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import dev.nativesteam.android.ui.input.InputMode
import dev.nativesteam.android.ui.input.LocalFocusedActions
import dev.nativesteam.android.ui.input.LocalInputState
import dev.nativesteam.android.ui.theme.Steam
import kotlin.math.max
import kotlin.math.min

private val EaseOut = CubicBezierEasing(0.2f, 0f, 0f, 1f)

/** Interaction state a [steamFocusable] element exposes to its content. */
@Stable
class FocusVisualState {
    /** Focused and the user is on keyboard/gamepad, i.e. the ring is showing. */
    var focusVisible by mutableStateOf(false)
        internal set

    /** Mouse pointer over the element. */
    var hovered by mutableStateOf(false)
        internal set

    var pressed by mutableStateOf(false)
        internal set

    /** Show the name / extra info: hovered with a mouse or focused with keys. */
    val emphasised: Boolean get() = focusVisible || hovered
}

/**
 * The one interaction modifier used by every card, row, chip and button in the app.
 *
 * - **Keyboard / gamepad**: focusable; when focused draws the Native Steam focus treatment
 *   (scale [focusScale], 2 dp white inner ring, 4 dp accent glow at 55%, brightened content)
 *   with a 120 ms ease-out. Registers itself so the shell can route gamepad A / X to it.
 * - **Mouse**: hover lift + highlight.
 * - **Touch**: ripple press feedback.
 */
@Composable
fun Modifier.steamFocusable(
    onClick: () -> Unit,
    corner: Dp = 6.dp,
    focusScale: Float = 1.04f,
    onSecondary: (() -> Unit)? = null,
    focusRequester: FocusRequester? = null,
    state: FocusVisualState? = null,
    hoverLift: Boolean = true,
    role: Role = Role.Button,
    rippleColor: Color = Color.White,
    enabled: Boolean = true,
): Modifier {
    val input = LocalInputState.current
    val actions = LocalFocusedActions.current
    val visual = state ?: remember { FocusVisualState() }
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()
    val pressed by interaction.collectIsPressedAsState()
    var focused by remember { mutableStateOf(false) }
    val showFocus = focused && input.mode.showsFocus
    val mouseHover = hovered && input.mode == InputMode.Mouse
    visual.focusVisible = showFocus
    visual.hovered = mouseHover
    visual.pressed = pressed

    val ring by animateFloatAsState(if (showFocus) 1f else 0f, tween(120, easing = EaseOut), label = "ring")
    val scale by animateFloatAsState(
        when {
            showFocus -> focusScale
            pressed && input.mode == InputMode.Touch -> 0.98f
            else -> 1f
        },
        tween(120, easing = EaseOut),
        label = "scale",
    )
    val lift by animateDpAsState(if (mouseHover && hoverLift) (-3).dp else 0.dp, tween(120, easing = EaseOut), label = "lift")
    val hoverGlow by animateFloatAsState(if (mouseHover) 1f else 0f, tween(120), label = "hover")

    val click by rememberUpdatedState(onClick)
    val secondary by rememberUpdatedState(onSecondary)
    val token = remember { Any() }
    DisposableEffect(actions) { onDispose { actions.unregister(token) } }

    val shape = RoundedCornerShape(corner)
    return this
        .zIndex(if (showFocus) 2f else if (mouseHover) 1f else 0f)
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
            translationY = lift.toPx()
        }
        .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
        .onFocusChanged {
            focused = it.isFocused
            if (it.isFocused) {
                actions.register(token, { click() }, if (secondary != null) ({ secondary?.invoke() }) else null)
            } else {
                actions.unregister(token)
            }
        }
        .drawWithContent {
            drawContent()
            val r = min(corner.toPx(), size.minDimension / 2f)
            if (hoverGlow > 0f) {
                drawRoundRect(Color.White.copy(alpha = 0.06f * hoverGlow), cornerRadius = CornerRadius(r))
            }
            if (ring > 0f) {
                // Brighter artwork.
                drawRoundRect(Color.White.copy(alpha = 0.07f * ring), cornerRadius = CornerRadius(r))
                // Soft outer glow, then the 4 dp accent @ 55% band hugging the edge.
                val soft = 9.dp.toPx()
                drawRoundRect(
                    color = Steam.accent.copy(alpha = 0.16f * ring),
                    topLeft = Offset(-soft / 2f - 2.dp.toPx(), -soft / 2f - 2.dp.toPx()),
                    size = Size(size.width + soft + 4.dp.toPx(), size.height + soft + 4.dp.toPx()),
                    cornerRadius = CornerRadius(r + soft / 2f + 2.dp.toPx()),
                    style = Stroke(soft),
                )
                val glow = 4.dp.toPx()
                drawRoundRect(
                    color = Steam.accent.copy(alpha = 0.55f * ring),
                    topLeft = Offset(-glow / 2f, -glow / 2f),
                    size = Size(size.width + glow, size.height + glow),
                    cornerRadius = CornerRadius(r + glow / 2f),
                    style = Stroke(glow),
                )
                // 2 dp white inner ring.
                val inner = 2.dp.toPx()
                drawRoundRect(
                    color = Color.White.copy(alpha = ring),
                    topLeft = Offset(inner / 2f, inner / 2f),
                    size = Size(size.width - inner, size.height - inner),
                    cornerRadius = CornerRadius(max(0f, r - inner / 2f)),
                    style = Stroke(inner),
                )
            }
        }
        .clip(shape)
        .clickable(
            interactionSource = interaction,
            indication = ripple(color = rippleColor),
            enabled = enabled,
            role = role,
            onClick = onClick,
        )
}

/**
 * A focusable card surface whose background turns `surfaceHover` on mouse hover and
 * keyboard focus, as Steam's desktop client does.
 */
@Composable
fun SteamCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = Steam.surface,
    corner: Dp = 6.dp,
    focusScale: Float = 1.04f,
    onSecondary: (() -> Unit)? = null,
    focusRequester: FocusRequester? = null,
    state: FocusVisualState = remember { FocusVisualState() },
    content: @Composable BoxScope.(FocusVisualState) -> Unit,
) {
    val bg by animateColorAsState(
        if (state.hovered || state.focusVisible) Steam.surfaceHover else color,
        tween(120),
        label = "cardBg",
    )
    Box(
        modifier
            .steamFocusable(
                onClick = onClick,
                corner = corner,
                focusScale = focusScale,
                onSecondary = onSecondary,
                focusRequester = focusRequester,
                state = state,
            )
            .background(bg),
    ) {
        content(state)
    }
}

/**
 * Keeps the focused card fully visible with roughly one card of lookahead when moving
 * through a horizontal shelf with a D-pad (DESIGN.md §3).
 */
class ShelfBringIntoViewSpec(private val lookaheadFraction: Float = 1f) : BringIntoViewSpec {
    override fun calculateScrollDistance(offset: Float, size: Float, containerSize: Float): Float {
        val lookahead = min(size * lookaheadFraction, max(0f, (containerSize - size) / 2f))
        val trailing = offset + size
        return when {
            offset < lookahead -> offset - lookahead
            trailing > containerSize - lookahead -> trailing - (containerSize - lookahead)
            else -> 0f
        }
    }
}

/**
 * For stock Material components (segmented buttons, nav bar items) that keep their own focus
 * visuals: lets the shell's gamepad A button activate them while they hold focus.
 */
@Composable
fun Modifier.gamepadActivatable(onActivate: () -> Unit): Modifier {
    val actions = LocalFocusedActions.current
    val token = remember { Any() }
    val current by rememberUpdatedState(onActivate)
    DisposableEffect(actions) { onDispose { actions.unregister(token) } }
    return this.onFocusChanged {
        if (it.isFocused) actions.register(token, { current() }, null) else actions.unregister(token)
    }
}

/**
 * Fades the element (artwork + its scrims) to transparent towards the bottom so hero art
 * dissolves into whatever page gradient is behind it, with no seam.
 */
fun Modifier.fadeOutBottom(from: Float = 0.55f): Modifier = this
    .graphicsLayer(compositingStrategy = androidx.compose.ui.graphics.CompositingStrategy.Offscreen)
    .drawWithContent {
        drawContent()
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.verticalGradient(from to Color.Black, 1f to Color.Transparent),
            blendMode = androidx.compose.ui.graphics.BlendMode.DstIn,
        )
    }
