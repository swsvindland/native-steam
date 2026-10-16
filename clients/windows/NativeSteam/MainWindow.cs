using System;
using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Services;
using Windows.Graphics;

namespace NativeSteam;

/// <summary>
/// The single top-level window: Mica Alt backdrop, content extended into a tall (48 epx) title bar,
/// Steam-dark caption buttons, and an initial size/position (overridable with <c>--size WxH</c>).
/// </summary>
public sealed class MainWindow : Window
{
    private const int DefaultWidth = 1440;
    private const int DefaultHeight = 900;

    public MainWindow(LaunchOptions options, string? loadError)
    {
        Title = "Native Steam";
        Shell = new ShellPage();
        Content = Shell;

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(Shell.TitleBarElement);
        ConfigureTitleBar();
        ConfigureBackdrop();
        SizeAndCenter(options);

        Shell.Attach(this, options);
        if (loadError is not null)
        {
            Shell.ShowFatalError("Could not load Assets\\snapshot.json.\n\n" + loadError);
        }
    }

    public ShellPage Shell { get; }

    private void ConfigureTitleBar()
    {
        try
        {
            AppWindowTitleBar titleBar = AppWindow.TitleBar;
            titleBar.PreferredHeightOption = TitleBarHeightOption.Tall;
            titleBar.ButtonBackgroundColor = Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
            titleBar.ButtonForegroundColor = Colors.White;
            titleBar.ButtonInactiveForegroundColor = Palette.TextMuted;
            titleBar.ButtonHoverBackgroundColor = Palette.SurfaceHover;
            titleBar.ButtonHoverForegroundColor = Colors.White;
            titleBar.ButtonPressedBackgroundColor = Palette.Surface;
            titleBar.ButtonPressedForegroundColor = Colors.White;
        }
        catch (Exception ex)
        {
            App.Log("Title bar customization failed: " + ex.Message);
        }
    }

    private void ConfigureBackdrop()
    {
        try
        {
            if (MicaController.IsSupported())
            {
                // Mica Alt shows through the translucent title bar row (Windows 11).
                SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };
            }
            else
            {
                // Windows 10: no Mica; paint the chrome solid.
                Shell.Background = Palette.Brush(Palette.Chrome);
            }
        }
        catch (Exception ex)
        {
            App.Log("Backdrop failed: " + ex.Message);
            Shell.Background = Palette.Brush(Palette.Chrome);
        }
    }

    private void SizeAndCenter(LaunchOptions options)
    {
        try
        {
            double scale = GetScale();
            int width = (int)Math.Round((options.Width ?? DefaultWidth) * scale);
            int height = (int)Math.Round((options.Height ?? DefaultHeight) * scale);

            DisplayArea display = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary);
            RectInt32 work = display.WorkArea;
            if (options.Width is null)
            {
                // Default size: never larger than the work area.
                width = Math.Min(width, work.Width);
                height = Math.Min(height, work.Height);
            }

            AppWindow.ResizeClient(new SizeInt32(width, height));
            SizeInt32 outer = AppWindow.Size;
            int x = work.X + Math.Max(0, (work.Width - outer.Width) / 2);
            int y = work.Y + Math.Max(0, (work.Height - outer.Height) / 2);
            AppWindow.Move(new PointInt32(x, y));
        }
        catch (Exception ex)
        {
            App.Log("Sizing failed: " + ex.Message);
        }
    }

    private double GetScale()
    {
        try
        {
            IntPtr hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            uint dpi = GetDpiForWindow(hwnd);
            return dpi > 0 ? dpi / 96.0 : 1.0;
        }
        catch
        {
            return 1.0;
        }
    }

    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);
}
