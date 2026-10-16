using System.Globalization;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;

namespace NativeSteam.ViewModels;

public sealed class ActivityVM
{
    public ActivityVM(ActivityItem a)
    {
        Item = a;
        AppId = a.AppId;
        FriendName = a.FriendName;
        FriendAvatar = a.FriendAvatarUrl;
        Headline = " " + a.Headline + " ";
        AppName = a.AppName;
        TimeLabel = a.TimeLabel;

        Friend? friend = DataStore.Friend(a.FriendId);
        string status = friend?.Status ?? "online";
        StatusBrush = Palette.StatusBrush(status);
        NameBrush = status == "inGame" ? Palette.Brush(Palette.StatusInGame) : Palette.Brush(Palette.StatusOnline);

        bool isAchievement = a.Kind == "achievement" && a.Achievement is not null;
        bool isScreenshot = a.Kind == "screenshot" && !string.IsNullOrEmpty(a.ImageUrl);
        bool isReview = a.Kind == "review" && a.Review is not null;
        bool isGame = !isAchievement && !isScreenshot && !isReview;

        AchievementVisibility = Vis.Of(isAchievement);
        AchievementIcon = a.Achievement?.IconUrl ?? "";
        AchievementName = a.Achievement?.Name ?? "";
        AchievementDetail = a.Achievement?.UnlockedLabel ?? "Unlocked";

        ScreenshotVisibility = Vis.Of(isScreenshot);
        ScreenshotUrl = a.ImageUrl ?? "";

        ReviewVisibility = Vis.Of(isReview);
        bool recommended = a.Review?.Recommended ?? true;
        ReviewGlyph = recommended ? Glyphs.Like : Glyphs.Dislike;
        ReviewVerdict = recommended ? "Recommended" : "Not Recommended";
        ReviewBrush = recommended ? Palette.Brush(Palette.AccentLink) : Palette.Brush("#c35c2c");
        ReviewPlateBrush = recommended ? Palette.Brush("#2a66c0f4") : Palette.Brush("#2aa34c25");
        ReviewHours = a.Review?.HoursLabel ?? "";
        ReviewBody = a.Review is null ? "" : "“" + a.Review.Body + "”";

        GameVisibility = Vis.Of(isGame);
        GameImage = a.Kind == "newGame" && !string.IsNullOrEmpty(a.ImageUrl) ? a.ImageUrl! : a.AppImages.Header;
        GameCaption = a.Kind == "newGame" ? "Added to library" : "Now playing";

        Likes = a.Likes.ToString(CultureInfo.InvariantCulture);
        Comments = a.Comments.ToString(CultureInfo.InvariantCulture);
    }

    public ActivityItem Item { get; }
    public uint AppId { get; }
    public string FriendName { get; }
    public string FriendAvatar { get; }
    public string Headline { get; }
    public string AppName { get; }
    public string TimeLabel { get; }
    public SolidColorBrush StatusBrush { get; }
    public SolidColorBrush NameBrush { get; }

    public Visibility AchievementVisibility { get; }
    public string AchievementIcon { get; }
    public string AchievementName { get; }
    public string AchievementDetail { get; }

    public Visibility ScreenshotVisibility { get; }
    public string ScreenshotUrl { get; }

    public Visibility ReviewVisibility { get; }
    public string ReviewGlyph { get; }
    public string ReviewVerdict { get; }
    public SolidColorBrush ReviewBrush { get; }
    public SolidColorBrush ReviewPlateBrush { get; }
    public string ReviewHours { get; }
    public string ReviewBody { get; }

    public Visibility GameVisibility { get; }
    public string GameImage { get; }
    public string GameCaption { get; }

    public string Likes { get; }
    public string Comments { get; }
}

public sealed class NewsVM
{
    public NewsVM(NewsItem n)
    {
        AppId = n.AppId;
        Title = n.Title;
        Image = string.IsNullOrEmpty(n.ImageUrl) ? n.AppImages.Header : n.ImageUrl!;
        Meta = $"{n.AppName} · {n.FeedLabel} · {n.DateLabel}";
        AppName = n.AppName;
        Excerpt = n.Excerpt;
    }

    public uint AppId { get; }
    public string Title { get; }
    public string Image { get; }
    public string Meta { get; }
    public string AppName { get; }
    public string Excerpt { get; }
}

public sealed class HubVM
{
    public HubVM(Hub h)
    {
        AppId = h.AppId;
        Rank = h.Rank.ToString(CultureInfo.InvariantCulture);
        Name = h.Name;
        Header = h.Images.Header;
        PlayersLabel = h.CurrentPlayersLabel;
    }

    public uint AppId { get; }
    public string Rank { get; }
    public string Name { get; }
    public string Header { get; }
    public string PlayersLabel { get; }
}
