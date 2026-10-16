import SwiftUI

/// LIBRARY tab (DESIGN §4.2).
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    private var showsSidebar: Bool { layout.width >= 1000 }

    var body: some View {
        HStack(spacing: 0) {
            if showsSidebar {
                CollectionsSidebar()
                    .frame(width: 248)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: layout.isCompact ? 24 : 32) {
                    if !showsSidebar {
                        if layout.isCompact { LibrarySearchField() }
                        CollectionChips()
                    }
                    if model.libraryFilter.isEmpty {
                        RecentGamesSection()
                    }
                    AllGamesSection()
                }
                .padding(.horizontal, layout.gutter)
                .padding(.top, layout.isCompact ? 4 : 24)
                .padding(.bottom, 48)
                .frame(maxWidth: 1600)
                .frame(maxWidth: .infinity)
            }
            .focusScrollContainer(.vertical)
            .background(Steam.libraryBackground.ignoresSafeArea())
        }
        .screenChrome(title: "Library")
        .focusScope("library")
        #if os(iOS)
        .toolbar {
            if layout.isCompact {
                ToolbarItem(placement: .topBarTrailing) { SortMenu(compact: true) }
            }
        }
        #endif
    }
}

// MARK: - Collections

private func collectionIcon(_ collection: GameCollection) -> String {
    switch collection.id {
    case "all": "square.grid.2x2"
    case "favorites": "star"
    case "installed": "arrow.down.circle"
    case "controller": "gamecontroller"
    default: collection.kind == "user" ? "folder" : "sparkles"
    }
}

private struct CollectionsSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchField()
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sectionLabel("Library")
                    ForEach(model.snapshot.library.collections.filter { $0.kind == "dynamic" }) { c in
                        CollectionRow(collection: c)
                    }
                    sectionLabel("Collections").padding(.top, 14)
                    ForEach(model.snapshot.library.collections.filter { $0.kind != "dynamic" }) { c in
                        CollectionRow(collection: c)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.never)
            .steamFocusSection()

            Divider().overlay(Steam.divider)
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add a Game")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Steam.textSecondary)
            .padding(14)
        }
        .background(Steam.bgChrome)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.black.opacity(0.4)).frame(width: 1) }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).captionCaps(size: 11, color: Steam.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

private struct CollectionRow: View {
    let collection: GameCollection
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.collectionID == collection.id
        Button { select() } label: {
            CollectionRowLabel(
                icon: collectionIcon(collection),
                name: collection.name,
                count: model.count(of: collection),
                selected: selected
            )
        }
        .buttonStyle(.pressable)
        .steamFocusable("lib.collection.\(collection.id)", cornerRadius: 4, scales: false, lifts: false, action: select)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select() {
        withAnimation(.easeOut(duration: 0.2)) { model.collectionID = collection.id }
    }
}

private struct CollectionRowLabel: View {
    let icon: String
    let name: String
    let count: Int
    let selected: Bool
    @Environment(\.cardHighlighted) private var highlighted

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: selected ? icon + ".fill" : icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Steam.accentLink : Steam.textSecondary)
                .frame(width: 18)
            Text(name)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Steam.textTitle : Steam.textBody)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Steam.textMuted)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(selected ? Steam.accent.opacity(0.18) : (highlighted ? Steam.surfaceHover.opacity(0.7) : .clear))
        )
        .overlay(alignment: .leading) {
            if selected {
                Capsule().fill(Steam.accent).frame(width: 3, height: 18)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CollectionChips: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.snapshot.library.collections) { c in
                    Button { select(c) } label: {
                        ChipLabel(c.name, selected: model.collectionID == c.id, count: model.count(of: c))
                    }
                    .buttonStyle(.pressable)
                    .steamFocusable("lib.collection.\(c.id)", cornerRadius: 16, lifts: false) { select(c) }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, layout.gutter, for: .scrollContent)
        .focusScrollContainer(.horizontal, margin: layout.gutter)
        .padding(.horizontal, -layout.gutter)
        .padding(.vertical, -8)
    }

    private func select(_ c: GameCollection) {
        withAnimation(.easeOut(duration: 0.2)) { model.collectionID = c.id }
    }
}

private struct LibrarySearchField: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.layout) private var layout
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Steam.textSecondary)
            TextField(layout.isCompact ? "Search your library" : "Filter by name", text: $model.libraryFilter)
                .textFieldStyle(.plain)
                .focused($focused)
                .foregroundStyle(Steam.textTitle)
            if !model.libraryFilter.isEmpty {
                Button { model.libraryFilter = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Steam.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: layout.isCompact ? 40 : 32)
        .background(RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 4).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 4).strokeBorder(focused ? Steam.accent : .clear, lineWidth: 1.5))
        .steamFocusable("lib.search", cornerRadius: 6, scales: false, lifts: false) { focused = true }
        .onChange(of: model.searchRequest) { _, _ in focused = true }
        .onChange(of: focused) { _, f in engine.textInputActive = f }
    }
}

// MARK: - Recent games

private struct RecentGamesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let height: CGFloat = layout.isCompact ? 150 : 210
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recent Games") { SeeAllLabel() }
            Shelf(Array(model.recentGames.enumerated()).map { RecentEntry(index: $0.offset, game: $0.element) }, spacing: 14) { entry in
                RecentGameCard(
                    game: entry.game,
                    width: (entry.index == 0 && !layout.isCompact) ? height * 2.6 : (layout.isCompact ? height * 1.8 : height * 1.3),
                    height: height,
                    isDefault: entry.index == 0
                )
            }
        }
    }
}

