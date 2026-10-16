using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;

namespace NativeSteam.ViewModels;

public sealed class StoreItemVM
{
    public StoreItemVM(StoreItem item)
    {
        Item = item;
        AppId = item.AppId;
        Name = item.Name;
        Header = item.Images.Header;
        Capsule = string.IsNullOrEmpty(item.Images.Capsule) ? item.Images.Header : item.Images.Capsule;
        SmallCapsule = string.IsNullOrEmpty(item.Images.SmallCapsule) ? item.Images.Header : item.Images.SmallCapsule;
        Backdrop = item.Images.Background ?? item.Images.Hero ?? Capsule;
        Price = item.Price;
        ReleaseText = string.IsNullOrWhiteSpace(item.ReleaseDate) ? "Coming soon" : item.ReleaseDate!;
        PriceFallback = item.ComingSoon || item.Price is null ? ReleaseText : "";

        if (!string.IsNullOrEmpty(item.DiscountEndsLabel)) Subline = item.DiscountEndsLabel!;
        else if (item.ComingSoon) Subline = "Releases " + ReleaseText;
        else if (item.Genres.Count > 0) Subline = string.Join(" · ", item.Genres.Take(3));
        else Subline = ReleaseText;

        ReviewLabel = item.Review?.Label ?? (item.ComingSoon ? "Coming soon" : "No user reviews");
        ReviewBrush = Palette.ReviewBrush(item.Review?.Tone);
        ReviewDetail = item.Review is null
            ? ""
            : $"{item.Review.PercentPositive.ToString(CultureInfo.InvariantCulture)}% of {item.Review.TotalLabel} are positive";
        ReviewTotal = item.Review is null ? "" : $"({item.Review.TotalLabel})";
        ReviewVisibility = Vis.Of(item.Review is not null);

        Genres = item.Genres.Take(4).Select(g => new TextChipVM(g)).ToList();
        GenresText = item.Genres.Count > 0 ? string.Join(", ", item.Genres) : "—";
        DevelopersText = item.Developers.Count > 0 ? string.Join(", ", item.Developers) : "—";
        ShortDescription = item.ShortDescription ?? "";

        Screenshots = item.Screenshots
            .Select((s, i) => new ScreenshotVM(s.Thumbnail, s.Full, item.Name, i))
            .ToList();
        string Thumb(int i) => i < item.Screenshots.Count ? item.Screenshots[i].Thumbnail : Header;
        Thumb1 = Thumb(0);
        Thumb2 = Thumb(1);
        Thumb3 = Thumb(2);
        Thumb4 = Thumb(3);

        WindowsVisibility = Vis.Of(item.Platforms.Windows);
        MacVisibility = Vis.Of(item.Platforms.Mac);
        LinuxVisibility = Vis.Of(item.Platforms.Linux);
        ControllerVisibility = Vis.Of(item.ControllerSupport is "full" or "partial");
        ControllerLabel = item.ControllerSupport == "partial" ? "Partial Controller Support" : "Full Controller Support";

        var platforms = new List<string>();
        if (item.Platforms.Windows) platforms.Add("Windows");
        if (item.Platforms.Mac) platforms.Add("macOS");
        if (item.Platforms.Linux) platforms.Add("SteamOS + Linux");
        PlatformsText = platforms.Count > 0 ? string.Join(" · ", platforms) : "Windows";
    }

    public StoreItem Item { get; }
    public uint AppId { get; }
    public string Name { get; }
    public string Header { get; }
    public string Capsule { get; }
    public string SmallCapsule { get; }
    public string Backdrop { get; }
    public Price? Price { get; }
    public string PriceFallback { get; }
    public string ReleaseText { get; }
    public string Subline { get; }
    public string ReviewLabel { get; }
    public SolidColorBrush ReviewBrush { get; }
    public string ReviewDetail { get; }
    public string ReviewTotal { get; }
    public Visibility ReviewVisibility { get; }
    public IReadOnlyList<TextChipVM> Genres { get; }
    public string GenresText { get; }
    public string DevelopersText { get; }
    public string ShortDescription { get; }
    public IReadOnlyList<ScreenshotVM> Screenshots { get; }
    public string Thumb1 { get; }
    public string Thumb2 { get; }
    public string Thumb3 { get; }
    public string Thumb4 { get; }
    public Visibility WindowsVisibility { get; }
    public Visibility MacVisibility { get; }
    public Visibility LinuxVisibility { get; }
    public Visibility ControllerVisibility { get; }
    public string ControllerLabel { get; }
    public string PlatformsText { get; }
}

public sealed class ChartEntryVM
{
    public ChartEntryVM(ChartEntry e)
    {
        AppId = e.AppId;
        Rank = "#" + e.Rank.ToString(CultureInfo.InvariantCulture);
        Name = e.Name;
        Header = e.Images.Header;
        PlayersLabel = e.CurrentPlayersLabel;
        PeakLabel = e.PeakTodayLabel;
        Price = e.Price;
    }

    public uint AppId { get; }
    public string Rank { get; }
    public string Name { get; }
    public string Header { get; }
    public string PlayersLabel { get; }
    public string PeakLabel { get; }
    public Price? Price { get; }
}

public sealed class TagVM
{
    public TagVM(Tag t)
    {
        Id = t.Id;
        Name = t.Name;
    }

    public uint Id { get; }
    public string Name { get; }
}
