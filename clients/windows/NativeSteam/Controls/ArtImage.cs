using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using NativeSteam.Services;
using Windows.Foundation;

namespace NativeSteam.Controls;

/// <summary>
/// Steam CDN artwork: aspect-fill + clip to rounded corners, with a <c>surface</c>-coloured
/// placeholder (optionally showing the game name) while loading or on failure.
/// BitmapImage keeps its own memory/disk cache for http(s) URIs.
/// </summary>
public sealed class ArtImage : UserControl
{
    private readonly Grid _root;
    private readonly Border _placeholder;
    private readonly TextBlock _label;
    private readonly Border _image;
    private readonly ImageBrush _brush;

    public ArtImage()
    {
        IsTabStop = false;
        HorizontalContentAlignment = HorizontalAlignment.Stretch;
        VerticalContentAlignment = VerticalAlignment.Stretch;

        _label = new TextBlock
        {
            Margin = new Thickness(10),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextAlignment = TextAlignment.Center,
            TextWrapping = TextWrapping.WrapWholeWords,
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxLines = 3,
            FontSize = 13,
            Foreground = Palette.Brush(Palette.TextMuted),
        };
        _placeholder = new Border { Background = Palette.Brush(Palette.Surface), Child = _label };

        _brush = new ImageBrush { Stretch = Stretch.UniformToFill, AlignmentX = AlignmentX.Center, AlignmentY = AlignmentY.Center };
        _brush.ImageOpened += (_, _) => _label.Visibility = Visibility.Collapsed;
        _brush.ImageFailed += (_, _) => _label.Visibility = Visibility.Visible;
        _image = new Border { Background = _brush };

        _root = new Grid();
        _root.Children.Add(_placeholder);
        _root.Children.Add(_image);
        Content = _root;

        RegisterPropertyChangedCallback(CornerRadiusProperty, (_, _) => ApplyCornerRadius());
    }

    // ---- Url -------------------------------------------------------------------------------

    public static readonly DependencyProperty UrlProperty = DependencyProperty.Register(
        nameof(Url), typeof(string), typeof(ArtImage), new PropertyMetadata(null, OnSourceChanged));

    /// <summary>Absolute http(s) URL. Null/empty shows the placeholder only.</summary>
    public string? Url
    {
        get => (string?)GetValue(UrlProperty);
        set => SetValue(UrlProperty, value);
    }

    // ---- PlaceholderText -------------------------------------------------------------------

    public static readonly DependencyProperty PlaceholderTextProperty = DependencyProperty.Register(
        nameof(PlaceholderText), typeof(string), typeof(ArtImage), new PropertyMetadata(null, OnPlaceholderTextChanged));

    public string? PlaceholderText
    {
        get => (string?)GetValue(PlaceholderTextProperty);
        set => SetValue(PlaceholderTextProperty, value);
    }

    // ---- ShowPlaceholder -------------------------------------------------------------------

    public static readonly DependencyProperty ShowPlaceholderProperty = DependencyProperty.Register(
        nameof(ShowPlaceholder), typeof(bool), typeof(ArtImage), new PropertyMetadata(true, OnShowPlaceholderChanged));

    /// <summary>False for transparent artwork (logos) that must not get a backing plate.</summary>
    public bool ShowPlaceholder
    {
        get => (bool)GetValue(ShowPlaceholderProperty);
        set => SetValue(ShowPlaceholderProperty, value);
    }

    // ---- Stretch / alignment ---------------------------------------------------------------

    public static readonly DependencyProperty StretchProperty = DependencyProperty.Register(
        nameof(Stretch), typeof(Stretch), typeof(ArtImage), new PropertyMetadata(Stretch.UniformToFill, OnBrushLayoutChanged));

    public Stretch Stretch
    {
        get => (Stretch)GetValue(StretchProperty);
        set => SetValue(StretchProperty, value);
    }

