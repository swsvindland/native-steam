package dev.nativesteam.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.theme.Steam

/**
 * Root screen of a tab. Compact: Material large collapsing title over the page gradient.
 * Regular: no title (the top nav bar names the tab), content starts right away.
 */
@Composable
fun HomeScaffold(
    title: String,
    background: Brush,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    val shell = LocalShell.current
    if (shell.compact) {
        val behavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
        Column(
            Modifier
                .fillMaxSize()
                .background(background)
                .nestedScroll(behavior.nestedScrollConnection),
        ) {
            LargeTopAppBar(
                title = {
                    Text(
                        title,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.01).em,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    Row(Modifier.padding(start = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.SportsEsports, null, tint = Steam.accentLink, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.width(8.dp))
                        Wordmark(fontSize = 16)
                    }
                },
                actions = actions,
                expandedHeight = 124.dp,
                scrollBehavior = behavior,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    scrolledContainerColor = Steam.bgChrome,
                    titleContentColor = Steam.textTitle,
                    actionIconContentColor = Steam.textBody,
                ),
            )
            Box(Modifier.weight(1f)) { content(PaddingValues(bottom = 24.dp)) }
        }
    } else {
        Box(Modifier.fillMaxSize().background(background)) {
            content(PaddingValues(top = 8.dp, bottom = shell.bottomInset + 32.dp))
        }
    }
}

/** 48 dp icon action for top app bars. */
@Composable
fun BarAction(icon: ImageVector, description: String, tint: Color = Steam.textBody, onClick: () -> Unit) {
    Box(
        Modifier
            .steamFocusable(onClick = onClick, corner = 24.dp, focusScale = 1.06f, hoverLift = false)
            .size(48.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, description, tint = tint, modifier = Modifier.size(24.dp))
    }
}

/**
 * Floating back button for detail pages whose hero art runs under the status bar.
 */
@Composable
fun BoxScope.DetailBackButton(onBack: () -> Unit, visible: Boolean = true) {
    if (!visible) return
    val shell = LocalShell.current
    Box(
        Modifier
            .align(Alignment.TopStart)
            .then(if (shell.compact) Modifier.statusBarsPadding() else Modifier)
            .padding(start = 8.dp, top = 8.dp)
            .steamFocusable(onClick = onBack, corner = 24.dp, focusScale = 1.08f, hoverLift = false)
            .background(Color.Black.copy(alpha = 0.45f))
            .size(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Color.White, modifier = Modifier.size(22.dp))
    }
}

/** Solid top bar that fades in once the hero has scrolled away. */
@Composable
fun BoxScope.CollapsedDetailBar(title: String, progressProvider: () -> Float, onBack: () -> Unit) {
    // Read here (not in the caller) so only this bar recomposes while scrolling.
    val progress = progressProvider()
    if (progress <= 0.01f) return
    val shell = LocalShell.current
    Row(
        Modifier
            .align(Alignment.TopStart)
            .fillMaxWidth()
            .background(Steam.bgChrome.copy(alpha = 0.97f * progress))
            .then(if (shell.compact) Modifier.statusBarsPadding() else Modifier)
            .height(60.dp)
            .padding(start = 60.dp, end = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            color = Steam.textTitle.copy(alpha = progress),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun ColumnScope.Gap(h: Int) = Spacer(Modifier.height(h.dp))

@Composable
fun RowScope.HGap(w: Int) = Spacer(Modifier.width(w.dp))

/** Height of the status bar, for screens whose art runs edge-to-edge under it. */
@Composable
fun statusBarHeight() = with(androidx.compose.ui.platform.LocalDensity.current) {
    WindowInsets.statusBars.getTop(this).toDp()
}
