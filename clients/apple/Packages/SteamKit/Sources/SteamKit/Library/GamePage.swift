import SwiftUI

/// Library game page (DESIGN §4.2.4).
struct GamePage: View {
    let appId: Int
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        Group {
            if let game = model.libraryGame(appId) {
                content(game)
            } else {
                ContentUnavailableView("Not in your library", systemImage: "questionmark.square.dashed",
                                       description: Text("App \(appId) isn’t in Kestrel’s library."))
            }
        }
        .background(Steam.libraryBottom.ignoresSafeArea())
        .screenChrome(title: model.libraryGame(appId)?.name ?? "Library", large: false, fullBleed: true)
        .focusScope("library.game.\(appId)")
    }

    private func heroHeight(_ width: CGFloat) -> CGFloat {
        layout.isCompact ? 300 : min(max(width / Aspect.hero, 280), 420)
    }

    private func content(_ game: LibraryGame) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GameHero(game: game, height: heroHeight(layout.width))
                pageBody(game)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        // Continue the hero's fade so there is no seam against the page.
                        LinearGradient(colors: [Steam.libraryTop, Steam.libraryBottom], startPoint: .top, endPoint: .bottom)
                            .frame(height: 900)
                    }
            }
        }
        .focusScrollContainer(.vertical)
        .ignoresSafeArea(edges: layout.isCompact ? .top : [])
    }

    private func pageBody(_ game: LibraryGame) -> some View {
                VStack(alignment: .leading, spacing: layout.isCompact ? 24 : 28) {
                    ActionBar(game: game)
                    if layout.isCompact {
                        StatsRow(game: game)
                        mainSections(game)
                        sideSections(game)
                    } else {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 28) { mainSections(game) }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 28) { sideSections(game) }
                                .frame(width: layout.width >= 1100 ? 340 : 280)
                        }
                    }
                }
                .padding(.horizontal, layout.gutter)
                .padding(.bottom, 48)
                .frame(maxWidth: 1600)
    }

    @ViewBuilder
    private func mainSections(_ game: LibraryGame) -> some View {
        if let achievements = game.achievements {
            AchievementsSection(progress: achievements)
        }
        if !game.screenshots.isEmpty {
            ScreenshotsSection(game: game)
        }
    }

    @ViewBuilder
    private func sideSections(_ game: LibraryGame) -> some View {
        FriendsWhoPlay(game: game)
        AboutSection(game: game)
    }
}

// MARK: - Hero

private struct GameHero: View {
    let game: LibraryGame
    let height: CGFloat
    @Environment(\.layout) private var layout