    public static readonly DependencyProperty ImageAlignmentXProperty = DependencyProperty.Register(
        nameof(ImageAlignmentX), typeof(AlignmentX), typeof(ArtImage), new PropertyMetadata(AlignmentX.Center, OnBrushLayoutChanged));

    public AlignmentX ImageAlignmentX
    {
        get => (AlignmentX)GetValue(ImageAlignmentXProperty);
        set => SetValue(ImageAlignmentXProperty, value);
    }

    public static readonly DependencyProperty ImageAlignmentYProperty = DependencyProperty.Register(
        nameof(ImageAlignmentY), typeof(AlignmentY), typeof(ArtImage), new PropertyMetadata(AlignmentY.Center, OnBrushLayoutChanged));

    public AlignmentY ImageAlignmentY
    {
        get => (AlignmentY)GetValue(ImageAlignmentYProperty);
        set => SetValue(ImageAlignmentYProperty, value);
    }

    // ---- DecodeWidth -----------------------------------------------------------------------

    public static readonly DependencyProperty DecodeWidthProperty = DependencyProperty.Register(
        nameof(DecodeWidth), typeof(int), typeof(ArtImage), new PropertyMetadata(0, OnSourceChanged));

    /// <summary>Decode to this logical width (0 = natural size). Keeps memory low for big CDN art.</summary>
    public int DecodeWidth
    {
        get => (int)GetValue(DecodeWidthProperty);
        set => SetValue(DecodeWidthProperty, value);
    }

    // ---- AspectRatio -----------------------------------------------------------------------

    public static readonly DependencyProperty AspectRatioProperty = DependencyProperty.Register(
        nameof(AspectRatio), typeof(double), typeof(ArtImage), new PropertyMetadata(0.0, OnAspectChanged));

    /// <summary>Width / height. When &gt; 0 the control sizes its height from the available width.</summary>
    public double AspectRatio
    {
        get => (double)GetValue(AspectRatioProperty);
        set => SetValue(AspectRatioProperty, value);
    }

    // ---- Implementation --------------------------------------------------------------------

    private static void OnSourceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((ArtImage)d).LoadImage();

    private static void OnPlaceholderTextChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (ArtImage)d;
        self._label.Text = e.NewValue as string ?? "";
    }

    private static void OnShowPlaceholderChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (ArtImage)d;
        self._placeholder.Visibility = (bool)e.NewValue ? Visibility.Visible : Visibility.Collapsed;
    }

    private static void OnBrushLayoutChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (ArtImage)d;
        self._brush.Stretch = self.Stretch;
        self._brush.AlignmentX = self.ImageAlignmentX;
        self._brush.AlignmentY = self.ImageAlignmentY;
    }

    private static void OnAspectChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((ArtImage)d).InvalidateMeasure();

    private void ApplyCornerRadius()
    {
        _placeholder.CornerRadius = CornerRadius;
        _image.CornerRadius = CornerRadius;
    }

    private void LoadImage()
    {
        string? url = Url;
        if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out Uri? uri))
        {
            _brush.ImageSource = null;
            _label.Visibility = Visibility.Visible;
            return;
        }

        var bitmap = new BitmapImage();
        int decode = DecodeWidth;
        if (decode > 0)
        {
            bitmap.DecodePixelType = DecodePixelType.Logical;
            bitmap.DecodePixelWidth = decode;
        }
        bitmap.UriSource = uri;
        _brush.ImageSource = bitmap;
    }

    protected override Size MeasureOverride(Size availableSize)
    {
        double ratio = AspectRatio;
        if (ratio > 0 && !double.IsInfinity(availableSize.Width) && availableSize.Width > 0)
        {
            double width = availableSize.Width;
            double height = width / ratio;
            if (!double.IsInfinity(availableSize.Height) && height > availableSize.Height) height = availableSize.Height;
            _root.Measure(new Size(width, height));
            return new Size(width, height);
        }
        return base.MeasureOverride(availableSize);
    }
}
