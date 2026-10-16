using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using NativeSteam.Models;
using NativeSteam.Services;
using NativeSteam.ViewModels;

namespace NativeSteam.Pages;

/// <summary>Store app page (DESIGN.md §4.1 "Store app page"). Navigation parameter: the app id (uint).</summary>
public sealed partial class AppPage : Page, IFocusTarget, IGamepadAware, IHintsProvider
{
    private bool _inCart;
    private bool _wishlisted;
    private bool? _compact;

    public AppPage()
    {
        Item = new StoreItemVM(new StoreItem { Name = "" });
        InitializeComponent();
        SizeChanged += OnSizeChanged;
    }

    public StoreItemVM Item { get; private set; }

    public UIElement? DefaultFocusElement => AddToCartButton;

    public string? SecondaryHint => "Wishlist";

    public string? SectionHint => null;

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is uint appId && DataStore.StoreItemOrFallback(appId) is StoreItem item)
        {
            Item = new StoreItemVM(item);
        }
        ShowScreenshot(0);
        Bindings.Update();
    }

    private void ShowScreenshot(int index)
    {
        if (Item.Screenshots.Count == 0)
        {
            MainShot.Url = Item.Capsule;
            ThumbStrip.Visibility = Visibility.Collapsed;
            return;
        }
        if (index < 0 || index >= Item.Screenshots.Count) index = 0;
        MainShot.Url = Item.Screenshots[index].Full;
        ThumbStrip.Visibility = Visibility.Visible;
    }

    private void OnThumbClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: ScreenshotVM shot }) ShowScreenshot(shot.Index);
    }

    private void OnAddToCartClick(object sender, RoutedEventArgs e)
    {
        // Purely visual: no purchase flow in this concept.
        _inCart = !_inCart;
        AddToCartLabel.Text = _inCart ? "In Cart" : "Add to Cart";
    }

    private void OnWishlistClick(object sender, RoutedEventArgs e)
    {
        _wishlisted = !_wishlisted;
        WishlistGlyph.Glyph = _wishlisted ? "" : "";
        WishlistLabel.Text = _wishlisted ? "On Wishlist" : "Wishlist";
    }

    public bool HandlePad(PadAction action, DependencyObject? focused)
    {
        if (action == PadAction.Secondary)
        {
            OnWishlistClick(WishlistButton, new RoutedEventArgs());
            return true;
        }
        return false;
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        bool compact = e.NewSize.Width < 900;
        if (compact == _compact) return;
        _compact = compact;

        ContentColumn.Padding = compact ? new Thickness(16, 12, 16, 32) : new Thickness(32, 20, 32, 48);
        SummaryColumn.Width = compact ? new GridLength(0) : new GridLength(340);
        MediaGrid.RowSpacing = compact ? 20 : 0;
        MediaGrid.ColumnSpacing = compact ? 0 : 24;
        Grid.SetColumn(SummaryPanel, compact ? 0 : 1);
        Grid.SetRow(SummaryPanel, compact ? 1 : 0);

        // Stack the purchase actions under the title on narrow windows.
        Grid.SetColumn(BuyActions, compact ? 0 : 1);
        Grid.SetRow(BuyActions, compact ? 1 : 0);
        if (PurchaseBox.RowDefinitions.Count == 0)
        {
            PurchaseBox.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            PurchaseBox.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        }
        PurchaseBox.RowSpacing = compact ? 12 : 0;
        BuyActions.HorizontalAlignment = compact ? HorizontalAlignment.Left : HorizontalAlignment.Right;
    }
}
