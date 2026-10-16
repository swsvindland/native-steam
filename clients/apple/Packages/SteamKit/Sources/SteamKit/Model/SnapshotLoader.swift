import Foundation

public enum SnapshotError: Error, CustomStringConvertible {
    case notFound

    public var description: String {
        "snapshot.json was not found in the app bundle. It is referenced from ../../data/snapshot.json in project.yml."
    }
}

extension Snapshot {
    /// Decodes a snapshot from raw JSON.
    public static func decode(_ data: Data) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// Loads the snapshot bundled with the app (`data/snapshot.json`, referenced in place).
    public static func loadBundled(bundle: Bundle = .main) throws -> Snapshot {
        if let override = ProcessInfo.processInfo.environment["NATIVE_STEAM_SNAPSHOT"] {
            return try decode(Data(contentsOf: URL(fileURLWithPath: override)))
        }
        guard let url = bundle.url(forResource: "snapshot", withExtension: "json") else {
            throw SnapshotError.notFound
        }
        return try decode(Data(contentsOf: url))
    }
}

/// Fast lookups over a snapshot. Built once at launch.
public struct SnapshotIndex: Sendable {
    public let libraryGames: [Int: LibraryGame]
    public let storeItems: [Int: StoreItem]
    public let chartEntries: [Int: ChartEntry]
    public let friends: [String: Friend]

    public init(_ snapshot: Snapshot) {
        libraryGames = Dictionary(snapshot.library.games.map { ($0.appId, $0) }, uniquingKeysWith: { a, _ in a })
        let store = snapshot.store
        let all = store.featured + store.specials + store.topSellers + store.newReleases + store.comingSoon
        storeItems = Dictionary(all.map { ($0.appId, $0) }, uniquingKeysWith: { a, _ in a })
        chartEntries = Dictionary(store.mostPlayed.map { ($0.appId, $0) }, uniquingKeysWith: { a, _ in a })
        friends = Dictionary(snapshot.friends.map { ($0.steamId, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

// MARK: - Convenience

extension Images {
    /// Best wide artwork for a landscape card: hero, falling back to capsule.
    public var wide: String { hero ?? capsule }
    /// Best page-header artwork for a store page.
    public var pageHeader: String { hero ?? background ?? capsule }
}

extension Friend {
    public var statusOrder: Int {
        switch status {
        case "inGame": 0
        case "online": 1
        case "away": 2
        default: 3
        }
    }
}

extension StoreItem {
    /// Builds a minimal store page model for apps only known from charts or the library.
    public init(chart: ChartEntry, library: LibraryGame?) {
        self.init(
            appId: chart.appId,
            name: chart.name,
            images: chart.images,
            price: chart.price,
            platforms: Platforms(windows: true, mac: false, linux: false),
            controllerSupport: library?.controllerSupport,
            shortDescription: library?.shortDescription,
            genres: library?.genres ?? [],
            developers: library?.developers ?? [],
            releaseDate: library?.releaseDate,
            comingSoon: false,
            review: nil,
            screenshots: library?.screenshots ?? [],
            metacritic: nil,
            discountEndsLabel: nil
        )
    }

    public init(library game: LibraryGame) {
        self.init(
            appId: game.appId,
            name: game.name,
            images: game.images,
            price: nil,
            platforms: Platforms(windows: true, mac: false, linux: false),
            controllerSupport: game.controllerSupport,
            shortDescription: game.shortDescription,
            genres: game.genres,
            developers: game.developers,
            releaseDate: game.releaseDate,
            comingSoon: false,
            review: nil,
            screenshots: game.screenshots,
            metacritic: nil,
            discountEndsLabel: nil
        )
    }
}
