package dev.nativesteam.android.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cake
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.Edit
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
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.nativesteam.android.data.Badge
import dev.nativesteam.android.data.RecentGame
import dev.nativesteam.android.data.ShowcaseAchievement
import dev.nativesteam.android.data.UserProfile
import dev.nativesteam.android.ui.components.Avatar
import dev.nativesteam.android.ui.components.LevelRing
import dev.nativesteam.android.ui.components.ProgressLine
import dev.nativesteam.android.ui.components.SecondaryButton
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.Shelf
import dev.nativesteam.android.ui.components.SteamCard
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.components.statusBarHeight
import androidx.compose.ui.platform.LocalDensity
import dev.nativesteam.android.ui.components.fadeOutBottom
import dev.nativesteam.android.ui.library.GameLogo
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType
import java.text.NumberFormat
import java.util.Locale

@Composable
fun ProfileScreen() {
    val app = LocalAppState.current
    val shell = LocalShell.current
    val user = app.index.snapshot.user
    val scroll = rememberScrollState()
    val first = remember { FocusRequester() }
    InitialFocus(first)
    val gutter = shell.gutter

    Box(Modifier.fillMaxSize().background(Steam.libraryBackground)) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scroll)
                .padding(bottom = shell.bottomInset + 32.dp),
        ) {
            Banner(user, { scroll.value }, first)
            if (shell.width.hasSidebar) {
                Column(Modifier.padding(horizontal = gutter)) {
                    Summary(user)
                    Spacer(Modifier.height(20.dp))
                    StatsGrid(user, perRow = 7)
                    Spacer(Modifier.height(24.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(28.dp)) {
                        Column(Modifier.weight(1f)) {
                            FavoriteGame(user)
                            Spacer(Modifier.height(24.dp))
                            RecentActivity(user.recentGames)
                            Spacer(Modifier.height(24.dp))
                            ScreenshotShowcase(user)
                        }
                        Column(Modifier.width(360.dp)) {
                            SectionHeader("Badges", count = "${user.stats.badges}")
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                user.badges.forEach { BadgeMedallion(it) }
                            }
                            Spacer(Modifier.height(20.dp))
                            RareAchievementsGrid(user.rareAchievements)
                            Spacer(Modifier.height(20.dp))
                            FriendsPreview()
                        }
                    }
                }
            } else {
                Column(Modifier.padding(horizontal = gutter)) {
                    Summary(user)
                    Spacer(Modifier.height(20.dp))
                    StatsGrid(user, perRow = if (shell.compact) 4 else 7)
                }
                Spacer(Modifier.height(20.dp))
                SectionHeader("Badges", count = "${user.stats.badges}", modifier = Modifier.padding(horizontal = gutter))
                Shelf(gutter = gutter, spacing = 6.dp) {
                    items(user.badges, key = { it.name }) { BadgeMedallion(it) }
                }
                Column(Modifier.padding(horizontal = gutter)) {
                    Spacer(Modifier.height(16.dp))
                    FavoriteGame(user)
                    Spacer(Modifier.height(24.dp))
                    RecentActivity(user.recentGames)
                }
                Spacer(Modifier.height(20.dp))
                SectionHeader("Rare Achievement Showcase", modifier = Modifier.padding(horizontal = gutter))
                Shelf(gutter = gutter, spacing = 8.dp) {
                    items(user.rareAchievements, key = { "${it.appId}-${it.achievement.name}" }) { RareAchievementTile(it) }
                }
                Column(Modifier.padding(horizontal = gutter)) {
                    Spacer(Modifier.height(12.dp))
                    ScreenshotShowcase(user)
                    Spacer(Modifier.height(24.dp))
                    FriendsPreview()
                }
            }
        }
        // Status-bar scrim once the banner has scrolled away (compact, edge-to-edge).
        if (shell.compact) {
            val fadeRange = with(LocalDensity.current) { 240.dp.toPx() }
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(statusBarHeight())
                    .graphicsLayer { alpha = (scroll.value / fadeRange).coerceIn(0f, 1f) }
                    .background(Steam.bgChrome.copy(alpha = 0.96f)),
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

@Composable
private fun Banner(user: UserProfile, scroll: () -> Int, first: FocusRequester) {
    val shell = LocalShell.current
    val height = if (shell.compact) 372.dp else 320.dp
    Box(Modifier.fillMaxWidth().height(height).clipToBounds()) {
        // Darkened art that dissolves into the page.
        Box(Modifier.fillMaxSize().fadeOutBottom(0.45f)) {
            SteamImage(
                user.backgroundUrl,
                Modifier.fillMaxSize().graphicsLayer { translationY = scroll() * 0.45f },
                placeholderColor = Color.Transparent,
                transparent = true,
            )
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        0f to Color.Black.copy(alpha = 0.55f),
                        0.35f to Color.Black.copy(alpha = 0.3f),
                        1f to Color.Black.copy(alpha = 0.6f),
                    ),
                ),
            )
        }
        Column(
            Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .padding(horizontal = shell.gutter)
                .padding(bottom = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.Bottom) {
                Box(
                    Modifier
                        .size(if (shell.compact) 100.dp else 132.dp)
                        .border(3.dp, Steam.statusOnline, RoundedCornerShape(6.dp))
                        .padding(4.dp)
                        .clip(RoundedCornerShape(4.dp)),
                ) {
                    SteamImage(user.avatarUrl, Modifier.fillMaxSize(), placeholderColor = Steam.surfaceNeutral)
                }
                Spacer(Modifier.width(16.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        user.personaName,
                        style = if (shell.compact) MaterialTheme.typography.headlineMedium else MaterialTheme.typography.displaySmall,
                        color = Steam.textTitle,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                    )
                    Text(
                        "${user.realName}  ·  ${user.country}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Steam.textBody,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text("Online", style = MaterialTheme.typography.labelLarge, color = Steam.statusOnline)
                }
                if (!shell.compact) {
                    LevelBlock(user, Modifier.width(260.dp))
                    Spacer(Modifier.width(24.dp))
                    EditProfileButton(first)
                }
            }
            if (shell.compact) {
                Spacer(Modifier.height(16.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LevelBlock(user, Modifier.weight(1f))
                    Spacer(Modifier.width(16.dp))
                    EditProfileButton(first)
                }
            }
        }
    }
}

