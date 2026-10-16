package dev.nativesteam.android.ui.community

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.ThumbUp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import dev.nativesteam.android.data.ActivityItem
import dev.nativesteam.android.data.Community
import dev.nativesteam.android.data.Hub
import dev.nativesteam.android.data.NewsItem
import dev.nativesteam.android.ui.components.Avatar
import dev.nativesteam.android.ui.components.BarAction
import dev.nativesteam.android.ui.components.HomeScaffold
import dev.nativesteam.android.ui.components.LiveDot
import dev.nativesteam.android.ui.components.SectionHeader
import dev.nativesteam.android.ui.components.SteamCard
import dev.nativesteam.android.ui.components.SteamImage
import dev.nativesteam.android.ui.components.gamepadActivatable
import dev.nativesteam.android.ui.shell.InitialFocus
import dev.nativesteam.android.ui.shell.LocalAppState
import dev.nativesteam.android.ui.shell.LocalNavigator
import dev.nativesteam.android.ui.shell.LocalShell
import dev.nativesteam.android.ui.shell.Tab
import dev.nativesteam.android.ui.theme.Steam
import dev.nativesteam.android.ui.theme.SteamType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Section(val label: String) { Activity("Activity"), News("News"), Hubs("Hubs") }

@Composable
fun CommunityScreen() {
    val app = LocalAppState.current
    val shell = LocalShell.current
    val nav = LocalNavigator.current
    val firstFocus = remember { FocusRequester() }
    InitialFocus(firstFocus)
    var section by rememberSaveable { mutableStateOf(Section.Activity) }
    val community = app.index.snapshot.community

    // LT / RT page between sections on compact.
    LaunchedEffect(app) {
        app.pageEvents.collect { d ->
            if (app.tab != Tab.Community) return@collect
            val all = Section.entries
            section = all[(all.indexOf(section) + d + all.size) % all.size]
            app.requestContentFocus()
        }
    }

    HomeScaffold(
        title = "Community",
        background = Steam.storeBackground,
        actions = {
            BarAction(Icons.Outlined.PersonAdd, "Add a friend") {}
        },
    ) { padding ->
        when {
            shell.compact -> CompactCommunity(community, section, { section = it }, padding, firstFocus)
            shell.width.hasRail -> Row(Modifier.fillMaxSize().padding(horizontal = shell.gutter), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                FeedColumn(Modifier.weight(1f).widthIn(max = 720.dp), padding) {
                    activityItems(community.activity, firstFocus)
                }
                FeedColumn(Modifier.width(360.dp), padding) {
                    newsItems(community.news)
                }
                FeedColumn(
                    Modifier
                        .width(300.dp)
                        .background(Steam.bgChrome.copy(alpha = 0.55f)),
                    padding,
                    horizontal = 14.dp,
                ) {
                    item(key = "friends-h") { SectionHeader("Friends", count = "${app.index.snapshot.friends.size}", onSeeAll = { nav.openFriends() }) }
                    friendItems(app.index.snapshot.friends, compactRows = true)
                    item(key = "hubs-gap") { Spacer(Modifier.height(16.dp)) }
                    hubItems(community.hubs, compact = true)
                }
            }
            else -> Row(Modifier.fillMaxSize().padding(horizontal = shell.gutter), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                FeedColumn(Modifier.weight(1f), padding) { activityItems(community.activity, firstFocus) }
                FeedColumn(Modifier.width(320.dp), padding) {
                    newsItems(community.news)
                    item(key = "hubs-gap") { Spacer(Modifier.height(16.dp)) }
                    hubItems(community.hubs, compact = true)
                }
            }
        }
    }
}

