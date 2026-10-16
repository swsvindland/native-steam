using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NativeSteam.Services;

namespace NativeSteam.Controls;

/// <summary>
/// Steam section header: UPPERCASE, semibold, ~0.06em tracking, textTitle @ 90%,
/// with an optional trailing "See all ›" style label.
/// </summary>
public sealed class SectionHeader : UserControl
{
    private readonly TextBlock _title;
    private readonly TextBlock _trailing;

    public SectionHeader()
    {
        IsTabStop = false;
        _title = new TextBlock
        {
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            CharacterSpacing = 60,
            Foreground = Palette.Brush("#e6ffffff"),
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        _trailing = new TextBlock
        {
            FontSize = 13,
            Foreground = Palette.Brush(Palette.AccentLink),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right,
            Visibility = Visibility.Collapsed,
        };
        var grid = new Grid { MinHeight = 28 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.Children.Add(_title);
        Grid.SetColumn(_trailing, 1);
        grid.Children.Add(_trailing);
        Content = grid;
    }

    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(
        nameof(Title), typeof(string), typeof(SectionHeader), new PropertyMetadata("", OnTitleChanged));

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public static readonly DependencyProperty TrailingProperty = DependencyProperty.Register(
        nameof(Trailing), typeof(string), typeof(SectionHeader), new PropertyMetadata(null, OnTrailingChanged));

    /// <summary>e.g. "See all ›". Hidden when null or empty.</summary>
    public string? Trailing
    {
        get => (string?)GetValue(TrailingProperty);
        set => SetValue(TrailingProperty, value);
    }

    private static void OnTitleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (SectionHeader)d;
        self._title.Text = (e.NewValue as string ?? "").ToUpperInvariant();
    }

    private static void OnTrailingChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (SectionHeader)d;
        string? text = e.NewValue as string;
        self._trailing.Text = text ?? "";
        self._trailing.Visibility = string.IsNullOrEmpty(text) ? Visibility.Collapsed : Visibility.Visible;
    }
}
