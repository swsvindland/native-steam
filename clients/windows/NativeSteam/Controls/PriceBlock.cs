using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NativeSteam.Models;
using NativeSteam.Services;
using Windows.UI.Text;

namespace NativeSteam.Controls;

/// <summary>
/// DESIGN.md "Price block": discount badge + struck-through original over the final price,
/// just the final price when not discounted, or a fallback ("Coming soon" / release date)
/// when the item has no price.
/// </summary>
public sealed class PriceBlock : UserControl
{
    private readonly StackPanel _root;
    private readonly Border _badge;
    private readonly TextBlock _badgeText;
    private readonly Border _priceBox;
    private readonly TextBlock _initial;
    private readonly TextBlock _final;

    public PriceBlock()
    {
        IsTabStop = false;
        HorizontalAlignment = HorizontalAlignment.Left;
        VerticalAlignment = VerticalAlignment.Center;

        _badgeText = new TextBlock
        {
            FontWeight = FontWeights.Bold,
            Foreground = Palette.Brush("#beee11"),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _badge = new Border
        {
            Background = Palette.Brush("#4c6b22"),
            Padding = new Thickness(6, 0, 6, 0),
            CornerRadius = new CornerRadius(2, 0, 0, 2),
            Child = _badgeText,
        };

        _initial = new TextBlock
        {
            Foreground = Palette.Brush("#738895"),
            TextDecorations = TextDecorations.Strikethrough,
            HorizontalAlignment = HorizontalAlignment.Right,
        };
        _final = new TextBlock
        {
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
        };
        var stack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        stack.Children.Add(_initial);
        stack.Children.Add(_final);
        _priceBox = new Border
        {
            Background = Palette.Brush("#40000000"),
            Padding = new Thickness(8, 2, 8, 2),
            CornerRadius = new CornerRadius(2),
            Child = stack,
        };

        _root = new StackPanel { Orientation = Orientation.Horizontal };
        _root.Children.Add(_badge);
        _root.Children.Add(_priceBox);
        Content = _root;
        Update();
    }

    public static readonly DependencyProperty PriceProperty = DependencyProperty.Register(
        nameof(Price), typeof(object), typeof(PriceBlock), new PropertyMetadata(null, OnChanged));

    /// <summary>A <see cref="Models.Price"/> or null.</summary>
    public object? Price
    {
        get => GetValue(PriceProperty);
        set => SetValue(PriceProperty, value);
    }

    public static readonly DependencyProperty FallbackTextProperty = DependencyProperty.Register(
        nameof(FallbackText), typeof(string), typeof(PriceBlock), new PropertyMetadata("Coming soon", OnChanged));

    public string? FallbackText
    {
        get => (string?)GetValue(FallbackTextProperty);
        set => SetValue(FallbackTextProperty, value);
    }

    public static readonly DependencyProperty IsLargeProperty = DependencyProperty.Register(
        nameof(IsLarge), typeof(bool), typeof(PriceBlock), new PropertyMetadata(false, OnChanged));

    /// <summary>Bigger type for the store app page purchase box.</summary>
    public bool IsLarge
    {
        get => (bool)GetValue(IsLargeProperty);
        set => SetValue(IsLargeProperty, value);
    }

    private static void OnChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((PriceBlock)d).Update();

    private void Update()
    {
        bool large = IsLarge;
        double finalSize = large ? 17 : 13;
        double minHeight = large ? 40 : 30;
        _badgeText.FontSize = large ? 22 : 15;
        _initial.FontSize = large ? 12 : 11;
        _final.FontSize = finalSize;
        _badge.MinHeight = minHeight;
        _priceBox.MinHeight = minHeight;

        if (Price is Models.Price p)
        {
            bool discounted = !string.IsNullOrEmpty(p.DiscountLabel);
            _badge.Visibility = discounted ? Visibility.Visible : Visibility.Collapsed;
            _badgeText.Text = p.DiscountLabel ?? "";
            _initial.Visibility = discounted ? Visibility.Visible : Visibility.Collapsed;
            _initial.Text = p.InitialLabel;
            _final.Text = p.FinalLabel;
            _final.Foreground = Palette.Brush(discounted ? Palette.DiscountText : Palette.TextBody);
            _priceBox.CornerRadius = discounted ? new CornerRadius(0, 2, 2, 0) : new CornerRadius(2);
            _priceBox.Background = Palette.Brush("#40000000");
        }
        else
        {
            _badge.Visibility = Visibility.Collapsed;
            _initial.Visibility = Visibility.Collapsed;
            _final.Text = string.IsNullOrEmpty(FallbackText) ? "Coming soon" : FallbackText;
            _final.Foreground = Palette.Brush(Palette.TextSecondary);
            _priceBox.CornerRadius = new CornerRadius(2);
            _priceBox.Background = Palette.Brush("#26000000");
        }
    }
}
