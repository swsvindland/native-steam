using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;

namespace NativeSteam.ViewModels;

/// <summary>Minimal INotifyPropertyChanged base (no toolkit dependency).</summary>
public abstract class Observable : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        return true;
    }

    protected void Raise(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

internal static class Vis
{
    public static Visibility Of(bool visible) => visible ? Visibility.Visible : Visibility.Collapsed;
    public static Visibility Of(string? text) => string.IsNullOrWhiteSpace(text) ? Visibility.Collapsed : Visibility.Visible;
}

public sealed class TextChipVM
{
    public TextChipVM(string text) => Text = text;
    public string Text { get; }
}

public sealed class ScreenshotVM
{
    public ScreenshotVM(string thumbnail, string full, string caption, int index)
    {
        Thumbnail = thumbnail;
        Full = full;
        Caption = caption;
        Index = index;
    }

    public string Thumbnail { get; }
    public string Full { get; }
    public string Caption { get; }
    public int Index { get; }
}

public sealed class AchievementVM
{
    public AchievementVM(Achievement a)
    {
        Name = a.Name;
        Icon = a.IconUrl;
        Unlocked = a.Unlocked;
        Detail = a.Unlocked ? (a.UnlockedLabel ?? "Unlocked") : "Locked";
        IconOpacity = a.Unlocked ? 1.0 : 0.32;
        LockVisibility = Vis.Of(!a.Unlocked);
    }

    public string Name { get; }
    public string Icon { get; }
    public bool Unlocked { get; }
    public string Detail { get; }
    public double IconOpacity { get; }
    public Visibility LockVisibility { get; }
}

public sealed class FriendVM
{
    public FriendVM(Friend f)
    {
        SteamId = f.SteamId;
        Name = f.PersonaName;
        Avatar = f.AvatarUrl;
        StatusLabel = f.StatusLabel;
        Status = f.Status;
        StatusBrush = Palette.StatusBrush(f.Status);
        NameBrush = f.Status switch
        {
            "inGame" => Palette.Brush(Palette.StatusInGame),
            "online" or "away" => Palette.Brush(Palette.StatusOnline),
            _ => Palette.Brush(Palette.StatusOffline),
        };
        LevelLabel = f.Level.ToString(System.Globalization.CultureInfo.InvariantCulture);
        LevelBrush = Palette.Brush(f.LevelColor);
        GameAppId = f.Game?.AppId ?? 0;
        AvatarOpacity = f.Status == "offline" ? 0.55 : 1.0;
    }

    public string SteamId { get; }
    public string Name { get; }
    public string Avatar { get; }
    public string Status { get; }
    public string StatusLabel { get; }
    public SolidColorBrush StatusBrush { get; }
    public SolidColorBrush NameBrush { get; }
    public string LevelLabel { get; }
    public SolidColorBrush LevelBrush { get; }
    public uint GameAppId { get; }
    public double AvatarOpacity { get; }
}

public sealed class FriendGroupVM
{
    public FriendGroupVM(string title, IReadOnlyList<FriendVM> friends)
    {
        Title = $"{title.ToUpperInvariant()} ({friends.Count.ToString(System.Globalization.CultureInfo.InvariantCulture)})";
        Friends = friends;
        Visibility = Vis.Of(friends.Count > 0);
    }

    public string Title { get; }
    public IReadOnlyList<FriendVM> Friends { get; }
    public Visibility Visibility { get; }

    /// <summary>Groups friends In-Game / Online (incl. Away) / Offline as in DESIGN.md §4.3.</summary>
    public static IReadOnlyList<FriendGroupVM> Build(IEnumerable<Friend> friends)
    {
        List<FriendVM> all = friends.Select(f => new FriendVM(f)).ToList();
        return new List<FriendGroupVM>
        {
            new("In-Game", all.Where(f => f.Status == "inGame").ToList()),
            new("Online", all.Where(f => f.Status is "online" or "away").ToList()),
            new("Offline", all.Where(f => f.Status is not ("inGame" or "online" or "away")).ToList()),
        };
    }
}

internal static class Glyphs
{
    public const string Store = "";
    public const string Library = "";
    public const string People = "";
    public const string Search = "";
    public const string Back = "";
    public const string ChevronLeft = "";
    public const string ChevronRight = "";
    public const string Download = "";
    public const string StarFilled = "";
    public const string Star = "";
    public const string Settings = "";
    public const string Info = "";
    public const string Play = "";
    public const string Like = "";
    public const string Dislike = "";
    public const string Comment = "";
    public const string Gamepad = "";
    public const string Lock = "";
    public const string Calendar = "";
    public const string Tag = "";
    public const string Camera = "";
    public const string Heart = "";
    public const string Cart = "";

    public static string ForBadge(string icon) => icon switch
    {
        "years" => Calendar,
        "sale" => Tag,
        "collector" => Library,
        "community" => People,
        "awards" => Star,
        "deck" => Gamepad,
        "trophy" => StarFilled,
        _ => StarFilled,
    };
}