private struct RecentEntry: Identifiable {
    let index: Int
    let game: LibraryGame
    var id: Int { game.appId }
}

private struct RecentGameCard: View {
    let game: LibraryGame
    let width: CGFloat
    let height: CGFloat
    var isDefault = false
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) {
                RecentGameArt(game: game, width: width, height: height)
            }
            .buttonStyle(.pressable)
            .steamFocusable("lib.recent.\(game.appId)", isDefault: isDefault, action: open,
                            secondary: { model.toggleFavorite(game.appId) })
            .accessibilityLabel("\(game.name), last played \(game.lastPlayedLabel)")

            HStack(spacing: 6) {
                Text(game.lastPlayedLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Steam.textBody)
                if let two = game.playtimeTwoWeeksLabel {
                    Text("· \(two)")
                        .font(.system(size: 12))
                        .foregroundStyle(Steam.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .leading)
        }
    }

    private func open() { model.push(.game(game.appId)) }
}

private struct RecentGameArt: View {
    let game: LibraryGame
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RemoteImage(game.images.wide, maxPixel: 1400, placeholder: nil, placeholderColor: Steam.surfaceNeutral)
            .frame(width: width, height: height)
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            )
            .overlay(alignment: .bottomLeading) {
                LogoImage(game.images.logo, fallbackTitle: game.name, maxPixel: 800, titleSize: 20)
                    .frame(maxWidth: width * 0.62, maxHeight: height * 0.42, alignment: .bottomLeading)
                    .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// MARK: - All games grid

private struct AllGamesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout
    @State private var gridWidth: CGFloat = 0

    var body: some View {
        let games = model.visibleGames
        let title = model.libraryFilter.isEmpty ? (model.currentCollection?.name ?? "All Games") : "Results"
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title, count: games.count) {
                if !layout.isCompact { SortMenu(compact: false) }
            }
            if games.isEmpty {
                Text("Nothing here yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Steam.textSecondary)
                    .padding(.vertical, 32)
            } else {
                PortraitGrid(games: games, width: gridWidth)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { gridWidth = $0 }
    }
}

private struct PortraitGrid: View {
    let games: [LibraryGame]
    let width: CGFloat
    @Environment(\.layout) private var layout

    var body: some View {
        let spacing: CGFloat = layout.isCompact ? 10 : 18
        let columns = layout.isCompact ? 3 : max(3, Int((width + spacing) / (152 + spacing)))
        let rows = stride(from: 0, to: games.count, by: columns).map { Array(games[$0..<min($0 + columns, games.count)]) }
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing + 4) {
            ForEach(rows, id: \.first!.appId) { row in
                GridRow {
                    ForEach(row) { game in
                        PortraitCard(game: game)
                    }
                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: games.map(\.appId))
    }
}

struct PortraitCard: View {
    let game: LibraryGame
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: open) {
            PortraitCardContent(game: game, favorite: model.favorites.contains(game.appId))
        }
        .buttonStyle(.pressable)
        .steamFocusable("lib.grid.\(game.appId)", action: open, secondary: { model.toggleFavorite(game.appId) })
        .contextMenu {
            Button(game.installed ? "Play" : "Install", systemImage: game.installed ? "play.fill" : "arrow.down.circle") {}
            Button(model.favorites.contains(game.appId) ? "Remove from Favorites" : "Add to Favorites", systemImage: "star") {
                model.toggleFavorite(game.appId)
            }
            Button("Properties…", systemImage: "gearshape") { open() }
        }
        .accessibilityLabel(game.name)
        .accessibilityValue(game.installed ? "Installed" : "Not installed")
    }

    private func open() { model.push(.game(game.appId)) }
}

private struct PortraitCardContent: View {
    let game: LibraryGame
    let favorite: Bool
    @Environment(\.cardHighlighted) private var highlighted

    var body: some View {
        RemoteImage(game.images.portrait ?? game.images.header, maxPixel: 600, placeholder: game.name, placeholderColor: Steam.surfaceNeutral)
            .aspectRatio(Aspect.portrait, contentMode: .fit)
            .opacity(game.installed ? 1 : 0.65)
            .overlay(alignment: .bottom) {
                if highlighted {
                    Text(game.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if favorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFC82C))
                        .padding(5)
                        .background(.black.opacity(0.6), in: Circle())
                        .padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if game.updateAvailable {
                    Circle()
                        .fill(Steam.accent)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                        .padding(8)
                        .accessibilityLabel("Update available")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !game.installed && !highlighted {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.9), .black.opacity(0.55))
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: highlighted)
    }
}

struct SortMenu: View {
    let compact: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Menu {
            Picker("Sort by", selection: $model.librarySort) {
                ForEach(LibrarySort.allCases) { sort in
                    Text(sort.label).tag(sort)
                }
            }
        } label: {
            if compact {
                Image(systemName: "arrow.up.arrow.down")
            } else {
                HStack(spacing: 6) {
                    Text("Sort by").foregroundStyle(Steam.textSecondary)
                    Text(model.librarySort.label).foregroundStyle(Steam.textBody)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Steam.textSecondary)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Sort by \(model.librarySort.label)")
    }
}
