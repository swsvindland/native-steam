using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;

namespace NativeSteam.Pages;

/// <summary>LIBRARY tab (DESIGN.md §4.2).</summary>
public sealed partial class LibraryPage : Page, IFocusTarget, ISearchTarget, IGamepadAware, IHintsProvider
{
    private readonly List<LibraryGameVM> _allGames;
    private CollectionVM _selected;
    private LibrarySort _sort = LibrarySort.Alphabetical;
    private string _filter = "";
    private bool? _sidebar;
    private bool? _compact;
    private bool _syncingLists;

    public LibraryPage()
    {
        Library library = DataStore.Snapshot.Library;
        Collections = library.Collections.Select(c => new CollectionVM(c)).ToList();
        if (Collections.Count == 0)
        {
            Collections = new List<CollectionVM>
            {
                new(new Collection { Id = "all", Name = "All Games", Kind = "dynamic", AppIds = library.Games.Select(g => g.AppId).ToList() }),
            };
        }
        _selected = Collections[0];
        _selected.IsSelected = true;
        DynamicCollections = Collections.Where(c => c.Collection.Kind != "user").ToList();
        UserCollections = Collections.Where(c => c.Collection.Kind == "user").ToList();

        _allGames = library.Games.Select(g => new LibraryGameVM(g)).ToList();
        Recent = BuildRecent(compact: false);
        int installed = library.Games.Count(g => g.Installed);
        InstalledSummary = $"{installed.ToString(CultureInfo.InvariantCulture)} installed · {library.Games.Count.ToString(CultureInfo.InvariantCulture)} games";

        InitializeComponent();

        Loaded += OnLoaded;
        SizeChanged += OnSizeChanged;
        UpdateSortButtons();
        ApplyFilter();
    }

    public IReadOnlyList<CollectionVM> Collections { get; }
    public IReadOnlyList<CollectionVM> DynamicCollections { get; }
    public IReadOnlyList<CollectionVM> UserCollections { get; }
    public IReadOnlyList<LibraryGameVM> Recent { get; private set; }
    public string InstalledSummary { get; }

    public UIElement? DefaultFocusElement =>
        FirstFocusableIn(RecentShelf.ContainerFromIndex(0))
        ?? (GamesRepeater.TryGetElement(0) as UIElement);

    public bool FocusSearch() => Sidebar.Visibility == Visibility.Visible && FilterBox.Focus(FocusState.Keyboard);

    public string? SecondaryHint => "Favorite";

    public string? SectionHint => "Collection";

    private void OnLoaded(object sender, RoutedEventArgs e) => SyncListSelection();

    /// <summary>Reflects the selected collection in whichever sidebar list holds it.</summary>
    private void SyncListSelection()
    {
        _syncingLists = true;
        try
        {
            bool dynamic = DynamicCollections.Contains(_selected);
            DynamicList.SelectedItem = dynamic ? _selected : null;
            UserList.SelectedItem = dynamic ? null : _selected;
        }
        finally
        {
            _syncingLists = false;
        }
    }

    private static UIElement? FirstFocusableIn(DependencyObject? container) =>
        container is null ? null : FocusManager.FindFirstFocusableElement(container) as UIElement;

    // ===================================================================== Data shaping

    private List<LibraryGameVM> BuildRecent(bool compact)
    {
        const double baseWidth = 300;
        var recent = new List<LibraryGameVM>();
        foreach (uint id in DataStore.Snapshot.Library.RecentAppIds)
        {
            // Share the view model with the grid so a favourite toggle shows in both places.
            LibraryGameVM? vm = _allGames.FirstOrDefault(g => g.AppId == id);
            if (vm is null) continue;
            vm.CardWidth = !compact && recent.Count == 0 ? baseWidth * 2 + 16 : (compact ? 260 : baseWidth);
            recent.Add(vm);
        }
        return recent;
    }

    private void ApplyFilter()
    {
        IEnumerable<LibraryGameVM> games = _allGames.Where(g => _selected.AppIds.Contains(g.AppId));
        if (!string.IsNullOrWhiteSpace(_filter))
        {
            string f = _filter.Trim();
            games = games.Where(g => g.Name.Contains(f, StringComparison.OrdinalIgnoreCase));
        }

        games = _sort switch
        {
            LibrarySort.RecentlyPlayed => games.OrderByDescending(g => ParseDate(g.Game.LastPlayed)).ThenBy(g => g.Name, StringComparer.OrdinalIgnoreCase),
            LibrarySort.HoursPlayed => games.OrderByDescending(g => g.Game.PlaytimeMinutes).ThenBy(g => g.Name, StringComparer.OrdinalIgnoreCase),
            _ => games.OrderBy(g => g.Name, StringComparer.OrdinalIgnoreCase),
        };

        List<LibraryGameVM> list = games.ToList();
        GamesRepeater.ItemsSource = list;
        AllGamesHeader.Title = $"{_selected.Name} ({list.Count.ToString(CultureInfo.InvariantCulture)})";
        EmptyText.Visibility = list.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private static DateTimeOffset ParseDate(string? value) =>
        DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out DateTimeOffset d) ? d : DateTimeOffset.MinValue;

