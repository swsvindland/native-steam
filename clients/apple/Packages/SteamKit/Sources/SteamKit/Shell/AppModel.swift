import Observation
import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case store, library, community, profile

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .store: "storefront.fill"
        case .library: "square.grid.2x2.fill"
        case .community: "person.2.fill"
        case .profile: "person.crop.square.fill"
        }
    }

    public var shortcutKey: KeyEquivalent {
        switch self {
        case .store: "1"
        case .library: "2"
        case .community: "3"
        case .profile: "4"
        }
    }
}

public enum Route: Hashable, Sendable {
    case storeApp(Int)
    case game(Int)
    case friends
}

/// One navigation path per tab (each tab is its own NavigationStack).
public struct TabPaths: Equatable, Sendable {
    public var store: [Route] = []
    public var library: [Route] = []
    public var community: [Route] = []
    public var profile: [Route] = []

    public subscript(_ tab: AppTab) -> [Route] {
        get {
            switch tab {
            case .store: store
            case .library: library
            case .community: community
            case .profile: profile
            }
        }
        set {
            switch tab {
            case .store: store = newValue
            case .library: library = newValue
            case .community: community = newValue
            case .profile: profile = newValue
            }
        }
    }
}

public enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case alphabetical, recent, hours

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .alphabetical: "Alphabetical"
        case .recent: "Recently Played"
        case .hours: "Hours Played"
        }
    }
}

public enum CommunitySection: String, CaseIterable, Identifiable, Sendable {
    case activity, news, hubs

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .activity: "Activity"
        case .news: "News"
        case .hubs: "Hubs"
        }
    }
}

/// Launch arguments used for screenshot automation:
/// `-tab store|library|community|profile`, `-game <appId>`, `-app <appId>`, `-input gamepad`.
public struct LaunchOptions: Sendable {
    public var tab: AppTab?
    public var game: Int?
    public var app: Int?
    public var forceGamepad: Bool
    public var friends: Bool

    public static var current: LaunchOptions {
        let d = UserDefaults.standard
        let tab = d.string(forKey: "tab").flatMap { AppTab(rawValue: $0.lowercased()) }
        let game = d.string(forKey: "game").flatMap { Int($0) }
        let app = d.string(forKey: "app").flatMap { Int($0) }
        let input = d.string(forKey: "input")?.lowercased()
        return LaunchOptions(
            tab: tab, game: game, app: app,
            forceGamepad: input == "gamepad",
            friends: d.bool(forKey: "friends")
        )
    }

    /// True when launched with any automation argument (macOS pins the window to 1440×900).
    public var isAutomated: Bool { tab != nil || game != nil || app != nil || forceGamepad }
}

@Observable
@MainActor
public final class AppModel {
    public let snapshot: Snapshot
    public let index: SnapshotIndex
    public let launch: LaunchOptions

    public var tab: AppTab = .store
    public var paths = TabPaths()

    public var favorites: Set<Int>
    public var wishlist: Set<Int> = []

    public var collectionID: String
    public var librarySort: LibrarySort = .alphabetical
    public var libraryFilter = ""
    public var storeQuery = ""
    public var communitySection: CommunitySection = .activity

    /// Bumped by Y / ⌘F; search fields observe it and take focus.
    public var searchRequest = 0

    public init(snapshot: Snapshot, launch: LaunchOptions = .current) {
        self.snapshot = snapshot
        self.index = SnapshotIndex(snapshot)
        self.launch = launch
        self.favorites = Set(snapshot.library.games.filter(\.favorite).map(\.appId))
        self.collectionID = snapshot.library.collections.first?.id ?? "all"

        if let tab = launch.tab { self.tab = tab }
        if let game = launch.game {
            if launch.tab == nil { tab = .library }
            paths[tab].append(.game(game))
        } else if let app = launch.app {
            if launch.tab == nil { tab = .store }
            paths[tab].append(.storeApp(app))
        } else if launch.friends {
            if launch.tab == nil { tab = .profile }
            paths[tab].append(.friends)
        }
    }

    public var persona: String { snapshot.user.personaName }

    public func title(for tab: AppTab) -> String {
        switch tab {
        case .store: "Store"
        case .library: "Library"
        case .community: "Community"
        case .profile: persona
        }
    }

