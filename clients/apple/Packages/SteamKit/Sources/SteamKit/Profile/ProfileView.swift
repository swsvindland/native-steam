import SwiftUI

/// KESTREL — the persona tab (DESIGN §4.4).
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileBanner()
                VStack(alignment: .leading, spacing: layout.isCompact ? 28 : 32) {
                    SummaryBlock()
                    StatsStrip()
                    if layout.isCompact {
                        BadgesSection()
                        FavoriteGameSection()
                        RecentActivitySection()
                        RareAchievementsSection()
                        ScreenshotShowcase()
                        FriendsPreview()
                    } else {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 32) {
                                FavoriteGameSection()
                                RecentActivitySection()
                                ScreenshotShowcase()
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 32) {
                                BadgesSection()
                                RareAchievementsSection()
                                FriendsPreview()
                            }
                            .frame(width: layout.width >= 1100 ? 360 : 300)
                        }
                    }
                }
                .padding(.horizontal, layout.gutter)
                .padding(.bottom, 48)
                .frame(maxWidth: 1400)
                .frame(maxWidth: .infinity)
                .background(alignment: .top) {
                    // Continue the banner's fade so there is no seam against the page.
                    LinearGradient(colors: [Steam.libraryTop, Steam.libraryBottom], startPoint: .top, endPoint: .bottom)
                        .frame(height: 900)
                }
            }
        }
        .focusScrollContainer(.vertical)
        .ignoresSafeArea(edges: layout.isCompact ? .top : [])
        .background(Steam.libraryBottom.ignoresSafeArea())
        .screenChrome(title: model.persona, large: false, fullBleed: true)
        .focusScope("profile")
        #if os(iOS)
        .toolbar {
            if layout.isCompact {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
        }
        #endif
    }
}

// MARK: - Banner

private struct ProfileBanner: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let user = model.snapshot.user
        let height: CGFloat = layout.isCompact ? 400 : 300
        ZStack(alignment: .bottom) {
            RemoteImage(user.backgroundUrl, maxPixel: 1920, placeholderColor: Steam.libraryTop)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.45), location: 0),
                            .init(color: .black.opacity(0.25), location: 0.35),
                            .init(color: Steam.libraryTop.opacity(0.85), location: 0.8),
                            .init(color: Steam.libraryTop, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipped()

            Group {
                if layout.isCompact {
                    compactIdentity(user)
                } else {
                    regularIdentity(user)
                }
            }
            .padding(.horizontal, layout.gutter)
            .padding(.bottom, layout.isCompact ? 16 : 24)
            .frame(maxWidth: 1400)
        }
        .frame(maxWidth: .infinity)
    }

    private func regularIdentity(_ user: UserProfile) -> some View {
        HStack(alignment: .bottom, spacing: 22) {
            AvatarView(user.avatarUrl, status: user.status, size: 148, borderWidth: 3)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(user.personaName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Steam.textTitle)
                Text("\(user.realName) · \(user.country)")
                    .font(.system(size: 14))
                    .foregroundStyle(Steam.textBody)
                HStack(spacing: 6) {
                    Circle().fill(Steam.statusOnline).frame(width: 8, height: 8)
                    Text("Currently Online")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Steam.statusOnline)
                }
                .padding(.top, 2)
            }
            .padding(.bottom, 8)
            Spacer(minLength: 16)
            LevelBlock(user: user)
                .padding(.bottom, 8)
        }
    }

    private func compactIdentity(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                AvatarView(user.avatarUrl, status: user.status, size: 96, borderWidth: 3)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.personaName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Steam.textTitle)
                    Text("\(user.realName) · \(user.country)")
                        .font(.system(size: 13))
                        .foregroundStyle(Steam.textBody)
                    HStack(spacing: 6) {
                        Circle().fill(Steam.statusOnline).frame(width: 7, height: 7)
                        Text("Online").font(.system(size: 12, weight: .medium)).foregroundStyle(Steam.statusOnline)
                    }
                }
                Spacer(minLength: 0)
            }
            LevelBlock(user: user)
        }
    }
}

private struct LevelBlock: View {
    let user: UserProfile
    @Environment(\.layout) private var layout