    private void SelectCollection(CollectionVM collection)
    {
        if (collection == _selected) return;
        _selected.IsSelected = false;
        _selected = collection;
        _selected.IsSelected = true;
        SyncListSelection();
        ApplyFilter();
    }

    // ===================================================================== Events

    private void OnCollectionSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncingLists) return;
        if (sender is ListView { SelectedItem: CollectionVM c }) SelectCollection(c);
    }

    private void OnCollectionChipClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: CollectionVM c }) SelectCollection(c);
    }

    private void OnFilterTextChanged(object sender, TextChangedEventArgs e)
    {
        _filter = FilterBox.Text ?? "";
        ApplyFilter();
    }

    private void OnSortClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string tag } && int.TryParse(tag, out int index))
        {
            _sort = index switch
            {
                1 => LibrarySort.RecentlyPlayed,
                2 => LibrarySort.HoursPlayed,
                _ => LibrarySort.Alphabetical,
            };
            UpdateSortButtons();
            ApplyFilter();
        }
    }

    private void UpdateSortButtons()
    {
        Button[] buttons = { SortAlphaButton, SortRecentButton, SortHoursButton };
        for (int i = 0; i < buttons.Length; i++)
        {
            bool selected = i == (int)_sort;
            buttons[i].Background = selected ? Palette.Brush(Palette.SurfaceHover) : Palette.Brush(Windows.UI.Color.FromArgb(0, 0, 0, 0));
            buttons[i].Foreground = selected ? Palette.Brush(Palette.TextTitle) : Palette.Brush(Palette.TextSecondary);
        }
    }

    private void OnGameClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: LibraryGameVM vm }) Nav.OpenGame(vm.AppId);
    }

    public bool HandlePad(PadAction action, DependencyObject? focused)
    {
        int index = Collections.ToList().IndexOf(_selected);
        switch (action)
        {
            case PadAction.Secondary:
                // X toggles the favourite star on the focused game (visual only).
                if (focused is FrameworkElement { DataContext: LibraryGameVM game })
                {
                    game.IsFavorite = !game.IsFavorite;
                    return true;
                }
                return false;
            case PadAction.PreviousSection:
                SelectCollection(Collections[(index - 1 + Collections.Count) % Collections.Count]);
                return true;
            case PadAction.NextSection:
                SelectCollection(Collections[(index + 1) % Collections.Count]);
                return true;
            default:
                return false;
        }
    }

    // ===================================================================== Responsive layout

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        double width = e.NewSize.Width;
        bool sidebar = width >= 1000;
        bool compact = width < 700;

        if (sidebar != _sidebar)
        {
            _sidebar = sidebar;
            Sidebar.Visibility = sidebar ? Visibility.Visible : Visibility.Collapsed;
            SidebarColumn.Width = sidebar ? new GridLength(272) : new GridLength(0);
            CollectionChips.Visibility = sidebar ? Visibility.Collapsed : Visibility.Visible;
        }

        if (compact != _compact)
        {
            _compact = compact;
            ContentColumn.Padding = compact ? new Thickness(16, 12, 16, 32) : new Thickness(32, 20, 32, 40);
            ContentColumn.Spacing = compact ? 22 : 28;
            Recent = BuildRecent(compact);
            RecentShelf.ItemsSource = Recent;
            GamesLayout.MinColumnSpacing = compact ? 10 : 16;
            GamesLayout.MinRowSpacing = compact ? 12 : 18;
        }

        if (compact)
        {
            // Exactly three portrait columns on phones / narrow windows.
            double available = width - 32 - 2 * 10;
            double item = Math.Max(80, Math.Floor(available / 3));
            GamesLayout.MinItemWidth = item;
            GamesLayout.MinItemHeight = Math.Round(item * 1.5);
        }
        else
        {
            GamesLayout.MinItemWidth = 168;
            GamesLayout.MinItemHeight = 252;
        }
    }
}
