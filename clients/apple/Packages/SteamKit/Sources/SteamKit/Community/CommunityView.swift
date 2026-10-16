import SwiftUI

/// COMMUNITY tab (DESIGN §4.3).
struct CommunityView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        Group {
            if layout.isCompact {
                CompactCommunity()
            } else {
                RegularCommunity()
            }
        }
        .background(Steam.storeBackground.ignoresSafeArea())
        .screenChrome(title: "Community")
        .focusScope("community")
    }
}

// MARK: - Compact: segmented Activity | News | Hubs

private struct CompactCommunity: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Section", selection: $model.communitySection) {
                    ForEach(CommunitySection.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                switch model.communitySection {
                case .activity:
                    ForEach(model.snapshot.community.activity) { item in
                        ActivityCard(item: item)
                    }
                case .news:
                    ForEach(model.snapshot.community.news) { item in
                        NewsCard(item: item)
                    }
                case .hubs:
                    HubsList()
                }
            }
            .padding(.horizontal, layout.gutter)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .focusScrollContainer(.vertical)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.push(.friends) } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Friends")
            }
        }
        #endif
    }
}

// MARK: - Regular: activity column, news beside, hubs + friends rail

private struct RegularCommunity: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let showsRail = layout.width >= 1100
        let newsBeside = layout.width >= 1300
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 32) {
                    HStack(alignment: .top, spacing: 24) {
                        ActivityColumn()
                            .frame(maxWidth: .infinity)
                        if newsBeside {
                            NewsColumn()
                                .frame(width: 380)
                        }
                    }
                    if !newsBeside {
                        NewsColumn()
                    }
                    if !showsRail {
                        HubsSection()
                        FriendsPanel()
                    }
                }
                .frame(maxWidth: .infinity)
                if showsRail {
                    VStack(alignment: .leading, spacing: 28) {
                        HubsSection()
                        FriendsPanel()
                    }
                    .frame(width: 320)
                }
            }
            .padding(.horizontal, layout.gutter)
            .padding(.top, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: 1600)
            .frame(maxWidth: .infinity)
        }
        .focusScrollContainer(.vertical)
    }
}

private struct ActivityColumn: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Friend Activity")
            ForEach(model.snapshot.community.activity) { item in
                ActivityCard(item: item, isDefault: item.id == model.snapshot.community.activity.first?.id)
            }
        }
    }
}

private struct NewsColumn: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("News") { SeeAllLabel() }
            ForEach(model.snapshot.community.news) { item in
                NewsCard(item: item)
            }
        }
    }
}

private struct HubsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Popular Hubs")
            HubsList()
        }
    }
}

// MARK: - Activity

struct ActivityCard: View {
    let item: ActivityItem
    var isDefault = false
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let open = { model.push(model.libraryGame(item.appId) != nil ? .game(item.appId) : .storeApp(item.appId)) }
        Button(action: open) {
            ActivityCardContent(item: item, friend: model.friend(item.friendId), compact: layout.isCompact)
        }
        .buttonStyle(PressableStyle(pressedScale: 0.99))
        .steamFocusable("community.activity.\(item.id)", scales: !layout.isCompact, lifts: false, isDefault: isDefault, action: open)
    }
}

private struct ActivityCardContent: View {
    let item: ActivityItem
    let friend: Friend?
    let compact: Bool

    private var headline: Text {
        let status = friend?.status ?? "online"
        let name = Text(item.friendName).fontWeight(.semibold).foregroundStyle(Steam.statusColor(status) == Steam.statusOffline ? Steam.textTitle : Steam.statusColor(status))
        let app = Text(item.appName).fontWeight(.semibold).foregroundStyle(Steam.accentLink)
        return Text("\(name) \(Text(item.headline).foregroundStyle(Steam.textSecondary)) \(app)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(item.friendAvatarUrl, status: friend?.status ?? "online", size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    headline
                        .font(.system(size: 14))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.timeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Steam.textMuted)
                }
                Spacer(minLength: 0)
            }
            ActivityBody(item: item)
            HStack(spacing: 18) {
                Label("\(item.likes)", systemImage: "hand.thumbsup")
                Label("\(item.comments)", systemImage: "bubble.left")
                Spacer()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Steam.textSecondary)
        }
        .padding(14)
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

private struct ActivityBody: View {
    let item: ActivityItem

