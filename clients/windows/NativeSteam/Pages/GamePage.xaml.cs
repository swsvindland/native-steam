using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;

namespace NativeSteam.Pages;

/// <summary>Library game page (DESIGN.md §4.2.4). Navigation parameter: the app id (uint).</summary>
public sealed partial class GamePage : Page, IFocusTarget, IGamepadAware, IHintsProvider
{
    private bool _favorite;
    private bool _busy;
    private bool? _compact;

    public GamePage()
    {
        Game = new GameDetailVM(new LibraryGame { Name = "" });
        InitializeComponent();
        SizeChanged += OnSizeChanged;
    }

    public GameDetailVM Game { get; private set; }

    public UIElement? DefaultFocusElement => Game.Game.Installed ? PlayButton : InstallButton;

    public string? SecondaryHint => "Favorite";

    public string? SectionHint => null;

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is uint appId && DataStore.LibraryGame(appId) is LibraryGame game)
        {
            Game = new GameDetailVM(game);
            _favorite = game.Favorite;
        }
        Bindings.Update();
    }

    private void OnPlayClick(object sender, RoutedEventArgs e)
    {
        // Visual only: flip to a "running" state.
        _busy = !_busy;
        PlayLabel.Text = _busy ? "RUNNING" : "PLAY";
    }

    private void OnInstallClick(object sender, RoutedEventArgs e)
    {
        _busy = !_busy;
        InstallLabel.Text = _busy ? "QUEUED" : "INSTALL";
    }

    private void OnFavoriteClick(object sender, RoutedEventArgs e) => ToggleFavorite();

    private void OnInfoClick(object sender, RoutedEventArgs e) => AboutSection.StartBringIntoView(new BringIntoViewOptions { AnimationDesired = true, VerticalAlignmentRatio = 0.1 });

    private void ToggleFavorite()
    {
        _favorite = !_favorite;
        FavoriteIcon.Glyph = _favorite ? "" : "";
        FavoriteIcon.Foreground = _favorite ? Palette.Brush("#ffc82c") : Palette.Brush(Palette.TextBody);
    }

    public bool HandlePad(PadAction action, DependencyObject? focused)
    {
        if (action == PadAction.Secondary)
        {
            ToggleFavorite(); // X = favorite (DESIGN.md §3)
            return true;
        }
        return false;
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        double width = e.NewSize.Width;
        HeroArea.Height = width < 700 ? 260 : width < 1100 ? 340 : 400;

        bool compact = width < 1000;
        if (compact == _compact) return;
        _compact = compact;

        double gutter = width < 700 ? 16 : 40;
        ActionBar.Padding = new Thickness(gutter, 14, gutter, 14);
        SectionsGrid.Padding = new Thickness(gutter, 24, gutter, 40);
        LogoImage.Margin = new Thickness(gutter, 0, gutter, 36);

        // Stats move under the buttons; the side column (friends) moves under the main sections.
        Grid.SetRow(StatsPanel, compact ? 1 : 0);
        Grid.SetColumn(StatsPanel, 0);
        Grid.SetColumnSpan(StatsPanel, compact ? 3 : 1);
        if (!compact) Grid.SetColumn(StatsPanel, 1);

        ActionBar.RowSpacing = compact ? 14 : 0;
        SideColumn.Width = compact ? new GridLength(0) : new GridLength(340);
        SectionsGrid.ColumnSpacing = compact ? 0 : 40;
        Grid.SetColumn(SideSections, compact ? 0 : 1);
        Grid.SetRow(SideSections, compact ? 1 : 0);
    }
}
