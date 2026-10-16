using System;
using System.IO;
using System.Linq;
using Microsoft.UI.Xaml;
using NativeSteam.Services;

namespace NativeSteam;

public partial class App : Application
{
    private static readonly object LogLock = new();
    private MainWindow? _window;

    public App()
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log("AppDomain unhandled: " + e.ExceptionObject);
        try
        {
            InitializeComponent();
        }
        catch (Exception ex)
        {
            // Most likely a resource (App.xaml / Themes/Steam.xaml) failed to load; make it diagnosable.
            Log("App.InitializeComponent failed: " + ex);
            throw;
        }
        UnhandledException += OnUnhandledException;
    }

    public static MainWindow? MainWindow => (Current as App)?._window;

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        string[] commandLine = Environment.GetCommandLineArgs().Skip(1).ToArray();
        LaunchOptions options = LaunchOptions.Parse(commandLine);
        Log($"Launch: {string.Join(' ', commandLine)}");

        string? loadError = null;
        try
        {
            DataStore.Load();
            Log($"Loaded snapshot from {DataStore.LoadedFrom}");
        }
        catch (Exception ex)
        {
            loadError = ex.ToString();
            Log("Failed to load snapshot: " + ex);
        }

        _window = new MainWindow(options, loadError);
        _window.Activate();
    }

    private void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        Log("Unhandled: " + e.Exception);
        // Keep the concept app alive for non-fatal UI errors (e.g. an image decode failure).
        e.Handled = true;
    }

    /// <summary>Appends to nativesteam.log next to the executable (falls back to %TEMP%).</summary>
    public static void Log(string message)
    {
        string line = $"{DateTime.Now:HH:mm:ss.fff} {message}{Environment.NewLine}";
        lock (LogLock)
        {
            try
            {
                File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "nativesteam.log"), line);
            }
            catch
            {
                try
                {
                    File.AppendAllText(Path.Combine(Path.GetTempPath(), "nativesteam.log"), line);
                }
                catch
                {
                    // Logging must never crash the app.
                }
            }
        }
    }
}
