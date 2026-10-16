using System;
using System.Collections.Generic;
using System.Globalization;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace NativeSteam.Services;

/// <summary>
/// Brand tokens from docs/DESIGN.md §1 for code-behind and view models.
/// Themes/Steam.xaml defines the same values as XAML resources.
/// All members must be touched on the UI thread (brushes are DependencyObjects).
/// </summary>
public static class Palette
{
    public static readonly Color Chrome = Hex("#171a21");
    public static readonly Color Surface = Hex("#16202d");
    public static readonly Color SurfaceNeutral = Hex("#23262e");
    public static readonly Color SurfaceHover = Hex("#2a475e");
    public static readonly Color TextTitle = Hex("#ffffff");
    public static readonly Color TextBody = Hex("#c7d5e0");
    public static readonly Color TextSecondary = Hex("#8f98a0");
    public static readonly Color TextMuted = Hex("#67707b");
    public static readonly Color Accent = Hex("#1a9fff");
    public static readonly Color AccentLink = Hex("#66c0f4");
    public static readonly Color DiscountText = Hex("#beee11");
    public static readonly Color ReviewPositive = Hex("#66c0f4");
    public static readonly Color ReviewMixed = Hex("#b9a074");
    public static readonly Color ReviewNegative = Hex("#a34c25");
    public static readonly Color StatusInGame = Hex("#90ba3c");
    public static readonly Color StatusOnline = Hex("#57cbde");
    public static readonly Color StatusAway = Color.FromArgb(0x80, 0x57, 0xcb, 0xde);
    public static readonly Color StatusOffline = Hex("#898989");

    private static readonly Dictionary<uint, SolidColorBrush> Cache = new();

    public static SolidColorBrush Brush(Color c)
    {
        uint key = ((uint)c.A << 24) | ((uint)c.R << 16) | ((uint)c.G << 8) | c.B;
        if (!Cache.TryGetValue(key, out SolidColorBrush? brush))
        {
            brush = new SolidColorBrush(c);
            Cache[key] = brush;
        }
        return brush;
    }

    public static SolidColorBrush Brush(string hex) => Brush(Hex(hex));

    public static SolidColorBrush ReviewBrush(string? tone) => tone switch
    {
        "positive" => Brush(ReviewPositive),
        "mixed" => Brush(ReviewMixed),
        "negative" => Brush(ReviewNegative),
        _ => Brush(TextSecondary),
    };

    public static SolidColorBrush StatusBrush(string? status) => status switch
    {
        "inGame" => Brush(StatusInGame),
        "online" => Brush(StatusOnline),
        "away" => Brush(StatusAway),
        _ => Brush(StatusOffline),
    };

    /// <summary>Parses #rgb, #rrggbb or #aarrggbb. Falls back to textSecondary.</summary>
    public static Color Hex(string? hex)
    {
        if (string.IsNullOrWhiteSpace(hex)) return Color.FromArgb(0xff, 0x8f, 0x98, 0xa0);
        string s = hex.Trim().TrimStart('#');
        if (s.Length == 3) s = new string(new[] { s[0], s[0], s[1], s[1], s[2], s[2] });
        if (s.Length == 6) s = "ff" + s;
        if (s.Length != 8 || !uint.TryParse(s, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out uint v))
        {
            return Color.FromArgb(0xff, 0x8f, 0x98, 0xa0);
        }
        return Color.FromArgb((byte)(v >> 24), (byte)(v >> 16), (byte)(v >> 8), (byte)v);
    }

    public static Color WithAlpha(Color c, double alpha) =>
        Color.FromArgb((byte)Math.Clamp(Math.Round(alpha * 255), 0, 255), c.R, c.G, c.B);
}
