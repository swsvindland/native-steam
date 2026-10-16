using System;
using System.Globalization;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;

namespace NativeSteam.ViewModels;

public sealed class StatVM
{
    public StatVM(string value, string caption)
    {
        Value = value;
        Caption = caption.ToUpperInvariant();
    }

    public StatVM(uint value, string caption) : this(value.ToString("N0", CultureInfo.InvariantCulture), caption)
    {
    }

    public string Value { get; }
    public string Caption { get; }
}

public sealed class BadgeVM
{
    public BadgeVM(Badge b)
    {
        Name = b.Name;
        Description = b.Description;
        Fill = Palette.Brush(b.Color);
        Glyph = Glyphs.ForBadge(b.Icon);
        Level = b.Level.ToString(CultureInfo.InvariantCulture);
        Xp = b.Xp.ToString(CultureInfo.InvariantCulture) + " XP";
    }

    public string Name { get; }
    public string Description { get; }
    public SolidColorBrush Fill { get; }
    public string Glyph { get; }
    public string Level { get; }
    public string Xp { get; }
}

public sealed class RecentGameVM
{
    public RecentGameVM(RecentGame g)
    {
        AppId = g.AppId;
        Name = g.Name;
        Header = g.Images.Header;
        TotalLabel = g.TotalLabel;
        TwoWeeksLabel = g.TwoWeeksLabel;
        LastPlayedLabel = g.LastPlayedLabel;
        AchievementProgress? a = g.Achievements;
        AchievementVisibility = Vis.Of(a is not null && a.Total > 0);
        AchievementLabel = a is null
            ? ""
            : $"Achievement progress  {a.Unlocked.ToString(CultureInfo.InvariantCulture)} of {a.Total.ToString(CultureInfo.InvariantCulture)}";
        AchievementPercent = a is null ? 0 : Math.Clamp(a.Fraction * 100.0, 0, 100);
    }

    public uint AppId { get; }
    public string Name { get; }
    public string Header { get; }
    public string TotalLabel { get; }
    public string TwoWeeksLabel { get; }
    public string LastPlayedLabel { get; }
    public Visibility AchievementVisibility { get; }
    public string AchievementLabel { get; }
    public double AchievementPercent { get; }
}

public sealed class ShowcaseAchievementVM
{
    public ShowcaseAchievementVM(ShowcaseAchievement s)
    {
        AppId = s.AppId;
        AppName = s.AppName;
        Name = s.Achievement.Name;
        Icon = s.Achievement.IconUrl;
        Detail = s.Achievement.UnlockedLabel ?? "";
    }

    public uint AppId { get; }
    public string AppName { get; }
    public string Name { get; }
    public string Icon { get; }
    public string Detail { get; }
}

public sealed class ShowcaseScreenshotVM
{
    public ShowcaseScreenshotVM(ShowcaseScreenshot s)
    {
        AppId = s.AppId;
        AppName = s.AppName;
        Url = s.Url;
    }

    public uint AppId { get; }
    public string AppName { get; }
    public string Url { get; }
}