    var body: some View {
        switch item.kind {
        case "achievement":
            if let a = item.achievement {
                HStack(spacing: 14) {
                    RemoteImage(a.iconUrl, maxPixel: 200)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Steam.textTitle)
                        if let label = a.unlockedLabel {
                            Text(label)
                                .font(.system(size: 12))
                                .foregroundStyle(Steam.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }
        case "screenshot":
            RemoteImage(item.imageUrl ?? item.appImages.header, maxPixel: 1400, placeholder: item.appName)
                .aspectRatio(Aspect.screenshot, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        case "review":
            if let review = item.review {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: review.recommended ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                (review.recommended ? Color(hex: 0x2B6A94) : Color(hex: 0x8A3B1E)),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.recommended ? "Recommended" : "Not Recommended")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Steam.textTitle)
                            Text(review.hoursLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(Steam.textSecondary)
                        }
                    }
                    Text("“\(review.body)”")
                        .font(.system(size: 14))
                        .italic()
                        .foregroundStyle(Steam.textBody)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }
        default: // nowPlaying, newGame
            HStack(spacing: 14) {
                RemoteImage(item.appImages.header, maxPixel: 700, placeholder: item.appName)
                    .aspectRatio(Aspect.header, contentMode: .fit)
                    .frame(maxWidth: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.appName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                    Text(item.kind == "nowPlaying" ? "Now playing" : "New to their library")
                        .font(.system(size: 12))
                        .foregroundStyle(item.kind == "nowPlaying" ? Steam.statusInGame : Steam.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - News

struct NewsCard: View {
    let item: NewsItem
    @Environment(AppModel.self) private var model

    var body: some View {
        let open = { model.push(model.libraryGame(item.appId) != nil ? .game(item.appId) : .storeApp(item.appId)) }
        Button(action: open) {
            NewsCardContent(item: item)
        }
        .buttonStyle(PressableStyle(pressedScale: 0.99))
        .steamFocusable("community.news.\(item.id)", lifts: true, action: open)
    }
}

private struct NewsCardContent: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(item.imageUrl ?? item.appImages.header, maxPixel: 900, placeholder: item.appName)
                .aspectRatio(Aspect.header, contentMode: .fit)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(item.appName) · \(item.feedLabel) · \(item.dateLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Steam.textSecondary)
                    .lineLimit(1)
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.excerpt)
                    .font(.system(size: 13))
                    .foregroundStyle(Steam.textBody.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Hubs

struct HubsList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            // Ordered by live player count; show the position in this list.
            ForEach(Array(model.snapshot.community.hubs.enumerated()), id: \.element.id) { i, hub in
                HubRow(hub: hub, position: i + 1)
            }
        }
    }
}

private struct HubRow: View {
    let hub: Hub
    let position: Int
    @Environment(AppModel.self) private var model

    var body: some View {
        let open = { model.push(.storeApp(hub.appId)) }
        Button(action: open) {
            HubRowContent(hub: hub, position: position)
        }
        .buttonStyle(.pressable)
        .steamFocusable("community.hub.\(hub.appId)", lifts: false, action: open)
    }
}

private struct HubRowContent: View {
    let hub: Hub
    let position: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(position)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Steam.textMuted)
                .frame(width: 18)
            RemoteImage(hub.images.header, maxPixel: 400)
                .frame(width: 92, height: 43)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 4) {
                Text(hub.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    LiveDot()
                    Text(hub.currentPlayersLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Steam.statusInGame)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Friends

struct FriendsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Friends", count: model.snapshot.friends.count)
            FriendsGroups(idPrefix: "community.friend")
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(Steam.bgChrome.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}

/// Friends grouped In-Game / Online / Offline.
struct FriendsGroups: View {
    let idPrefix: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let friends = model.snapshot.friends
        let groups: [(String, [Friend])] = [
            ("In-Game", friends.filter { $0.status == "inGame" }),
            ("Online", friends.filter { $0.status == "online" || $0.status == "away" }),
            ("Offline", friends.filter { $0.status == "offline" }),
        ]
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groups, id: \.0) { title, members in
                if !members.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(title) (\(members.count))")
                            .captionCaps(size: 10, color: Steam.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                        ForEach(members) { friend in
                            FriendRow(friend: friend, focusID: "\(idPrefix).\(friend.steamId)")
                        }
                    }
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: Friend
    let focusID: String
    var playing = false
    @Environment(AppModel.self) private var model

    var body: some View {
        let open: () -> Void = {
            if let game = friend.game { model.push(model.libraryGame(game.appId) != nil ? .game(game.appId) : .storeApp(game.appId)) }
        }
        Button(action: open) {
            FriendRowContent(friend: friend)
        }
        .buttonStyle(.pressable)
        .steamFocusable(focusID, cornerRadius: 4, scales: false, lifts: false, action: open)
        .accessibilityLabel("\(friend.personaName), \(friend.statusLabel)")
    }
}

private struct FriendRowContent: View {
    let friend: Friend
    @Environment(\.cardHighlighted) private var highlighted

    var body: some View {
        let color = Steam.statusColor(friend.status)
        HStack(spacing: 10) {
            AvatarView(friend.avatarUrl, status: friend.status, size: 32)
                .opacity(friend.status == "offline" ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(friend.personaName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(friend.statusLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(friend.status == "inGame" ? Steam.statusInGame.opacity(0.85) : Steam.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            LevelRing(level: friend.level, color: friend.levelColor, size: 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 4).fill(highlighted ? Steam.surfaceHover : .clear))
        .contentShape(Rectangle())
    }
}

/// Full friends list (pushed from Profile on compact, or the top-bar friends button).
struct FriendsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !layout.isCompact {
                    Text("Friends")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                }
                FriendsGroups(idPrefix: "friends.page")
            }
            .padding(.horizontal, layout.gutter)
            .padding(.vertical, layout.isCompact ? 8 : 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .focusScrollContainer(.vertical)
        .background(Steam.storeBackground.ignoresSafeArea())
        .screenChrome(title: "Friends", large: true)
        .focusScope("friends")
    }
}
