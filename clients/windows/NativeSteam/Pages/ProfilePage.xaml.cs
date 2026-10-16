using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Controls;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;

namespace NativeSteam.Pages;

/// <summary>The persona tab — KESTREL (DESIGN.md §4.4).</summary>
public sealed partial class ProfilePage : Page, IFocusTarget
{
    private readonly List<ShowcaseScreenshotVM> _screenshots;
    private readonly uint _favoriteAppId;
    private bool? _compact;

    public ProfilePage()
    {
        Snapshot snapshot = DataStore.Snapshot;
        User = snapshot.User;
        LevelBrush = Palette.Brush(User.LevelColor);
        LevelText = User.Level.ToString(CultureInfo.InvariantCulture);
        XpPercent = Math.Clamp(User.XpFraction * 100.0, 0, 100);

        ProfileStats s = User.Stats;
        Stats = new List<StatVM>
        {
            new(s.GamesOwned, "Games"),
            new(s.Achievements, "Achievements"),
            new(s.PerfectGames, "Perfect games"),
            new(s.HoursLabel.Replace(" hrs", "", StringComparison.Ordinal), "Hours played"),
            new(s.Friends, "Friends"),
            new(s.Screenshots, "Screenshots"),
            new(s.Reviews, "Reviews"),
        };

        Badges = User.Badges.Select(b => new BadgeVM(b)).ToList();
        BadgesCount = s.Badges.ToString(CultureInfo.InvariantCulture);

        // Favorite game: library art (hero + logo) with hours and achievement progress.
        _favoriteAppId = User.FavoriteGame.AppId;
        LibraryGame? favorite = DataStore.LibraryGame(_favoriteAppId);
        FavoriteVisibility = User.FavoriteGame.AppId != 0 ? Visibility.Visible : Visibility.Collapsed;
        FavoriteName = favorite?.Name ?? User.FavoriteGame.Name;
        FavoriteHero = favorite?.Images.Hero ?? favorite?.Images.Capsule ?? "";
        FavoriteLogo = favorite?.Images.Logo ?? "";
        FavoriteHours = favorite?.PlaytimeLabel ?? "";
        AchievementProgress? fa = favorite?.Achievements;
        FavoriteAchievements = fa is null
            ? ""
            : $"{fa.Unlocked.ToString(CultureInfo.InvariantCulture)} of {fa.Total.ToString(CultureInfo.InvariantCulture)} achievements";
        FavoritePercent = fa is null ? 0 : Math.Clamp(fa.Fraction * 100.0, 0, 100);

        RecentGames = User.RecentGames.Select(g => new RecentGameVM(g)).ToList();
        double twoWeekHours = DataStore.Snapshot.Library.Games.Sum(g => g.PlaytimeTwoWeeksMinutes) / 60.0;
        RecentHoursLabel = $"{twoWeekHours.ToString("0.0", CultureInfo.InvariantCulture)} hours past 2 weeks";

        RareAchievements = User.RareAchievements.Select(a => new ShowcaseAchievementVM(a)).ToList();

        _screenshots = User.Screenshots.Select(x => new ShowcaseScreenshotVM(x)).ToList();
        ScreenshotsVisibility = _screenshots.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        ScreenshotsCount = $"{s.Screenshots.ToString("N0", CultureInfo.InvariantCulture)} screenshots";

        TopFriends = snapshot.Friends
            .OrderBy(f => f.Status switch { "inGame" => 0, "online" => 1, "away" => 2, _ => 3 })
            .Take(8)
            .Select(f => new FriendVM(f))
            .ToList();
        FriendsCount = s.Friends.ToString(CultureInfo.InvariantCulture);

        InitializeComponent();
        FillScreenshots();
        SizeChanged += OnSizeChanged;
    }

