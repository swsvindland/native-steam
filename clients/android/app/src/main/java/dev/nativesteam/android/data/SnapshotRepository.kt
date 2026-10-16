package dev.nativesteam.android.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

/** Loads the bundled `snapshot.json` (copied from the repo's `data/` dir at build time). */
object SnapshotRepository {
    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        explicitNulls = false
    }

    @Volatile
    private var cached: Snapshot? = null

    suspend fun load(context: Context): Snapshot = cached ?: withContext(Dispatchers.IO) {
        val text = context.assets.open("snapshot.json").bufferedReader().use { it.readText() }
        json.decodeFromString(Snapshot.serializer(), text).also { cached = it }
    }
}

/** Fast lookups over a decoded [Snapshot]. Built once per snapshot. */
class SnapshotIndex(val snapshot: Snapshot) {
    private val libraryById = snapshot.library.games.associateBy { it.appId }
    private val friendsById = snapshot.friends.associateBy { it.steamId }
    private val storeById: Map<Int, StoreItem> = buildMap {
        with(snapshot.store) {
            (featured + specials + topSellers + newReleases + comingSoon).forEach { putIfAbsent(it.appId, it) }
        }
    }

    /** Every unique store item, in shelf order. Used by store search. */
    val allStoreItems: List<StoreItem> = storeById.values.toList()

    fun libraryGame(appId: Int): LibraryGame? = libraryById[appId]
    fun friend(steamId: String): Friend? = friendsById[steamId]
    fun owns(appId: Int): Boolean = appId in libraryById

    /**
     * A store page for any app id. Apps that only appear in charts, hubs or the library
     * get a page synthesised from whatever data the snapshot has for them.
     */
    fun storeItem(appId: Int): StoreItem? {
        storeById[appId]?.let { return it }
        libraryById[appId]?.let { g ->
            return StoreItem(
                appId = g.appId,
                name = g.name,
                images = g.images,
                controllerSupport = g.controllerSupport,
                shortDescription = g.shortDescription,
                genres = g.genres,
                developers = g.developers,
                releaseDate = g.releaseDate,
                screenshots = g.screenshots,
                platforms = Platforms(windows = true),
                price = snapshot.store.mostPlayed.firstOrNull { it.appId == appId }?.price,
            )
        }
        snapshot.store.mostPlayed.firstOrNull { it.appId == appId }?.let { c ->
            return StoreItem(appId = c.appId, name = c.name, images = c.images, price = c.price, platforms = Platforms(windows = true))
        }
        snapshot.community.hubs.firstOrNull { it.appId == appId }?.let { h ->
            return StoreItem(appId = h.appId, name = h.name, images = h.images, platforms = Platforms(windows = true))
        }
        return null
    }

    fun collection(id: String): Collection? = snapshot.library.collections.firstOrNull { it.id == id }
}