@Composable
private fun LevelBlock(user: UserProfile, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        LevelRing(user.level, user.levelColor, size = 48.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text("Level ", style = MaterialTheme.typography.titleSmall, color = Steam.textBody)
                Text("${user.level}", style = MaterialTheme.typography.titleSmall, color = Steam.textTitle)
            }
            Spacer(Modifier.height(5.dp))
            ProgressLine(user.xpFraction, color = Steam.parseHex(user.levelColor).let { lerp(it, Color.White, 0.25f) }, height = 4.dp)
            Spacer(Modifier.height(4.dp))
            Text(user.xpToNextLabel, style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, maxLines = 1)
        }
    }
}

@Composable
private fun EditProfileButton(first: FocusRequester) {
    Row(
        Modifier
            .steamFocusable(onClick = {}, corner = 4.dp, focusRequester = first)
            .background(Color.White.copy(alpha = 0.12f))
            .height(40.dp)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.Edit, null, tint = Steam.textBody, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text("Edit Profile", style = MaterialTheme.typography.labelLarge, color = Steam.textBody)
    }
}

// ---------------------------------------------------------------------------
// Summary & stats
// ---------------------------------------------------------------------------

@Composable
private fun Summary(user: UserProfile) {
    Column(Modifier.widthIn(max = 820.dp)) {
        Spacer(Modifier.height(4.dp))
        Text(user.summary, style = MaterialTheme.typography.bodyLarge, color = Steam.textBody)
        Spacer(Modifier.height(8.dp))
        Text(
            "${user.memberSinceLabel}  ·  ${user.yearsLabel}",
            style = MaterialTheme.typography.labelMedium,
            color = Steam.textSecondary,
        )
    }
}

private val numbers: NumberFormat = NumberFormat.getIntegerInstance(Locale.US)

