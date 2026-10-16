using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;
using VirtualKey = Windows.System.VirtualKey;

namespace NativeSteam.Pages;

/// <summary>STORE tab (DESIGN.md §4.1).</summary>
public sealed partial class StorePage : Page, IFocusTarget, ISearchTarget, IGamepadAware
{
    private static readonly TimeSpan HeroInterval = TimeSpan.FromSeconds(6);

    private readonly DispatcherQueueTimer _heroTimer;
    private readonly List<(string Name, uint AppId, string Haystack)> _searchIndex;
    private bool _heroHovered;
    private bool _heroFocused;
    private bool? _compact;

    public StorePage()
    {
        Store store = DataStore.Snapshot.Store;
        Featured = store.Featured.Select(i => new StoreItemVM(i)).ToList();
        Specials = store.Specials.Select(i => new StoreItemVM(i)).ToList();
        TopSellers = store.TopSellers.Select(i => new StoreItemVM(i)).ToList();
        NewReleases = store.NewReleases.Select(i => new StoreItemVM(i)).ToList();
        ComingSoon = store.ComingSoon.Select(i => new StoreItemVM(i)).ToList();
        MostPlayed = store.MostPlayed.Select(i => new ChartEntryVM(i)).ToList();
        Tags = store.PopularTags.Select(t => new TagVM(t)).ToList();

        _searchIndex = store.Featured.Concat(store.Specials).Concat(store.TopSellers).Concat(store.NewReleases).Concat(store.ComingSoon)
            .Select(i => (i.Name, i.AppId, Haystack: (i.Name + " " + string.Join(" ", i.Genres)).ToLowerInvariant()))
            .Concat(DataStore.Snapshot.Library.Games.Select(g => (g.Name, g.AppId, Haystack: (g.Name + " " + string.Join(" ", g.Genres)).ToLowerInvariant())))
            .GroupBy(x => x.AppId)
            .Select(g => g.First())
            .ToList();

        InitializeComponent();

        _heroTimer = DispatcherQueue.CreateTimer();
        _heroTimer.Interval = HeroInterval;
        _heroTimer.IsRepeating = true;
        _heroTimer.Tick += OnHeroTimerTick;

        Loaded += (_, _) => _heroTimer.Start();
        Unloaded += (_, _) => _heroTimer.Stop();
        SizeChanged += OnSizeChanged;
    }

    public IReadOnlyList<StoreItemVM> Featured { get; }
    public int FeaturedCount => Featured.Count;
    public IReadOnlyList<StoreItemVM> Specials { get; }
    public IReadOnlyList<StoreItemVM> TopSellers { get; }
    public IReadOnlyList<StoreItemVM> NewReleases { get; }
    public IReadOnlyList<StoreItemVM> ComingSoon { get; }
    public IReadOnlyList<ChartEntryVM> MostPlayed { get; }
    public IReadOnlyList<TagVM> Tags { get; }

    public UIElement? DefaultFocusElement => HeroFlip;

    public bool FocusSearch() => SearchBox.Focus(FocusState.Keyboard);

    // ===================================================================== Responsive layout

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        double width = e.NewSize.Width;
        bool compact = width < 700;
        if (compact != _compact)
        {
            _compact = compact;
            ContentColumn.Padding = compact ? new Thickness(16, 12, 16, 32) : new Thickness(32, 20, 32, 40);
            ContentColumn.Spacing = compact ? 24 : 32;
            HeroFlip.ItemTemplate = (DataTemplate)Resources[compact ? "HeroCompactTemplate" : "HeroWideTemplate"];

            // Compact: search on its own row, tags underneath.
            SearchColumn.Width = compact ? new GridLength(1, GridUnitType.Star) : new GridLength(340);
            Grid.SetRow(TagsShelf, compact ? 1 : 0);
            Grid.SetColumn(TagsShelf, compact ? 0 : 1);
            Grid.SetColumnSpan(TagsShelf, compact ? 2 : 1);
            Grid.SetColumnSpan(SearchBox, compact ? 2 : 1);
            SearchRow.RowSpacing = compact ? 12 : 0;

            TopSellersLayout.MaximumRowsOrColumns = compact ? 1 : 2;
            TopSellersLayout.MinItemWidth = compact ? 260 : 420;
            MostPlayedLayout.MaximumRowsOrColumns = compact ? 1 : 2;
            MostPlayedLayout.MinItemWidth = compact ? 260 : 420;
        }