    public UserProfile User { get; }
    public SolidColorBrush LevelBrush { get; }
    public string LevelText { get; }
    public double XpPercent { get; }
    public IReadOnlyList<StatVM> Stats { get; }
    public IReadOnlyList<BadgeVM> Badges { get; }
    public string BadgesCount { get; }
    public Visibility FavoriteVisibility { get; }
    public string FavoriteName { get; }
    public string FavoriteHero { get; }
    public string FavoriteLogo { get; }
    public string FavoriteHours { get; }
    public string FavoriteAchievements { get; }
    public double FavoritePercent { get; }
    public IReadOnlyList<RecentGameVM> RecentGames { get; }
    public string RecentHoursLabel { get; }
    public IReadOnlyList<ShowcaseAchievementVM> RareAchievements { get; }
    public Visibility ScreenshotsVisibility { get; }
    public string ScreenshotsCount { get; }
    public IReadOnlyList<FriendVM> TopFriends { get; }
    public string FriendsCount { get; }

    public UIElement? DefaultFocusElement => FavoriteVisibility == Visibility.Visible ? FavoriteCard : EditProfileButton;

    private void FillScreenshots()
    {
        CardButton[] cards = { Shot0, Shot1, Shot2, Shot3 };
        ArtImage[] images = { Shot0Image, Shot1Image, Shot2Image, Shot3Image };
        for (int i = 0; i < cards.Length; i++)
        {
            if (i < _screenshots.Count)
            {
                images[i].Url = _screenshots[i].Url;
                images[i].PlaceholderText = _screenshots[i].AppName;
                cards[i].Tag = _screenshots[i].AppId.ToString(CultureInfo.InvariantCulture);
                ToolTipService.SetToolTip(cards[i], _screenshots[i].AppName);
                cards[i].Visibility = Visibility.Visible;
            }
            else
            {
                cards[i].Visibility = Visibility.Collapsed;
            }
        }
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        double width = e.NewSize.Width;
        bool compact = width < 1000;
        if (compact == _compact) return;
        _compact = compact;

        double gutter = width < 700 ? 16 : 40;
        BannerContent.Padding = new Thickness(gutter, 0, gutter, 24);
        BodyGrid.Padding = new Thickness(gutter, 8, gutter, 40);
        Banner.Height = compact ? 380 : 320;
        AvatarFrame.Width = AvatarFrame.Height = compact ? 104 : 140;

        // Level / XP block moves under the name on narrow windows.
        Grid.SetRow(LevelPanel, compact ? 1 : 0);
        Grid.SetColumn(LevelPanel, compact ? 0 : 2);
        Grid.SetColumnSpan(LevelPanel, compact ? 3 : 1);
        LevelPanel.HorizontalAlignment = compact ? HorizontalAlignment.Left : HorizontalAlignment.Stretch;
        BannerContent.RowSpacing = compact ? 16 : 0;

        // Single column: summary / badges / friends first, then the showcases.
        SideColumn.Width = compact ? new GridLength(0) : new GridLength(360);
        BodyGrid.ColumnSpacing = compact ? 0 : 40;
        Grid.SetColumn(SideColumnPanel, compact ? 0 : 1);
        Grid.SetRow(SideColumnPanel, 1);
        Grid.SetRow(MainColumn, compact ? 2 : 1);
        ScreenshotGrid.Height = width < 700 ? 240 : 390;
    }

    // ===================================================================== Events

    private void OnFavoriteClick(object sender, RoutedEventArgs e) => OpenOwned(_favoriteAppId);

    private void OnRecentGameClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: RecentGameVM vm }) OpenOwned(vm.AppId);
    }

    private void OnRareAchievementClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: ShowcaseAchievementVM vm }) Nav.OpenApp(vm.AppId);
    }

    private void OnShowcaseScreenshotClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string tag } && uint.TryParse(tag, NumberStyles.Integer, CultureInfo.InvariantCulture, out uint appId))
        {
            Nav.OpenApp(appId);
        }
    }

    private void OnFriendClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: FriendVM vm } && vm.GameAppId != 0) Nav.OpenApp(vm.GameAppId);
    }

    private void OnAllFriendsClick(object sender, RoutedEventArgs e) => Nav.SelectTab(AppTab.Community);

    private void OnEditProfileClick(object sender, RoutedEventArgs e)
    {
        // Visual only.
        EditProfileLabel.Text = EditProfileLabel.Text == "Edit Profile" ? "Editing…" : "Edit Profile";
    }

    private static void OpenOwned(uint appId)
    {
        if (appId == 0) return;
        Nav.OpenApp(appId);
    }
}