    var body: some View {
        VStack(alignment: layout.isCompact ? .leading : .trailing, spacing: 10) {
            HStack(spacing: 12) {
                Text("Level").font(.system(size: layout.isCompact ? 15 : 18, weight: .medium)).foregroundStyle(Steam.textBody)
                LevelRing(level: user.level, color: user.levelColor, size: layout.isCompact ? 36 : 40)
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(user.xpToNextLabel).font(.system(size: 11)).foregroundStyle(Steam.textSecondary)
                            .lineLimit(1)
                        ProgressBar(user.xpFraction, tint: Color(hexString: user.levelColor), height: 4)
                    }
                    Spacer(minLength: 8)
                    editButton
                }
            }
            if !layout.isCompact {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(user.xpToNextLabel).font(.system(size: 12)).foregroundStyle(Steam.textSecondary)
                    ProgressBar(user.xpFraction, tint: Color(hexString: user.levelColor), height: 4)
                        .frame(width: 200)
                }
                editButton
            }
        }
    }

    private var editButton: some View {
        Button {} label: {
            SecondaryButtonLabel(layout.isCompact ? "Edit" : "Edit Profile", systemImage: "pencil", height: 34)
                .fixedSize()
        }
        .buttonStyle(.pressable)
        .steamFocusable("profile.edit", cornerRadius: Radius.button, lifts: false)
    }
}

// MARK: - Summary + stats

private struct SummaryBlock: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let user = model.snapshot.user
        VStack(alignment: .leading, spacing: 8) {
            Text(user.summary)
                .font(.system(size: 15))
                .foregroundStyle(Steam.textBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(user.memberSinceLabel)
                Text("·")
                Text(user.yearsLabel)
            }
            .font(.system(size: 12))
            .foregroundStyle(Steam.textSecondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: 820, alignment: .leading)
    }
}

private struct StatsStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let s = model.snapshot.user.stats
        let stats: [(String, String)] = [
            (s.gamesOwned.formatted(), "Games"),
            (s.achievements.formatted(), "Achievements"),
            (s.perfectGames.formatted(), "Perfect Games"),
            (s.hoursLabel, "Played"),
            (s.friends.formatted(), "Friends"),
            (s.screenshots.formatted(), "Screenshots"),
            (s.reviews.formatted(), "Reviews"),
        ]
        Group {
            if layout.isCompact {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), alignment: .leading, spacing: 16) {
                    ForEach(stats, id: \.1) { value, caption in statView(value, caption) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { i, stat in
                        statView(stat.0, stat.1)
                            .frame(maxWidth: .infinity)
                        if i < stats.count - 1 {
                            Rectangle().fill(Steam.divider).frame(width: 1, height: 36)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, layout.isCompact ? 12 : 8)
        .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func statView(_ value: String, _ caption: String) -> some View {
        VStack(alignment: layout.isCompact ? .leading : .center, spacing: 4) {
            Text(value)
                .font(.system(size: layout.isCompact ? 18 : 24, weight: .semibold))
                .foregroundStyle(Steam.textTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption).captionCaps(size: layout.isCompact ? 9 : 10)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Badges

private struct BadgesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let user = model.snapshot.user
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Badges", count: user.stats.badges) { SeeAllLabel() }
            let columns = layout.isCompact ? 3 : 3
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: columns), spacing: 14) {
                ForEach(user.badges) { badge in
                    VStack(spacing: 8) {
                        BadgeMedallion(badge, size: layout.isCompact ? 58 : 60)
                        Text(badge.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Steam.textBody)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("\(badge.xp) XP")
                            .font(.system(size: 10))
                            .foregroundStyle(Steam.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .steamFocusable("profile.badge.\(badge.name)", cornerRadius: Radius.card, lifts: false)
                    .help(badge.description)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(12)
            .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}

// MARK: - Favorite game

private struct FavoriteGameSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let ref = model.snapshot.user.favoriteGame
        let game = model.libraryGame(ref.appId)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Favorite Game")
            Button { model.push(.game(ref.appId)) } label: {
                FavoriteGameCard(ref: ref, game: game, compact: layout.isCompact)
            }
            .buttonStyle(PressableStyle(pressedScale: 0.99))
            .steamFocusable("profile.favorite", isDefault: true) { model.push(.game(ref.appId)) }
        }
    }
}

private struct FavoriteGameCard: View {
    let ref: GameRef
    let game: LibraryGame?
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(game?.images.hero ?? game?.images.capsule, maxPixel: 1600, placeholderColor: Steam.surfaceNeutral)
                .frame(height: compact ? 150 : 210)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    LogoImage(game?.images.logo, fallbackTitle: ref.name, maxPixel: 800, titleSize: 26)
                        .frame(maxWidth: compact ? 180 : 300, maxHeight: compact ? 64 : 96, alignment: .bottomLeading)
                        .padding(16)
                }
                .clipped()
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game?.playtimeLabel.replacingOccurrences(of: " on record", with: "") ?? "—")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                    Text("Hours played").captionCaps(size: 10)
                }
                if let a = game?.achievements {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Achievement Progress").captionCaps(size: 10)
                            Spacer()
                            Text("\(a.unlocked) of \(a.total)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Steam.textBody)
                        }
                        ProgressBar(a.fraction, height: 5)
                    }
                }
            }
            .padding(14)
        }
        .background(CardBackground(neutral: true))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Recent activity

