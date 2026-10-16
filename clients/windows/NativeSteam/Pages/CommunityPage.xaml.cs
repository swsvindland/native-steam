using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;

namespace NativeSteam.Pages;

/// <summary>COMMUNITY tab (DESIGN.md §4.3).</summary>
public sealed partial class CommunityPage : Page, IFocusTarget, IGamepadAware, IHintsProvider
{
    private enum LayoutMode
    {
        Wide,
        Medium,
        Narrow,
        Compact,
    }

    private LayoutMode? _mode;
    private int _section; // compact: 0 Activity, 1 News, 2 Hubs (+ friends)

    public CommunityPage()
    {
        Snapshot snapshot = DataStore.Snapshot;
        Activity = snapshot.Community.Activity.Select(a => new ActivityVM(a)).ToList();
        News = snapshot.Community.News.Select(n => new NewsVM(n)).ToList();
        Hubs = snapshot.Community.Hubs.OrderBy(h => h.Rank).Select(h => new HubVM(h)).ToList();
        FriendGroups = FriendGroupVM.Build(snapshot.Friends);
        int online = snapshot.Friends.Count(f => f.Status != "offline");
        FriendsOnline = $"{online.ToString(CultureInfo.InvariantCulture)} online";

        InitializeComponent();
        SizeChanged += (_, e) => ApplyLayout(e.NewSize.Width);
    }

    public IReadOnlyList<ActivityVM> Activity { get; }
    public IReadOnlyList<NewsVM> News { get; }
    public IReadOnlyList<HubVM> Hubs { get; }
    public IReadOnlyList<FriendGroupVM> FriendGroups { get; }
    public string FriendsOnline { get; }

    public UIElement? DefaultFocusElement => ActivityRepeater.TryGetElement(0);

    public string? SecondaryHint => null;

    public string? SectionHint => _mode == LayoutMode.Compact ? "Section" : null;

    // ===================================================================== Layout

    private void ApplyLayout(double width)
    {
        LayoutMode mode = width >= 1340 ? LayoutMode.Wide
            : width >= 1100 ? LayoutMode.Medium
            : width >= 700 ? LayoutMode.Narrow
            : LayoutMode.Compact;
        if (mode == _mode) return;
        _mode = mode;

        LayoutGrid.Padding = mode == LayoutMode.Compact ? new Thickness(16, 12, 16, 32) : new Thickness(32, 20, 32, 40);
        SectionSwitcher.Visibility = mode == LayoutMode.Compact ? Visibility.Visible : Visibility.Collapsed;
        Grid.SetRowSpan(RailSection, 1);

        switch (mode)
        {
            case LayoutMode.Wide:
                SetColumns(news: 380, rail: 320, spacing: 28);
                Place(ActivitySection, 1, 0);
                Place(NewsSection, 1, 1);
                Place(RailSection, 1, 2);
                break;
            case LayoutMode.Medium:
                SetColumns(news: 0, rail: 320, spacing: 14);
                Place(ActivitySection, 1, 0);
                Place(NewsSection, 2, 0);
                Place(RailSection, 1, 2);
                Grid.SetRowSpan(RailSection, 2);
                break;
            case LayoutMode.Narrow:
                SetColumns(news: 0, rail: 0, spacing: 0);
                Place(ActivitySection, 1, 0);
                Place(NewsSection, 2, 0);
                Place(RailSection, 3, 0);
                break;
            default:
                // Compact: one section at a time (segmented control), all in the same cell.
                SetColumns(news: 0, rail: 0, spacing: 0);
                Place(ActivitySection, 1, 0);
                Place(NewsSection, 1, 0);
                Place(RailSection, 1, 0);
                break;
        }
        ApplySectionVisibility();
    }

    private void SetColumns(double news, double rail, double spacing)
    {
        NewsColumn.Width = new GridLength(news);
        RailColumn.Width = new GridLength(rail);
        LayoutGrid.ColumnSpacing = spacing;
    }

    private static void Place(FrameworkElement element, int row, int column)
    {
        Grid.SetRow(element, row);
        Grid.SetColumn(element, column);
        // Sections stacked under another one get a gap (the grid itself has no RowSpacing so
        // collapsed rows don't leave holes).
        element.Margin = row > 1 ? new Thickness(0, 32, 0, 0) : new Thickness(0);
    }

    private void ApplySectionVisibility()
    {
        bool compact = _mode == LayoutMode.Compact;
        ActivitySection.Visibility = !compact || _section == 0 ? Visibility.Visible : Visibility.Collapsed;
        NewsSection.Visibility = !compact || _section == 1 ? Visibility.Visible : Visibility.Collapsed;
        RailSection.Visibility = !compact || _section == 2 ? Visibility.Visible : Visibility.Collapsed;

        Button[] tabs = { ActivityTabButton, NewsTabButton, HubsTabButton };
        for (int i = 0; i < tabs.Length; i++)
        {
            bool selected = i == _section;
            tabs[i].Background = selected ? Palette.Brush(Palette.Accent) : Palette.Brush("#1fffffff");
            tabs[i].Foreground = selected ? Palette.Brush(Palette.TextTitle) : Palette.Brush(Palette.TextBody);
        }
    }

    private void OnSectionTabClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string tag } && int.TryParse(tag, out int index))
        {
            _section = index;
            ApplySectionVisibility();
        }
    }

    public bool HandlePad(PadAction action, DependencyObject? focused)
    {
        if (_mode != LayoutMode.Compact) return false;
        if (action == PadAction.PreviousSection) _section = (_section + 2) % 3;
        else if (action == PadAction.NextSection) _section = (_section + 1) % 3;
        else return false;
        ApplySectionVisibility();
        return true;
    }

    // ===================================================================== Items

    private void OnActivityClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: ActivityVM vm }) Nav.OpenApp(vm.AppId);
    }

    private void OnNewsClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: NewsVM vm }) Nav.OpenApp(vm.AppId);
    }

    private void OnHubClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: HubVM vm }) Nav.OpenApp(vm.AppId);
    }

    private void OnFriendClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: FriendVM vm } && vm.GameAppId != 0) Nav.OpenApp(vm.GameAppId);
    }
}
