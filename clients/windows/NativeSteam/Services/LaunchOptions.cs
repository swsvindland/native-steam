using System;
using System.Collections.Generic;
using System.Globalization;

namespace NativeSteam.Services;

public enum AppTab
{
    Store = 0,
    Library = 1,
    Community = 2,
    Profile = 3,
}

/// <summary>
/// Command-line switches, mainly for deterministic screenshots in CI:
/// <c>--tab store|library|community|profile</c>, <c>--game &lt;appId&gt;</c>, <c>--app &lt;appId&gt;</c>,
/// <c>--input gamepad</c>, <c>--size 1440x900</c>.
/// </summary>
public sealed class LaunchOptions
{
    public AppTab Tab { get; private set; } = AppTab.Store;
    public bool TabSpecified { get; private set; }
    public uint? GameAppId { get; private set; }
    public uint? StoreAppId { get; private set; }
    public bool ForceGamepad { get; private set; }
    public int? Width { get; private set; }
    public int? Height { get; private set; }

    public static LaunchOptions Current { get; private set; } = new();

    public static LaunchOptions Parse(IReadOnlyList<string> args)
    {
        var o = new LaunchOptions();
        for (int i = 0; i < args.Count; i++)
        {
            string arg = args[i];
            string? value = null;
            int eq = arg.IndexOf('=');
            if (arg.StartsWith("--", StringComparison.Ordinal) && eq > 0)
            {
                value = arg[(eq + 1)..];
                arg = arg[..eq];
            }
            else if (i + 1 < args.Count && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
            {
                value = args[i + 1];
            }

            bool consumed = true;
            switch (arg.ToLowerInvariant())
            {
                case "--tab":
                    if (TryParseTab(value, out AppTab tab)) { o.Tab = tab; o.TabSpecified = true; }
                    break;
                case "--game":
                    if (uint.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out uint game)) o.GameAppId = game;
                    break;
                case "--app":
                    if (uint.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out uint app)) o.StoreAppId = app;
                    break;
                case "--input":
                    o.ForceGamepad = string.Equals(value, "gamepad", StringComparison.OrdinalIgnoreCase);
                    break;
                case "--size":
                    if (value is not null)
                    {
                        string[] parts = value.ToLowerInvariant().Split('x');
                        if (parts.Length == 2
                            && int.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out int w)
                            && int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int h)
                            && w >= 320 && h >= 320)
                        {
                            o.Width = w;
                            o.Height = h;
                        }
                    }
                    break;
                default:
                    consumed = false;
                    break;
            }

            // Skip the separate value token ("--tab library") but not "--tab=library".
            if (consumed && eq <= 0 && value is not null) i++;
        }

        // A game page lives in the Library tab, a store page in the Store tab, unless told otherwise.
        if (!o.TabSpecified && o.GameAppId is not null) o.Tab = AppTab.Library;
        Current = o;
        return o;
    }

    private static bool TryParseTab(string? value, out AppTab tab)
    {
        switch (value?.ToLowerInvariant())
        {
            case "store": tab = AppTab.Store; return true;
            case "library": tab = AppTab.Library; return true;
            case "community": tab = AppTab.Community; return true;
            case "profile":
            case "user":
            case "kestrel": tab = AppTab.Profile; return true;
            default: tab = AppTab.Store; return false;
        }
    }
}