@Composable
private fun FeedColumn(
    modifier: Modifier,
    padding: PaddingValues,
    horizontal: androidx.compose.ui.unit.Dp = 0.dp,
    content: LazyListScope.() -> Unit,
) {
    LazyColumn(
        modifier.fillMaxHeight(),
        contentPadding = PaddingValues(
            start = horizontal,
            end = horizontal,
            top = padding.calculateTopPadding() + 4.dp,
            bottom = padding.calculateBottomPadding(),
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Composable
private fun CompactCommunity(
    community: Community,
    section: Section,
    onSection: (Section) -> Unit,
    padding: PaddingValues,
    firstFocus: FocusRequester,
) {
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
            scope.launch {
                refreshing = true
                delay(900)
                refreshing = false
            }
        },
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = padding.calculateBottomPadding()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "segments") {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(bottom = 4.dp)) {
                    Section.entries.forEachIndexed { i, s ->
                        SegmentedButton(
                            selected = section == s,
                            onClick = { onSection(s) },
                            shape = SegmentedButtonDefaults.itemShape(i, Section.entries.size),
                            colors = SegmentedButtonDefaults.colors(
                                activeContainerColor = Steam.accent.copy(alpha = 0.25f),
                                activeContentColor = Steam.textTitle,
                                activeBorderColor = Steam.accent.copy(alpha = 0.6f),
                                inactiveContainerColor = Color.Transparent,
                                inactiveContentColor = Steam.textSecondary,
                                inactiveBorderColor = Color.White.copy(alpha = 0.14f),
                            ),
                            label = { Text(s.label.uppercase(), style = SteamType.tabLabel.copy(fontSize = MaterialTheme.typography.labelMedium.fontSize)) },
                            modifier = Modifier.gamepadActivatable { onSection(s) },
                        )
                    }
                }
            }
            when (section) {
                Section.Activity -> activityItems(community.activity, firstFocus)
                Section.News -> newsItems(community.news, firstFocus)
                Section.Hubs -> hubItems(community.hubs, compact = false, firstFocus = firstFocus)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------

private fun LazyListScope.activityItems(activity: List<ActivityItem>, firstFocus: FocusRequester?) {
    item(key = "activity-h") { SectionHeader("Friend Activity") }
    itemsIndexed(activity, key = { _, a -> a.id }) { i, a ->
        ActivityCard(a, if (i == 0) firstFocus else null)
    }
}

@Composable
private fun ActivityCard(item: ActivityItem, focusRequester: FocusRequester?) {
    val app = LocalAppState.current
    val nav = LocalNavigator.current
    val friend = app.index.friend(item.friendId)
    SteamCard(
        onClick = { nav.openTitle(item.appId) },
        focusRequester = focusRequester,
        focusScale = 1.02f,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Avatar(item.friendAvatarUrl, 40.dp, status = friend?.status ?: "offline")
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        buildAnnotatedString {
                            withStyle(SpanStyle(color = Steam.statusColor(friend?.status).let { if (friend?.status == "offline") Steam.textTitle else it }, fontWeight = FontWeight.SemiBold)) {
                                append(item.friendName)
                            }
                            withStyle(SpanStyle(color = Steam.textSecondary)) { append(" ${item.headline} ") }
                            withStyle(SpanStyle(color = Steam.accentLink, fontWeight = FontWeight.SemiBold)) { append(item.appName) }
                        },
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(item.timeLabel, style = MaterialTheme.typography.labelSmall, color = Steam.textMuted)
                }
            }
            Spacer(Modifier.height(12.dp))
            ActivityBody(item)
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.ThumbUp, "Likes", tint = Steam.textSecondary, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("${item.likes}", style = MaterialTheme.typography.labelMedium, color = Steam.textSecondary)
                Spacer(Modifier.width(18.dp))
                Icon(Icons.AutoMirrored.Outlined.Chat, "Comments", tint = Steam.textSecondary, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("${item.comments}", style = MaterialTheme.typography.labelMedium, color = Steam.textSecondary)
            }
        }
    }
}

