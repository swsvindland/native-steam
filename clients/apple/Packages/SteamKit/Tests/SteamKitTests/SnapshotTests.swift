import Foundation
import Testing
@testable import SteamKit

private func loadSnapshot() throws -> Snapshot {
    // Tests/SteamKitTests/SnapshotTests.swift -> repo root /data/snapshot.json
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SnapshotTests.swift
        .deletingLastPathComponent() // SteamKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SteamKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // apple
        .deletingLastPathComponent() // clients
        .appendingPathComponent("data/snapshot.json")
    return try Snapshot.decode(Data(contentsOf: url))
}

@Test func decodesBundledSnapshot() throws {
    let snapshot = try loadSnapshot()
    #expect(snapshot.schemaVersion == 1)
    #expect(snapshot.user.personaName == "Kestrel")
    #expect(!snapshot.store.featured.isEmpty)
    #expect(snapshot.library.collections.first?.name == "All Games")
    #expect(snapshot.library.games.count == snapshot.library.collections.first?.appIds.count)
}

@Test func indexResolvesHadesII() throws {
    let index = SnapshotIndex(try loadSnapshot())
    let game = try #require(index.libraryGames[1145350])
    #expect(game.name == "Hades II")
}

@Test func spatialFocusPrefersAlignedNeighbours() {
    let origin = CGRect(x: 0, y: 0, width: 100, height: 150)
    let candidates: [String: FocusFrame] = [
        "right": FocusFrame(rect: CGRect(x: 120, y: 0, width: 100, height: 150), containers: [], isDefault: false, isChrome: false),
        "below": FocusFrame(rect: CGRect(x: 0, y: 170, width: 100, height: 150), containers: [], isDefault: false, isChrome: false),
        "diagonal": FocusFrame(rect: CGRect(x: 120, y: 170, width: 100, height: 150), containers: [], isDefault: false, isChrome: false),
    ]
    #expect(FocusEngine.nearest(from: origin, direction: .right, candidates: candidates) == "right")
    #expect(FocusEngine.nearest(from: origin, direction: .down, candidates: candidates) == "below")
    #expect(FocusEngine.nearest(from: origin, direction: .left, candidates: candidates) == nil)
}
