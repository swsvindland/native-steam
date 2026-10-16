using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;

namespace NativeSteam.ViewModels;

public sealed class LibraryGameVM : Observable
{
    private bool _isFavorite;

    public LibraryGameVM(LibraryGame g, double cardWidth = 0)
    {
        _isFavorite = g.Favorite;
        Game = g;
        AppId = g.AppId;
        Name = g.Name;
        Portrait = g.Images.Portrait ?? g.Images.Capsule;
        PortraitIsFallback = g.Images.Portrait is null;
        Hero = g.Images.Hero ?? g.Images.Capsule;
        Logo = g.Images.Logo ?? "";
        LogoVisibility = Vis.Of(g.Images.Logo);
        NameFallbackVisibility = Vis.Of(g.Images.Logo is null);
        Header = g.Images.Header;
        Capsule = g.Images.Capsule;
        LastPlayedLabel = g.LastPlayedLabel;
        PlaytimeLabel = g.PlaytimeLabel;
        CoverOpacity = g.Installed ? 1.0 : 0.65;
        NotInstalledVisibility = Vis.Of(!g.Installed);
        UpdateVisibility = Vis.Of(g.UpdateAvailable);
        CardWidth = cardWidth;
        StatusLine = g.Installed ? g.PlaytimeLabel : $"Not installed · {g.SizeLabel}";
    }

    public LibraryGame Game { get; }
    public uint AppId { get; }
    public string Name { get; }
    public string Portrait { get; }
    public bool PortraitIsFallback { get; }
    public string Hero { get; }
    public string Logo { get; }
    public Visibility LogoVisibility { get; }
    public Visibility NameFallbackVisibility { get; }
    public string Header { get; }
    public string Capsule { get; }
    public string LastPlayedLabel { get; }
    public string PlaytimeLabel { get; }
    public string StatusLine { get; }
    public double CoverOpacity { get; }
    public Visibility NotInstalledVisibility { get; }
    public Visibility UpdateVisibility { get; }
    public double CardWidth { get; set; }

    /// <summary>Toggled with X on a gamepad (visual only; the snapshot is never written).</summary>
    public bool IsFavorite
    {
        get => _isFavorite;
        set
        {
            if (Set(ref _isFavorite, value)) Raise(nameof(FavoriteVisibility));
        }
    }

    public Visibility FavoriteVisibility => Vis.Of(IsFavorite);
}

public sealed class CollectionVM : Observable
{
    private bool _isSelected;

    public CollectionVM(Collection c)
    {
        Collection = c;
        Id = c.Id;
        Name = c.Name;
        Count = c.AppIds.Count;
        CountLabel = Count.ToString(CultureInfo.InvariantCulture);
        Glyph = c.Id switch
        {
            "all" => Glyphs.Library,
            "favorites" => Glyphs.StarFilled,
            "installed" => Glyphs.Download,
            "controller" => Glyphs.Gamepad,
            _ => "", // Folder
        };
        AppIds = new HashSet<uint>(c.AppIds);
    }

    public Collection Collection { get; }
    public string Id { get; }
    public string Name { get; }
    public int Count { get; }
    public string CountLabel { get; }
    public string Glyph { get; }
    public HashSet<uint> AppIds { get; }

    public bool IsSelected
    {
        get => _isSelected;
        set
        {
            if (Set(ref _isSelected, value))
            {
                Raise(nameof(ChipBackground));
                Raise(nameof(ChipForeground));
            }
        }
    }

    public Brush ChipBackground => IsSelected ? Palette.Brush(Palette.Accent) : Palette.Brush("#1fffffff");
    public Brush ChipForeground => IsSelected ? Palette.Brush(Palette.TextTitle) : Palette.Brush(Palette.TextBody);
}

public enum LibrarySort
{
    Alphabetical,
    RecentlyPlayed,
    HoursPlayed,
}

