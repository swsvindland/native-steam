package dev.nativesteam.android.ui.community

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.nativesteam.android.data.Friend
import dev.nativesteam.android.ui.components.Avatar
import dev.nativesteam.android.ui.components.DetailBackButton
import dev.nativesteam.android.ui.components.LevelRing
import dev.nativesteam.android.ui.components.steamFocusable
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType

/** In-Game / Online / Offline groups (away counts as online, dimmed). */
fun groupFriends(friends: List<Friend>): List<Pair<String, List<Friend>>> = listOf(
    "In-Game" to friends.filter { it.status == "inGame" },
    "Online" to friends.filter { it.status == "online" || it.status == "away" },
    "Offline" to friends.filter { it.status == "offline" },
).filter { it.second.isNotEmpty() }

fun LazyListScope.friendItems(
    friends: List<Friend>,
    compactRows: Boolean = false,
    firstFocus: FocusRequester? = null,
) {
    groupFriends(friends).forEachIndexed { g, (group, members) ->
        item(key = "fg-$group") {
            Text(
                "${group.uppercase()}  (${members.size})",
                style = SteamType.caption,
                modifier = Modifier.padding(start = 4.dp, top = if (g == 0) 0.dp else 8.dp),
            )
        }
        itemsIndexed(members, key = { _, f -> "f-${f.steamId}" }) { i, f ->
            FriendRow(f, compactRows, if (g == 0 && i == 0) firstFocus else null)
        }
    }
}

@Composable
fun FriendRow(friend: Friend, compact: Boolean, focusRequester: FocusRequester? = null) {
    val nav = LocalNavigator.current
    Row(
        Modifier
            .fillMaxWidth()
            .steamFocusable(
                onClick = { friend.game?.let { nav.openTitle(it.appId) } },
                corner = 4.dp,
                focusScale = 1.02f,
                focusRequester = focusRequester,
                hoverLift = false,
            )
            .heightIn(min = if (compact) 52.dp else 60.dp)
            .padding(horizontal = 6.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(friend.avatarUrl, if (compact) 38.dp else 44.dp, status = friend.status)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                friend.personaName,
                style = MaterialTheme.typography.titleSmall,
                color = Steam.statusColor(friend.status),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                friend.statusLabel,
                style = MaterialTheme.typography.labelMedium,
                color = if (friend.status == "inGame") Steam.statusInGame.copy(alpha = 0.8f) else Steam.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (!compact) LevelRing(friend.level, friend.levelColor, size = 32.dp)
    }
}

/** Full friends list (pushed from Profile on compact, or "See all" on the rail). */
@Composable
fun FriendsScreen() {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val shell = LocalShell.current
    val first = remember { FocusRequester() }
    InitialFocus(first)
    val friends = app.index.snapshot.friends
    Box(Modifier.fillMaxSize().background(Steam.libraryBackground)) {
        LazyColumn(
            Modifier.fillMaxSize().then(if (shell.compact) Modifier.statusBarsPadding() else Modifier),
            contentPadding = PaddingValues(start = shell.gutter, end = shell.gutter, top = 64.dp, bottom = shell.bottomInset + 32.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            item(key = "title") {
                Column(Modifier.padding(start = 4.dp, bottom = 12.dp)) {
                    Text("Friends", style = MaterialTheme.typography.headlineMedium, color = Steam.textTitle, fontWeight = FontWeight.Bold)
                    Text(
                        "${friends.count { it.status != "offline" }} online · ${friends.size} total",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Steam.textSecondary,
                    )
                }
            }
            item(key = "spacer") { Box(Modifier.widthIn(max = 720.dp)) }
            friendItems(friends, firstFocus = first)
        }
        DetailBackButton(onBack = { nav.back() })
    }
}