@Composable
private fun StatsGrid(user: UserProfile, perRow: Int) {
    val s = user.stats
    val games = numbers.format(s.gamesOwned) to "Games"
    val achievements = numbers.format(s.achievements) to "Achievements"
    val perfect = numbers.format(s.perfectGames) to "Perfect games"
    val hours = s.hoursLabel to "Played"
    val friends = numbers.format(s.friends) to "Friends"
    val screenshots = numbers.format(s.screenshots) to "Screenshots"
    val reviews = numbers.format(s.reviews) to "Reviews"
    val rows = if (perRow >= 7) {
        listOf(listOf(games, achievements, perfect, hours, friends, screenshots, reviews))
    } else {
        // Short captions on the 4-up row, long ones get the wider 3-up row.
        listOf(listOf(games, friends, reviews, screenshots), listOf(achievements, perfect, hours))
    }
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.22f), RoundedCornerShape(6.dp))
            .padding(vertical = 14.dp, horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        rows.forEach { row ->
            Row(Modifier.fillMaxWidth()) {
                row.forEach { (value, caption) ->
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(value, style = MaterialTheme.typography.titleLarge, color = Steam.textTitle, fontWeight = FontWeight.Bold, maxLines = 1)
                        Spacer(Modifier.height(2.dp))
                        Text(caption.uppercase(), style = SteamType.caption, maxLines = 1, textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

private fun badgeIcon(key: String): ImageVector = when (key) {
    "years" -> Icons.Filled.Cake
    "sale" -> Icons.Filled.LocalOffer
    "collector" -> Icons.Filled.Inventory2
    "community" -> Icons.Filled.Forum
    "awards" -> Icons.Filled.EmojiEvents
    "deck" -> Icons.Filled.SportsEsports
    "trophy" -> Icons.Filled.MilitaryTech
    else -> Icons.Filled.WorkspacePremium
}

@Composable
private fun BadgeMedallion(badge: Badge) {
    val color = Steam.parseHex(badge.color)
    Column(
        Modifier
            .width(88.dp)
            .steamFocusable(onClick = {}, corner = 8.dp, focusScale = 1.06f)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(64.dp)) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.radialGradient(listOf(lerp(color, Color.White, 0.35f), color, lerp(color, Color.Black, 0.45f))),
                        CircleShape,
                    )
                    .border(2.dp, lerp(color, Color.White, 0.5f).copy(alpha = 0.8f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(badgeIcon(badge.icon), null, tint = Color.White, modifier = Modifier.size(28.dp))
            }
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 4.dp, y = 2.dp)
                    .size(24.dp)
                    .background(Steam.bgChrome, CircleShape)
                    .border(1.5.dp, color, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("${badge.level}", color = Steam.textTitle, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            badge.name,
            style = MaterialTheme.typography.labelSmall,
            color = Steam.textBody,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

// ---------------------------------------------------------------------------
// Favorite game, recent activity
// ---------------------------------------------------------------------------

@Composable
private fun FavoriteGame(user: UserProfile) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val game = app.index.libraryGame(user.favoriteGame.appId) ?: return
    SectionHeader("Favorite Game")
    SteamCard(onClick = { nav.openGame(game.appId) }, color = Steam.surfaceNeutral, focusScale = 1.02f, modifier = Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().height(if (shell.compact) 190.dp else 230.dp)) {
            SteamImage(game.images.hero ?: game.images.capsule, Modifier.fillMaxSize(), placeholderLabel = game.name)
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(0.35f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.85f)),
                ),
            )
            GameLogo(
                game.images.logo,
                game.name,
                Modifier
                    .align(Alignment.TopStart)
                    .padding(16.dp)
                    .fillMaxWidth(0.45f)
                    .height(if (shell.compact) 64.dp else 84.dp),
            )
            Row(
                Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(14.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(game.playtimeLabel, style = MaterialTheme.typography.titleMedium, color = Steam.textTitle)
                    Text("Last played ${game.lastPlayedLabel.lowercase().let { if (it == "today" || it == "yesterday") it else game.lastPlayedLabel }}", style = MaterialTheme.typography.labelMedium, color = Steam.textSecondary)
                }
                game.achievements?.let { a ->
                    Column(Modifier.width(150.dp), horizontalAlignment = Alignment.End) {
                        Text("${a.unlocked} / ${a.total} achievements", style = MaterialTheme.typography.labelMedium, color = Steam.textBody)
                        Spacer(Modifier.height(5.dp))
                        ProgressLine(a.fraction)
                    }
                }
            }
        }
    }
}

@Composable
private fun RecentActivity(games: List<RecentGame>) {
    val nav = LocalNavigator.current
    SectionHeader("Recent Activity")
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        games.forEach { g ->
            SteamCard(onClick = { nav.openGame(g.appId) }, color = Steam.surfaceNeutral, focusScale = 1.02f, modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.fillMaxWidth().padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    SteamImage(
                        g.images.header,
                        Modifier.width(136.dp).aspectRatio(460f / 215f).clip(RoundedCornerShape(3.dp)),
                        placeholderLabel = g.name,
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(g.name, style = MaterialTheme.typography.titleSmall, color = Steam.textTitle, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(g.totalLabel, style = MaterialTheme.typography.labelMedium, color = Steam.textBody, maxLines = 1)
                        Text(g.lastPlayedLabel, style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, maxLines = 1)
                        g.achievements?.let { a ->
                            Spacer(Modifier.height(6.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                ProgressLine(a.fraction, Modifier.weight(1f), height = 3.dp)
                                Spacer(Modifier.width(8.dp))
                                Text("${a.unlocked}/${a.total}", style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Showcases
// ---------------------------------------------------------------------------

@Composable
private fun RareAchievementTile(item: ShowcaseAchievement) {
    val nav = LocalNavigator.current
    Column(
        Modifier
            .width(96.dp)
            .steamFocusable(onClick = { nav.openGame(item.appId) }, corner = 6.dp, focusScale = 1.06f)
            .padding(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        SteamImage(
            item.achievement.iconUrl,
            Modifier.size(68.dp).clip(RoundedCornerShape(4.dp)).border(1.dp, Color(0xFFE5C55B).copy(alpha = 0.6f), RoundedCornerShape(4.dp)),
            placeholderColor = Steam.surfaceNeutral,
        )
        Spacer(Modifier.height(6.dp))
        Text(item.achievement.name, style = MaterialTheme.typography.labelSmall, color = Steam.textTitle, textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(item.appName, style = MaterialTheme.typography.labelSmall, color = Steam.textSecondary, textAlign = TextAlign.Center, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun RareAchievementsGrid(items: List<ShowcaseAchievement>) {
    SectionHeader("Rare Achievement Showcase")
    FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        items.forEach { RareAchievementTile(it) }
    }
}

@Composable
private fun ScreenshotShowcase(user: UserProfile) {
    val shots = user.screenshots
    if (shots.isEmpty()) return
    SectionHeader("Screenshot Showcase", count = numbers.format(user.stats.screenshots))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ShowcaseShot(shots.first().url, shots.first().appName, Modifier.fillMaxWidth())
        if (shots.size > 1) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                shots.drop(1).take(3).forEach { ShowcaseShot(it.url, it.appName, Modifier.weight(1f), small = true) }
            }
        }
    }
}

@Composable
private fun ShowcaseShot(url: String, appName: String, modifier: Modifier, small: Boolean = false) {
    Box(modifier.aspectRatio(16f / 9f).steamFocusable(onClick = {}, corner = 4.dp, focusScale = if (small) 1.05f else 1.02f)) {
        SteamImage(url, Modifier.fillMaxSize(), placeholderLabel = appName, placeholderColor = Steam.surfaceNeutral)
        if (!small) {
            Text(
                appName,
                style = MaterialTheme.typography.labelMedium,
                color = Steam.textTitle,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(8.dp)
                    .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(3.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun FriendsPreview() {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val friends = app.index.snapshot.friends
    SectionHeader("Friends", count = "${friends.size}", seeAllLabel = "View all", onSeeAll = { nav.openFriends() })
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        friends.take(8).forEach { f ->
            Box(Modifier.steamFocusable(onClick = { nav.openFriends() }, corner = 4.dp, focusScale = 1.08f)) {
                Avatar(f.avatarUrl, 40.dp, status = f.status, contentDescription = f.personaName)
            }
        }
    }
}
