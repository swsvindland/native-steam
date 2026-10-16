using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using NativeSteam.Models;

namespace NativeSteam.Services;

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, ReadCommentHandling = JsonCommentHandling.Skip)]
[JsonSerializable(typeof(Snapshot))]
internal sealed partial class SnapshotJsonContext : JsonSerializerContext
{
}

/// <summary>
/// Loads the bundled <c>snapshot.json</c> once and offers the lookups the pages need.
/// </summary>
public static class DataStore
{
    private static Snapshot? _snapshot;
    private static Dictionary<uint, LibraryGame>? _library;
    private static Dictionary<uint, StoreItem>? _store;
    private static Dictionary<string, Friend>? _friends;

    public static Snapshot Snapshot => _snapshot ?? throw new InvalidOperationException("DataStore.Load() has not been called.");

    /// <summary>Path the snapshot was loaded from (for diagnostics).</summary>
    public static string? LoadedFrom { get; private set; }

    public static void Load()
    {
        if (_snapshot is not null) return;

        string path = FindSnapshot();
        using FileStream stream = File.OpenRead(path);
        _snapshot = JsonSerializer.Deserialize(stream, SnapshotJsonContext.Default.Snapshot)
                    ?? throw new InvalidDataException("snapshot.json was empty.");
        LoadedFrom = path;

        _library = new Dictionary<uint, LibraryGame>();
        foreach (LibraryGame g in _snapshot.Library.Games) _library[g.AppId] = g;

        _store = new Dictionary<uint, StoreItem>();
        Store s = _snapshot.Store;
        foreach (StoreItem item in s.Featured.Concat(s.Specials).Concat(s.TopSellers).Concat(s.NewReleases).Concat(s.ComingSoon))
        {
            _store.TryAdd(item.AppId, item);
        }

        _friends = new Dictionary<string, Friend>();
        foreach (Friend f in _snapshot.Friends) _friends[f.SteamId] = f;
    }

    private static string FindSnapshot()
    {
        string bundled = Path.Combine(AppContext.BaseDirectory, "Assets", "snapshot.json");
        if (File.Exists(bundled)) return bundled;

        // Developer fallback: walk up from the exe to the repo's data/ folder.
        DirectoryInfo? dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            string candidate = Path.Combine(dir.FullName, "data", "snapshot.json");
            if (File.Exists(candidate)) return candidate;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("Could not find Assets\\snapshot.json next to the executable.", bundled);
    }

    public static LibraryGame? LibraryGame(uint appId) =>
        _library is not null && _library.TryGetValue(appId, out LibraryGame? g) ? g : null;

    public static StoreItem? StoreItem(uint appId) =>
        _store is not null && _store.TryGetValue(appId, out StoreItem? s) ? s : null;

    public static Friend? Friend(string steamId) =>
        _friends is not null && _friends.TryGetValue(steamId, out Friend? f) ? f : null;

    /// <summary>
    /// Builds a store page model for any app id we know something about: a real store
    /// entry if present, otherwise a best-effort item from charts, hubs or the library.
    /// </summary>
    public static StoreItem? StoreItemOrFallback(uint appId)
    {
        StoreItem? item = StoreItem(appId);
        if (item is not null) return item;

        ChartEntry? chart = Snapshot.Store.MostPlayed.FirstOrDefault(c => c.AppId == appId);
        if (chart is not null)
        {
            return new StoreItem { AppId = appId, Name = chart.Name, Images = chart.Images, Price = chart.Price, Platforms = new Platforms { Windows = true } };
        }

        LibraryGame? game = LibraryGame(appId);
        if (game is not null)
        {
            return new StoreItem
            {
                AppId = appId,
                Name = game.Name,
                Images = game.Images,
                Platforms = new Platforms { Windows = true },
                ControllerSupport = game.ControllerSupport,
                ShortDescription = game.ShortDescription,
                Genres = game.Genres,
                Developers = game.Developers,
                ReleaseDate = game.ReleaseDate,
                Screenshots = game.Screenshots,
            };
        }

        Hub? hub = Snapshot.Community.Hubs.FirstOrDefault(h => h.AppId == appId);
        if (hub is not null)
        {
            return new StoreItem { AppId = appId, Name = hub.Name, Images = hub.Images, Platforms = new Platforms { Windows = true } };
        }
        return null;
    }
}