    // MARK: Navigation

    public var currentPath: [Route] { paths[tab] }
    public var canGoBack: Bool { !currentPath.isEmpty }

    public func select(_ newTab: AppTab) {
        if newTab == tab {
            // Re-selecting the active tab pops to its root, like iOS.
            paths[tab] = []
        } else {
            tab = newTab
        }
    }

    public func push(_ route: Route) {
        paths[tab].append(route)
    }

    @discardableResult
    public func pop() -> Bool {
        guard !paths[tab].isEmpty else { return false }
        paths[tab].removeLast()
        return true
    }

    public func nextTab() { cycleTab(by: 1) }
    public func previousTab() { cycleTab(by: -1) }

    private func cycleTab(by delta: Int) {
        let all = AppTab.allCases
        let i = all.firstIndex(of: tab) ?? 0
        tab = all[(i + delta + all.count) % all.count]
    }

    public func requestSearch() { searchRequest += 1 }

    /// LT / RT: page between Library collections or Community sections.
    public func pageSection(by delta: Int) {
        switch tab {
        case .library:
            let ids = snapshot.library.collections.map(\.id)
            guard let i = ids.firstIndex(of: collectionID) else { return }
            collectionID = ids[(i + delta + ids.count) % ids.count]
        case .community:
            let all = CommunitySection.allCases
            let i = all.firstIndex(of: communitySection) ?? 0
            communitySection = all[(i + delta + all.count) % all.count]
        default:
            break
        }
    }

    // MARK: Actions (visual only)

    public func toggleFavorite(_ appId: Int) {
        if favorites.contains(appId) { favorites.remove(appId) } else { favorites.insert(appId) }
    }

    public func toggleWishlist(_ appId: Int) {
        if wishlist.contains(appId) { wishlist.remove(appId) } else { wishlist.insert(appId) }
    }

    // MARK: Lookups

    public func storeItem(_ appId: Int) -> StoreItem? {
        if let item = index.storeItems[appId] { return item }
        if let chart = index.chartEntries[appId] { return StoreItem(chart: chart, library: index.libraryGames[appId]) }
        if let game = index.libraryGames[appId] { return StoreItem(library: game) }
        return nil
    }

    public func libraryGame(_ appId: Int) -> LibraryGame? { index.libraryGames[appId] }
    public func friend(_ id: String) -> Friend? { index.friends[id] }

    public var recentGames: [LibraryGame] {
        snapshot.library.recentAppIds.compactMap { index.libraryGames[$0] }
    }

    public var currentCollection: GameCollection? {
        snapshot.library.collections.first { $0.id == collectionID }
    }

    public func count(of collection: GameCollection) -> Int {
        if collection.id == "favorites" { return favorites.count }
        return collection.appIds.count
    }

    /// Games in the selected collection, filtered by the library search and sorted.
    public var visibleGames: [LibraryGame] {
        var games: [LibraryGame]
        if let collection = currentCollection {
            if collection.id == "favorites" {
                games = snapshot.library.games.filter { favorites.contains($0.appId) }
            } else {
                let ids = Set(collection.appIds)
                games = snapshot.library.games.filter { ids.contains($0.appId) }
            }
        } else {
            games = snapshot.library.games
        }
        let q = libraryFilter.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            games = games.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }
        switch librarySort {
        case .alphabetical:
            games.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            games.sort { ($0.lastPlayed ?? "") > ($1.lastPlayed ?? "") }
        case .hours:
            games.sort { $0.playtimeMinutes > $1.playtimeMinutes }
        }
        return games
    }

    /// Store search results across every store list.
    public var storeResults: [StoreItem] {
        let q = storeQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let s = snapshot.store
        var seen = Set<Int>()
        return (s.featured + s.specials + s.topSellers + s.newReleases + s.comingSoon).filter {
            guard !seen.contains($0.appId) else { return false }
            seen.insert($0.appId)
            return $0.name.localizedCaseInsensitiveContains(q)
                || $0.genres.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    public var onlineFriendCount: Int {
        snapshot.friends.filter { $0.status != "offline" }.count
    }
}
