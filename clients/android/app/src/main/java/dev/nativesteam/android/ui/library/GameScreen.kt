package dev.nativesteam.android.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.nativesteam.android.data.Achievement
import dev.nativesteam.android.data.LibraryGame
import dev.nativesteam.android.ui.components.Avatar
import dev.nativesteam.android.ui.components.CollapsedDetailBar
import dev.nativesteam.android.ui.components.DetailBackButton
import dev.nativesteam.android.ui.components.GradientButton
import dev.nativesteam.android.ui.components.InfoPill
import dev.nativesteam.android.ui.components.ProgressLine
import dev.nativesteam.android.ui.components.SecondaryButton
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.Shelf
import dev.nativesteam.android.ui.components.SteamCard
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.components.fadeOutBottom
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.store.ControllerBadge
import dev.nativesteam.android.ui.store.StoreAppScreen
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType

@Composable
fun GameScreen(appId: Int) {
    val app = LocalAppState.current
    val game = remember(appId) { app.index.libraryGame(appId) }
    if (game == null) {
        // Not owned: show its store page instead.
        StoreAppScreen(appId)
        return
    }
    GameContent(game)
}

@Composable
private fun GameContent(game: LibraryGame) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val scroll = rememberScrollState()
    val primary = remember { FocusRequester() }
    InitialFocus(primary)
    val gutter = shell.gutter
    val heroHeight = if (shell.compact) 300.dp else 380.dp
    val density = LocalDensity.current
    val collapseStart = with(density) { (heroHeight - 140.dp).toPx() }
    val collapseRange = with(density) { 60.dp.toPx() }
    val favorite = app.isFavorite(game.appId)

    Box(Modifier.fillMaxSize().background(Steam.libraryBackground)) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scroll)
                .padding(bottom = shell.bottomInset + 32.dp),
        ) {
            // Hero: full-bleed library art with the logo, fading into the page.
            Box(Modifier.fillMaxWidth().height(heroHeight).clipToBounds()) {
                Box(Modifier.fillMaxSize().fadeOutBottom(0.6f)) {
                    SteamImage(
                        game.images.hero ?: game.images.capsule,
                        Modifier.fillMaxSize().graphicsLayer { translationY = scroll.value * 0.45f },
                        transparent = true,
                    )
                    Box(
                        Modifier.fillMaxSize().background(
                            Brush.verticalGradient(
                                0f to Color.Black.copy(alpha = 0.35f),
                                0.25f to Color.Transparent,
                            ),
                        ),
                    )
                }
                GameLogo(
                    game.images.logo,
                    game.name,
                    Modifier
                        .align(Alignment.BottomStart)
                        .padding(start = gutter, bottom = 20.dp)
                        .fillMaxWidth(if (shell.compact) 0.62f else 0.36f)
                        .height(if (shell.compact) 96.dp else 130.dp),
                    fontSize = 30,
                )
            }

            Column(Modifier.padding(horizontal = gutter)) {
                ActionRow(game, favorite, primary)
                Spacer(Modifier.height(18.dp))
                StatsRow(game)
                if (game.updateAvailable) {
                    Spacer(Modifier.height(14.dp))
                    UpdateBanner()
                }
            }

            val achievements = game.achievements
            if (achievements != null && achievements.highlighted.isNotEmpty()) {
                Spacer(Modifier.height(24.dp))
                SectionHeader(
                    "Achievements",
                    count = "${achievements.unlocked} of ${achievements.total}",
                    modifier = Modifier.padding(horizontal = gutter),
                )
                Shelf(gutter = gutter, spacing = 10.dp) {
                    items(achievements.highlighted, key = { it.name }) { a -> AchievementTile(a) }
                }
            }

            val friends = game.friendsPlaying.mapNotNull { app.index.friend(it) }
            if (friends.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                SectionHeader("Friends who play", count = "${friends.size}", modifier = Modifier.padding(horizontal = gutter))
                Shelf(gutter = gutter, spacing = 10.dp) {
                    items(friends, key = { it.steamId }) { f ->
                        SteamCard(onClick = { nav.openFriends() }, color = Steam.surfaceNeutral, focusScale = 1.03f) {
                            Row(
                                Modifier.width(196.dp).padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Avatar(f.avatarUrl, 42.dp, status = f.status)
                                Spacer(Modifier.width(10.dp))
                                Column {
                                    Text(f.personaName, color = Steam.statusColor(f.status), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    Text(f.statusLabel, color = Steam.textSecondary, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                }
                            }
                        }
                    }
                }
            }

            if (game.screenshots.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                SectionHeader("Screenshots", Modifier.padding(horizontal = gutter))
                Shelf(gutter = gutter) {
                    itemsIndexed(game.screenshots, key = { i, s -> "$i-${s.thumbnail}" }) { _, s ->
                        Box(
                            Modifier
                                .width(if (shell.compact) 260.dp else 320.dp)
                                .aspectRatio(16f / 9f)
                                .steamFocusable(onClick = {}, corner = 6.dp),
                        ) {
                            SteamImage(s.thumbnail, Modifier.fillMaxSize(), placeholderColor = Steam.surfaceNeutral)
                        }
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Column(Modifier.padding(horizontal = gutter).widthIn(max = 860.dp)) {
                SectionHeader("About")
                game.shortDescription?.let {
                    Text(it, style = MaterialTheme.typography.bodyLarge, color = Steam.textBody)
                    Spacer(Modifier.height(14.dp))
                }
                AboutFact("Developer", game.developers.joinToString(", ").ifEmpty { "—" })
                AboutFact("Release date", game.releaseDate ?: "—")
                AboutFact("Size on disk", if (game.installed) game.sizeLabel else "${game.sizeLabel} (not installed)")
                if (game.genres.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        game.genres.forEach { InfoPill(it) }
                    }
                }
                Spacer(Modifier.height(12.dp))
                ControllerBadge(game.controllerSupport)
            }
        }

        CollapsedDetailBar(game.name, { ((scroll.value - collapseStart) / collapseRange).coerceIn(0f, 1f) }) { nav.back() }
        DetailBackButton(onBack = { nav.back() })
    }
}

@Composable
private fun ActionRow(game: LibraryGame, favorite: Boolean, primary: FocusRequester) {
    val app = LocalAppState.current
    val shell = LocalShell.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (game.installed) {
            GradientButton(
                "PLAY",
                Steam.playGradient,
                onClick = {},
                icon = Icons.Filled.PlayArrow,
                height = 52.dp,
                focusRequester = primary,
                onSecondary = { app.toggleFavorite(game.appId) },
                modifier = if (shell.compact) Modifier.weight(1f) else Modifier.width(220.dp),
            )
        } else {
            GradientButton(
                "INSTALL",
                Steam.installGradient,
                onClick = {},
                icon = Icons.Filled.Download,
                height = 52.dp,
                focusRequester = primary,
                onSecondary = { app.toggleFavorite(game.appId) },
                modifier = if (shell.compact) Modifier.weight(1f) else Modifier.width(220.dp),
            )
        }
        if (!game.installed) {
            Spacer(Modifier.width(12.dp))
            Column {
                Text("SIZE", style = SteamType.caption)
                Text(game.sizeLabel, style = MaterialTheme.typography.titleSmall, color = Steam.textBody)
            }
        }
        if (!shell.compact) Spacer(Modifier.weight(1f)) else Spacer(Modifier.width(10.dp))
        SecondaryButton(
            text = null,
            icon = if (favorite) Icons.Filled.Star else Icons.Outlined.StarBorder,
            iconTint = if (favorite) Color(0xFFFFD34E) else Steam.textBody,
            contentDescription = "Favorite",
            onClick = { app.toggleFavorite(game.appId) },
            height = 52.dp,
        )
        Spacer(Modifier.width(8.dp))
        SecondaryButton(text = null, icon = Icons.Outlined.Settings, contentDescription = "Properties", onClick = {}, height = 52.dp)
        Spacer(Modifier.width(8.dp))
        SecondaryButton(text = null, icon = Icons.Outlined.Info, contentDescription = "Game info", onClick = {}, height = 52.dp)
    }
}

@Composable
private fun StatsRow(game: LibraryGame) {
    val shell = LocalShell.current
    Row(
        Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.22f), RoundedCornerShape(6.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(if (shell.compact) 12.dp else 40.dp),
        verticalAlignment = Alignment.Top,
    ) {
        // Play time labels ("38.4 hrs on record") are the longest, so they get the widest column.
        Stat("Last played", game.lastPlayedLabel, Modifier.weight(0.85f, fill = shell.compact))
        Stat("Play time", game.playtimeLabel, Modifier.weight(1.35f, fill = shell.compact))
        val a = game.achievements
        Column(Modifier.weight(0.9f, fill = shell.compact)) {
            Text("ACHIEVEMENTS", style = SteamType.caption, maxLines = 1)
            Spacer(Modifier.height(3.dp))
            Text(
                if (a != null) "${a.unlocked}/${a.total}" else "None",
                style = MaterialTheme.typography.titleSmall,
                color = Steam.textTitle,
            )
            if (a != null) {
                Spacer(Modifier.height(6.dp))
                ProgressLine(a.fraction, Modifier.widthIn(max = 180.dp))
            }
        }
    }
}

@Composable
private fun Stat(caption: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(caption.uppercase(), style = SteamType.caption, maxLines = 1)
        Spacer(Modifier.height(3.dp))
        Text(value, style = MaterialTheme.typography.titleSmall, color = Steam.textTitle, maxLines = 2)
    }
}