    var body: some View {
        RemoteImage(game.images.hero ?? game.images.capsule, maxPixel: 1920, placeholderColor: Steam.libraryTop)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(layout.isCompact ? 0.35 : 0), location: 0),
                        .init(color: .clear, location: 0.3),
                        .init(color: Steam.libraryTop.opacity(0.65), location: 0.78),
                        .init(color: Steam.libraryTop, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(alignment: .bottomLeading) {
                LogoImage(game.images.logo, fallbackTitle: game.name, maxPixel: 1000, titleSize: layout.isCompact ? 30 : 44)
                    .frame(maxWidth: layout.isCompact ? 240 : 420, maxHeight: layout.isCompact ? 100 : 150, alignment: .bottomLeading)
                    .padding(.horizontal, layout.gutter)
                    .padding(.bottom, layout.isCompact ? 20 : 32)
                    .frame(maxWidth: 1600, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(game.name)
    }
}

// MARK: - Action bar (PLAY / INSTALL + secondary buttons + stats)

private struct ActionBar: View {
    let game: LibraryGame
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let favorite = model.favorites.contains(game.appId)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button {} label: {
                    if game.installed {
                        GradientButtonLabel("PLAY", systemImage: "play.fill", gradient: Steam.play, height: layout.isCompact ? 50 : 52,
                                            expands: layout.isCompact)
                    } else {
                        GradientButtonLabel("INSTALL", systemImage: "arrow.down.to.line", gradient: Steam.install,
                                            subtitle: game.sizeLabel, height: layout.isCompact ? 50 : 52,
                                            expands: layout.isCompact)
                    }
                }
                .buttonStyle(.pressable)
                .frame(maxWidth: layout.isCompact ? .infinity : nil, alignment: .leading)
                .steamFocusable("game.play", cornerRadius: Radius.button, isDefault: true, action: {},
                                secondary: { model.toggleFavorite(game.appId) })
                .accessibilityLabel(game.installed ? "Play \(game.name)" : "Install \(game.name), \(game.sizeLabel)")

                if !layout.isCompact {
                    StatsRow(game: game)
                        .padding(.leading, 18)
                    Spacer(minLength: 12)
                }

                iconButton("game.favorite", favorite ? "star.fill" : "star", active: favorite, label: "Favorite") {
                    model.toggleFavorite(game.appId)
                }
                iconButton("game.settings", "gearshape.fill", label: "Settings") {}
                iconButton("game.info", "info.circle", label: "Info") {}
            }
            if game.updateAvailable || (!game.installed) {
                HStack(spacing: 8) {
                    Image(systemName: game.updateAvailable ? "arrow.triangle.2.circlepath" : "externaldrive")
                        .foregroundStyle(game.updateAvailable ? Steam.accent : Steam.textSecondary)
                    Text(game.updateAvailable ? "Update available · will download before launch" : "\(game.sizeLabel) required · not installed")
                        .foregroundStyle(Steam.textSecondary)
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(layout.isCompact ? 0 : 16)
        .background {
            if !layout.isCompact {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Color.black.opacity(0.25))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.white.opacity(0.05)))
            }
        }
        .padding(.top, layout.isCompact ? 4 : -20)
    }

    private func iconButton(_ id: String, _ symbol: String, active: Bool = false, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconButtonLabel(symbol, active: active, size: layout.isCompact ? 50 : 52)
        }
        .buttonStyle(.pressable)
        .steamFocusable(id, cornerRadius: Radius.button, lifts: false, action: action)
        .accessibilityLabel(label)
    }
}

private struct StatsRow: View {
    let game: LibraryGame
    @Environment(\.layout) private var layout

    var body: some View {
        HStack(alignment: .top, spacing: layout.isCompact ? 16 : 28) {
            stat("Last Played", game.lastPlayedLabel, icon: "calendar")
            stat("Play Time", game.playtimeLabel.replacingOccurrences(of: " on record", with: ""), icon: "clock")
            if let a = game.achievements {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Achievements", systemImage: "trophy")
                        .labelStyle(StatLabelStyle())
                    Text("\(a.unlocked)/\(a.total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                    ProgressBar(a.fraction, height: 4)
                        .frame(width: layout.isCompact ? 80 : 110)
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon).labelStyle(StatLabelStyle())
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Steam.textTitle)
                .lineLimit(1)
        }
    }
}

private struct StatLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.8)
        .textCase(.uppercase)
        .foregroundStyle(Steam.textSecondary)
    }
}

// MARK: - Sections

private struct AchievementsSection: View {
    let progress: AchievementProgress
    @Environment(\.layout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Achievements") {
                Text("\(progress.unlocked) of \(progress.total) · \(Int((progress.fraction * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Steam.textSecondary)
            }
            VStack(alignment: .leading, spacing: 14) {
                ProgressBar(progress.fraction, tint: Steam.accent, height: 6)
                let size: CGFloat = layout.isCompact ? 54 : 60
                FlowLayout(spacing: 10) {
                    ForEach(Array(progress.highlighted.enumerated()), id: \.offset) { i, a in
                        AchievementIcon(achievement: a, size: size)
                            .steamFocusable("game.ach.\(i)", cornerRadius: 4, lifts: false)
                    }
                }
            }
            .padding(14)
            .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}

struct AchievementIcon: View {
    let achievement: Achievement
    var size: CGFloat = 60