        double inner = Math.Min(width, 1600) - (compact ? 32 : 64);
        HeroFlip.Height = compact ? Math.Max(180, inner * 353.0 / 616.0) : Math.Clamp(inner * 0.30, 320, 440);
    }

    // ===================================================================== Hero carousel

    private void OnHeroTimerTick(DispatcherQueueTimer sender, object args)
    {
        if (_heroHovered || _heroFocused || Featured.Count < 2) return;
        HeroFlip.SelectedIndex = (HeroFlip.SelectedIndex + 1) % Featured.Count;
    }

    private void StepHero(int delta)
    {
        if (Featured.Count == 0) return;
        int index = HeroFlip.SelectedIndex < 0 ? 0 : HeroFlip.SelectedIndex;
        HeroFlip.SelectedIndex = (index + delta + Featured.Count) % Featured.Count;
    }

    private void OpenSelectedHero()
    {
        if (HeroFlip.SelectedItem is StoreItemVM vm) Nav.OpenStoreApp(vm.AppId);
    }

    private void OnHeroTapped(object sender, TappedRoutedEventArgs e)
    {
        // Ignore taps on the FlipView's own previous/next buttons.
        for (DependencyObject? cur = e.OriginalSource as DependencyObject; cur is not null && cur != HeroFlip; cur = VisualTreeHelper.GetParent(cur))
        {
            if (cur is ButtonBase) return;
        }
        OpenSelectedHero();
    }

    private void OnHeroKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key is VirtualKey.Enter or VirtualKey.Space)
        {
            OpenSelectedHero();
            e.Handled = true;
        }
    }

    private void OnHeroPointerEntered(object sender, PointerRoutedEventArgs e) => _heroHovered = true;

    private void OnHeroPointerExited(object sender, PointerRoutedEventArgs e) => _heroHovered = false;

    private void OnHeroGotFocus(object sender, RoutedEventArgs e) => _heroFocused = true;

    private void OnHeroLostFocus(object sender, RoutedEventArgs e) => _heroFocused = false;

    public bool HandlePad(PadAction action, DependencyObject? focused)
    {
        if (focused != HeroFlip) return false;
        switch (action)
        {
            case PadAction.Left:
                StepHero(-1);
                return true;
            case PadAction.Right:
                StepHero(1);
                return true;
            case PadAction.Accept:
                OpenSelectedHero();
                return true;
            default:
                return false;
        }
    }

    // ===================================================================== Items

    private void OnStoreItemClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: StoreItemVM vm }) Nav.OpenStoreApp(vm.AppId);
    }

    private void OnChartClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: ChartEntryVM vm }) Nav.OpenApp(vm.AppId);
    }

    private void OnTagClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TagVM tag })
        {
            SearchBox.Text = tag.Name;
            UpdateSuggestions(tag.Name);
            SearchBox.IsSuggestionListOpen = true;
        }
    }

    // ===================================================================== Search

    private void OnSearchTextChanged(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason == AutoSuggestionBoxTextChangeReason.UserInput) UpdateSuggestions(sender.Text);
    }

    private void UpdateSuggestions(string? query)
    {
        string q = (query ?? "").Trim().ToLowerInvariant();
        if (q.Length == 0)
        {
            SearchBox.ItemsSource = null;
            return;
        }
        List<string> matches = _searchIndex
            .Where(x => x.Haystack.Contains(q, StringComparison.Ordinal))
            .OrderBy(x => x.Name.StartsWith(q, StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(x => x.Name, StringComparer.OrdinalIgnoreCase)
            .Take(10)
            .Select(x => x.Name)
            .ToList();
        SearchBox.ItemsSource = matches.Count > 0 ? matches : new List<string> { "No results" };
    }

    private void OnSearchSuggestionChosen(AutoSuggestBox sender, AutoSuggestBoxSuggestionChosenEventArgs args)
    {
        if (args.SelectedItem is string name && name != "No results") sender.Text = name;
    }

    private void OnSearchQuerySubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        string? name = args.ChosenSuggestion as string ?? args.QueryText;
        if (string.IsNullOrWhiteSpace(name)) return;
        string q = name.Trim().ToLowerInvariant();
        var hit = _searchIndex.FirstOrDefault(x => x.Name.Equals(name, StringComparison.OrdinalIgnoreCase));
        if (hit.Name is null) hit = _searchIndex.FirstOrDefault(x => x.Haystack.Contains(q, StringComparison.Ordinal));
        if (hit.Name is not null) Nav.OpenApp(hit.AppId);
    }
}