private struct RecentActivitySection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let user = model.snapshot.user
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recent Activity") {
                Text(totalTwoWeeks())
                    .font(.system(size: 12))
                    .foregroundStyle(Steam.textSecondary)
            }
            VStack(spacing: 8) {
                ForEach(user.recentGames) { game in
                    RecentActivityRow(game: game)
                }
            }
        }
    }

    /// Steam shows the two-week total here; the snapshot has no label for it, so sum the minutes.
    private func totalTwoWeeks() -> String {
        let minutes = model.snapshot.library.games.reduce(0) { $0 + $1.playtimeTwoWeeksMinutes }
        return "\((Double(minutes) / 60).formatted(.number.precision(.fractionLength(1)))) hours past 2 weeks"
    }
}

private struct RecentActivityRow: View {
    let game: RecentGame
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        Button { model.push(.game(game.appId)) } label: {
            RecentActivityRowContent(game: game, compact: layout.isCompact)
        }
        .buttonStyle(.pressable)
        .steamFocusable("profile.recent.\(game.appId)", lifts: false) { model.push(.game(game.appId)) }
    }
}

private struct RecentActivityRowContent: View {
    let game: RecentGame
    let compact: Bool

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(game.images.header, maxPixel: 600, placeholder: game.name)
                .frame(width: compact ? 112 : 184, height: compact ? 52 : 86)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(game.name)
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !compact {
                        Text(game.totalLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(Steam.textSecondary)
                    }
                }
                Text(compact ? "\(game.totalLabel) · \(game.lastPlayedLabel)" : "Last played \(game.lastPlayedLabel) · \(game.twoWeeksLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(Steam.textSecondary)
                    .lineLimit(1)
                if let a = game.achievements {
                    HStack(spacing: 10) {
                        if !compact {
                            Text("Achievement Progress").captionCaps(size: 9, color: Steam.textMuted)
                        }
                        ProgressBar(a.fraction, height: 4)
                        Text("\(a.unlocked)/\(a.total)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Steam.textSecondary)
                    }
                }
            }
        }
        .padding(10)
        .background(CardBackground(neutral: true))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - Rare achievements

private struct RareAchievementsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let showcase = model.snapshot.user.rareAchievements
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Rare Achievement Showcase")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 10)], spacing: 12) {
                ForEach(Array(showcase.enumerated()), id: \.offset) { i, item in
                    VStack(spacing: 6) {
                        AchievementIcon(achievement: item.achievement, size: 64)
                        Text(item.appName)
                            .font(.system(size: 10))
                            .foregroundStyle(Steam.textSecondary)
                            .lineLimit(1)
                    }
                    .steamFocusable("profile.rare.\(i)", cornerRadius: 4, lifts: false)
                    .help("\(item.achievement.name) — \(item.appName)")
                }
            }
            .padding(12)
            .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}

// MARK: - Screenshot showcase (one large + three small)

private struct ScreenshotShowcase: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let shots = model.snapshot.user.screenshots
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Screenshot Showcase", count: model.snapshot.user.stats.screenshots)
            if let first = shots.first {
                VStack(spacing: 8) {
                    shot(first, index: 0, maxPixel: 1600)
                    HStack(spacing: 8) {
                        ForEach(Array(shots.dropFirst().prefix(3).enumerated()), id: \.offset) { i, s in
                            shot(s, index: i + 1, maxPixel: 700)
                        }
                    }
                }
            }
        }
    }

    private func shot(_ s: ShowcaseScreenshot, index: Int, maxPixel: Int) -> some View {
        RemoteImage(s.url, maxPixel: maxPixel, placeholder: s.appName)
            .aspectRatio(Aspect.screenshot, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                if index == 0 {
                    Text(s.appName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .steamFocusable("profile.shot.\(index)", lifts: false)
            .accessibilityLabel("Screenshot of \(s.appName)")
    }
}

// MARK: - Friends preview

private struct FriendsPreview: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let friends = model.snapshot.friends.sorted { $0.statusOrder < $1.statusOrder }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Friends", count: friends.count) {
                Button { model.push(.friends) } label: { SeeAllLabel() }
                    .buttonStyle(.plain)
            }
            Button { model.push(.friends) } label: {
                FriendsPreviewContent(friends: Array(friends.prefix(8)))
            }
            .buttonStyle(PressableStyle(pressedScale: 0.99))
            .steamFocusable("profile.friends", lifts: false) { model.push(.friends) }
        }
    }
}

private struct FriendsPreviewContent: View {
    let friends: [Friend]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
            ForEach(friends) { friend in
                VStack(spacing: 6) {
                    AvatarView(friend.avatarUrl, status: friend.status, size: 52)
                        .opacity(friend.status == "offline" ? 0.6 : 1)
                    Text(friend.personaName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Steam.statusColor(friend.status))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(CardBackground(neutral: true))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