    var body: some View {
        RemoteImage(achievement.iconUrl, maxPixel: Int(size * 3), placeholderColor: Steam.surfaceNeutral)
            .frame(width: size, height: size)
            .grayscale(achievement.unlocked ? 0 : 1)
            .opacity(achievement.unlocked ? 1 : 0.38)
            .overlay(alignment: .bottomTrailing) {
                if !achievement.unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Steam.textSecondary)
                        .padding(4)
                        .background(.black.opacity(0.6), in: Circle())
                        .padding(3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(achievement.unlockedLabel.map { "\(achievement.name) — \($0)" } ?? "\(achievement.name) — Locked")
            .accessibilityLabel(achievement.name)
            .accessibilityValue(achievement.unlockedLabel ?? "Locked")
    }
}

private struct ScreenshotsSection: View {
    let game: LibraryGame
    @Environment(\.layout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Screenshots", count: game.screenshots.count) { SeeAllLabel() }
            if layout.isCompact {
                Shelf(Array(game.screenshots.enumerated()).map { IndexedScreenshot(index: $0.offset, shot: $0.element) }, spacing: 10) { e in
                    RemoteImage(e.shot.thumbnail, maxPixel: 700)
                        .aspectRatio(Aspect.screenshot, contentMode: .fit)
                        .frame(width: 260)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                        .steamFocusable("game.shot.\(e.index)")
                }
            } else {
                // Eager grid so every thumbnail registers for spatial focus.
                let shots = Array(game.screenshots.prefix(6).enumerated())
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(stride(from: 0, to: shots.count, by: 3).map { $0 }, id: \.self) { start in
                        GridRow {
                            ForEach(shots[start..<min(start + 3, shots.count)], id: \.offset) { i, shot in
                                RemoteImage(shot.thumbnail, maxPixel: 700)
                                    .aspectRatio(Aspect.screenshot, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                                    .steamFocusable("game.shot.\(i)")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct IndexedScreenshot: Identifiable {
    let index: Int
    let shot: Screenshot
    var id: Int { index }
}

private struct FriendsWhoPlay: View {
    let game: LibraryGame
    @Environment(AppModel.self) private var model

    var body: some View {
        let friends = game.friendsPlaying.compactMap { model.friend($0) }.sorted { $0.statusOrder < $1.statusOrder }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Friends Who Play", count: friends.count)
            if friends.isEmpty {
                Text("None of your friends play this yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Steam.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(friends) { friend in
                        FriendRow(friend: friend, focusID: "game.friend.\(friend.steamId)", playing: friend.game?.appId == game.appId)
                    }
                }
            }
        }
        .padding(14)
        .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

private struct AboutSection: View {
    let game: LibraryGame

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("About")
            if let d = game.shortDescription {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundStyle(Steam.textBody)
                    .lineSpacing(3)
            }
            VStack(alignment: .leading, spacing: 8) {
                if !game.developers.isEmpty { info("Developer", game.developers.joined(separator: ", "), link: true) }
                if let date = game.releaseDate { info("Release Date", date) }
                info("Size on Disk", game.installed ? game.sizeLabel : "Not installed (\(game.sizeLabel))")
            }
            HStack(spacing: 8) {
                if game.controllerSupport == "full" { ControllerBadge(full: true) }
                else if game.controllerSupport == "partial" { ControllerBadge(full: false) }
            }
            if !game.genres.isEmpty { FlowChips(items: game.genres) }
        }
        .padding(14)
        .background(Steam.surfaceNeutral.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func info(_ label: String, _ value: String, link: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).captionCaps(size: 10, color: Steam.textMuted)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(link ? Steam.accentLink : Steam.textBody)
        }
    }
}
