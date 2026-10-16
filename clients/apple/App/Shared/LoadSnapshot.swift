import SteamKit

/// The snapshot is bundled from `data/snapshot.json` (referenced in place by project.yml).
/// Without it there is nothing to show, so failing loudly is the right call.
@MainActor
func loadSnapshotOrDie() -> Snapshot {
    do {
        return try Snapshot.loadBundled()
    } catch {
        fatalError("Native Steam could not load snapshot.json: \(error)")
    }
}