@Composable
private fun ActivityBody(item: ActivityItem) {
    when (item.kind) {
        "achievement" -> {
            val a = item.achievement
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Color.Black.copy(alpha = 0.22f), RoundedCornerShape(4.dp))
                    .padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SteamImage(a?.iconUrl, Modifier.size(64.dp).clip(RoundedCornerShape(4.dp)), placeholderColor = Steam.surfaceNeutral)
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(a?.name ?: "Achievement", style = MaterialTheme.typography.titleSmall, color = Steam.textTitle)
                    a?.unlockedLabel?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Steam.textSecondary) }
                }
            }
        }
        "screenshot" -> {
            SteamImage(
                item.imageUrl ?: item.appImages.header,
                Modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(4.dp)),
                placeholderLabel = item.appName,
            )
        }
        "review" -> {
            val r = item.review
            val recommended = r?.recommended ?: true
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Color.Black.copy(alpha = 0.22f), RoundedCornerShape(4.dp)),
            ) {
                Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(44.dp)
                            .background(
                                if (recommended) Steam.accent.copy(alpha = 0.25f) else Steam.reviewNegative.copy(alpha = 0.35f),
                                RoundedCornerShape(4.dp),
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            if (recommended) Icons.Filled.ThumbUp else Icons.Filled.ThumbDown,
                            null,
                            tint = if (recommended) Steam.accentLink else Color(0xFFE07B53),
                            modifier = Modifier.size(24.dp),
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(
                            if (recommended) "Recommended" else "Not Recommended",
                            style = MaterialTheme.typography.titleSmall,
                            color = Steam.textTitle,
                        )
                        r?.hoursLabel?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Steam.textSecondary) }
                    }
                }
                r?.body?.let { body ->
                    Row(Modifier.height(IntrinsicSize.Min).padding(start = 10.dp, end = 10.dp, bottom = 12.dp)) {
                        Box(Modifier.width(3.dp).fillMaxHeight().background(Steam.accentLink.copy(alpha = 0.5f)))
                        Spacer(Modifier.width(10.dp))
                        Text(
                            "“$body”",
                            style = MaterialTheme.typography.bodyMedium,
                            fontStyle = FontStyle.Italic,
                            color = Steam.textBody,
                        )
                    }
                }
            }
        }
        else -> {
            // nowPlaying / newGame: the game's header art with its name.
            Box(Modifier.fillMaxWidth().aspectRatio(460f / 215f).clip(RoundedCornerShape(4.dp))) {
                SteamImage(item.imageUrl ?: item.appImages.header, Modifier.fillMaxSize(), placeholderLabel = item.appName)
                if (item.kind == "nowPlaying") {
                    Row(
                        Modifier
                            .align(Alignment.TopStart)
                            .padding(8.dp)
                            .background(Color.Black.copy(alpha = 0.65f), RoundedCornerShape(4.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LiveDot()
                        Spacer(Modifier.width(6.dp))
                        Text("NOW PLAYING", style = SteamType.caption.copy(color = Steam.statusInGame))
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(item.appName, style = MaterialTheme.typography.titleSmall, color = Steam.textTitle)
        }
    }
}


// ---------------------------------------------------------------------------
// News & hubs
// ---------------------------------------------------------------------------

private fun LazyListScope.newsItems(news: List<NewsItem>, firstFocus: FocusRequester? = null) {
    item(key = "news-h") { SectionHeader("News") }
    itemsIndexed(news, key = { _, n -> "news-${n.id}" }) { i, n -> NewsCard(n, if (i == 0) firstFocus else null) }
}

@Composable
private fun NewsCard(item: NewsItem, focusRequester: FocusRequester?) {
    val uri = LocalUriHandler.current
    SteamCard(
        onClick = { runCatching { uri.openUri(item.url) } },
        focusRequester = focusRequester,
        focusScale = 1.02f,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            SteamImage(
                item.imageUrl ?: item.appImages.header,
                Modifier.fillMaxWidth().aspectRatio(if (item.imageUrl != null) 16f / 9f else 460f / 215f),
                placeholderLabel = item.appName,
            )
            Column(Modifier.padding(14.dp)) {
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(color = Steam.accentLink, fontWeight = FontWeight.SemiBold)) { append(item.appName) }
                        withStyle(SpanStyle(color = Steam.textSecondary)) { append("  ·  ${item.dateLabel}  ·  ${item.feedLabel}") }
                    },
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(6.dp))
                Text(item.title, style = MaterialTheme.typography.titleMedium, color = Steam.textTitle, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(6.dp))
                Text(item.excerpt, style = MaterialTheme.typography.bodyMedium, color = Steam.textBody, maxLines = 3, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

private fun LazyListScope.hubItems(hubs: List<Hub>, compact: Boolean, firstFocus: FocusRequester? = null) {
    item(key = "hubs-h") { SectionHeader("Popular Hubs") }
    itemsIndexed(hubs, key = { _, h -> "hub-${h.appId}" }) { i, h -> HubRow(h, compact, if (i == 0) firstFocus else null) }
}

@Composable
private fun HubRow(hub: Hub, compact: Boolean, focusRequester: FocusRequester?) {
    val nav = LocalNavigator.current
    SteamCard(
        onClick = { nav.openTitle(hub.appId) },
        focusRequester = focusRequester,
        focusScale = 1.02f,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.fillMaxWidth().padding(end = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            SteamImage(
                hub.images.header,
                Modifier.width(if (compact) 112.dp else 150.dp).aspectRatio(460f / 215f),
                placeholderLabel = hub.name,
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f).padding(vertical = 8.dp)) {
                Text(hub.name, style = MaterialTheme.typography.titleSmall, color = Steam.textTitle, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(3.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LiveDot()
                    Spacer(Modifier.width(6.dp))
                    Text(hub.currentPlayersLabel, style = MaterialTheme.typography.bodySmall, color = Steam.statusInGame, maxLines = 1)
                }
            }
            Text("#${hub.rank}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Steam.textSecondary)
        }
    }
}