/// <summary>Everything the Library game page shows (DESIGN.md §4.2.4).</summary>
public sealed class GameDetailVM
{
    public GameDetailVM(LibraryGame g)
    {
        Game = g;
        AppId = g.AppId;
        Name = g.Name;
        Hero = g.Images.Hero ?? g.Images.Background ?? g.Images.Capsule;
        Logo = g.Images.Logo ?? "";
        LogoVisibility = Vis.Of(g.Images.Logo);
        TitleFallbackVisibility = Vis.Of(g.Images.Logo is null);
        Header = g.Images.Header;

        PlayVisibility = Vis.Of(g.Installed);
        InstallVisibility = Vis.Of(!g.Installed);
        SizeLabel = g.SizeLabel;
        UpdateVisibility = Vis.Of(g.UpdateAvailable);
        FavoriteGlyph = g.Favorite ? Glyphs.StarFilled : Glyphs.Star;
        FavoriteBrush = g.Favorite ? Palette.Brush("#ffc82c") : Palette.Brush(Palette.TextBody);

        LastPlayedLabel = g.LastPlayedLabel;
        PlaytimeLabel = g.PlaytimeLabel;
        TwoWeeksLabel = g.PlaytimeTwoWeeksLabel ?? "";
        TwoWeeksVisibility = Vis.Of(g.PlaytimeTwoWeeksLabel);

        AchievementProgress? a = g.Achievements;
        HasAchievements = a is not null && a.Total > 0;
        AchievementsVisibility = Vis.Of(HasAchievements);
        NoAchievementsVisibility = Vis.Of(!HasAchievements);
        AchievementsLabel = a is null ? "—" : $"{a.Unlocked.ToString(CultureInfo.InvariantCulture)}/{a.Total.ToString(CultureInfo.InvariantCulture)}";
        AchievementsPercent = a is null ? 0 : Math.Clamp(a.Fraction * 100.0, 0, 100);
        AchievementsSummary = a is null
            ? ""
            : $"You've unlocked {a.Unlocked.ToString(CultureInfo.InvariantCulture)} of {a.Total.ToString(CultureInfo.InvariantCulture)} ({Math.Round(a.Fraction * 100).ToString(CultureInfo.InvariantCulture)}%)";
        Achievements = a?.Highlighted.Select(x => new AchievementVM(x)).ToList() ?? new List<AchievementVM>();

        Friends = g.FriendsPlaying
            .Select(DataStore.Friend)
            .Where(f => f is not null)
            .Select(f => new FriendVM(f!))
            .ToList();
        FriendsTitle = Friends.Count == 1 ? "1 friend who plays" : $"{Friends.Count.ToString(CultureInfo.InvariantCulture)} friends who play";
        FriendsVisibility = Vis.Of(Friends.Count > 0);
        NoFriendsVisibility = Vis.Of(Friends.Count == 0);

        Screenshots = g.Screenshots.Select((s, i) => new ScreenshotVM(s.Thumbnail, s.Full, g.Name, i)).ToList();
        ScreenshotsVisibility = Vis.Of(Screenshots.Count > 0);

        Description = string.IsNullOrWhiteSpace(g.ShortDescription) ? "No description available." : g.ShortDescription!;
        Developer = g.Developers.Count > 0 ? string.Join(", ", g.Developers) : "—";
        ReleaseDate = string.IsNullOrWhiteSpace(g.ReleaseDate) ? "—" : g.ReleaseDate!;
        Genres = g.Genres.Select(x => new TextChipVM(x)).ToList();
        ControllerLabel = g.ControllerSupport switch
        {
            "full" => "Full Controller Support",
            "partial" => "Partial Controller Support",
            _ => "Keyboard & mouse",
        };
        ControllerVisibility = Vis.Of(g.ControllerSupport is "full" or "partial");
    }

    public LibraryGame Game { get; }
    public uint AppId { get; }
    public string Name { get; }
    public string Hero { get; }
    public string Logo { get; }
    public Visibility LogoVisibility { get; }
    public Visibility TitleFallbackVisibility { get; }
    public string Header { get; }
    public Visibility PlayVisibility { get; }
    public Visibility InstallVisibility { get; }
    public string SizeLabel { get; }
    public Visibility UpdateVisibility { get; }
    public string FavoriteGlyph { get; }
    public Brush FavoriteBrush { get; }
    public string LastPlayedLabel { get; }
    public string PlaytimeLabel { get; }
    public string TwoWeeksLabel { get; }
    public Visibility TwoWeeksVisibility { get; }
    public bool HasAchievements { get; }
    public Visibility AchievementsVisibility { get; }
    public Visibility NoAchievementsVisibility { get; }
    public string AchievementsLabel { get; }
    public double AchievementsPercent { get; }
    public string AchievementsSummary { get; }
    public IReadOnlyList<AchievementVM> Achievements { get; }
    public IReadOnlyList<FriendVM> Friends { get; }
    public string FriendsTitle { get; }
    public Visibility FriendsVisibility { get; }
    public Visibility NoFriendsVisibility { get; }
    public IReadOnlyList<ScreenshotVM> Screenshots { get; }
    public Visibility ScreenshotsVisibility { get; }
    public string Description { get; }
    public string Developer { get; }
    public string ReleaseDate { get; }
    public IReadOnlyList<TextChipVM> Genres { get; }
    public string ControllerLabel { get; }
    public Visibility ControllerVisibility { get; }
}