@Composable
private fun UpdateBanner() {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Steam.accent.copy(alpha = 0.14f), RoundedCornerShape(6.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(9.dp).background(Steam.accent, CircleShape))
        Spacer(Modifier.width(10.dp))
        Text("Update available — it will download when you press Play.", style = MaterialTheme.typography.bodyMedium, color = Steam.textBody)
    }
}

@Composable
private fun AchievementTile(a: Achievement) {
    Column(
        Modifier
            .width(88.dp)
            .steamFocusable(onClick = {}, corner = 6.dp, focusScale = 1.06f)
            .padding(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box {
            SteamImage(
                a.iconUrl,
                Modifier.size(64.dp).clip(RoundedCornerShape(4.dp)),
                contentDescription = a.name,
                placeholderColor = Steam.surfaceNeutral,
                grayscale = !a.unlocked,
                alpha = if (a.unlocked) 1f else 0.45f,
            )
            if (!a.unlocked) {
                Icon(
                    Icons.Filled.Lock,
                    "Locked",
                    tint = Steam.textBody,
                    modifier = Modifier.align(Alignment.BottomEnd).padding(3.dp).size(14.dp),
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            a.name,
            style = MaterialTheme.typography.labelSmall,
            color = if (a.unlocked) Steam.textBody else Steam.textMuted,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun AboutFact(label: String, value: String) {
    Row(Modifier.padding(vertical = 3.dp)) {
        Text(label.uppercase(), style = SteamType.caption, modifier = Modifier.width(120.dp).padding(top = 3.dp))
        Text(value, style = MaterialTheme.typography.bodyMedium, color = Steam.textBody, fontWeight = FontWeight.Normal)
    }
}
