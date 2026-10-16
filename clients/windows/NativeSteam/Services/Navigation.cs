using Microsoft.UI.Xaml;

namespace NativeSteam.Services;

/// <summary>Logical gamepad actions after edge detection / stick-to-dpad mapping.</summary>
public enum PadAction
{
    Up,
    Down,
    Left,
    Right,
    Accept,
    Back,
    Search,
    Secondary,
    Menu,
    PreviousTab,
    NextTab,
    PreviousSection,
    NextSection,
}

/// <summary>Implemented by the shell; pages navigate through <see cref="Nav"/>.</summary>
public interface IShell
{
    void SelectTab(AppTab tab, bool focusContent);
    void OpenStoreApp(uint appId);
    void OpenGame(uint appId);
    bool GoBack();
    void FocusSearch();
}

/// <summary>Pages that know which element should receive focus first (keyboard / gamepad).</summary>
public interface IFocusTarget
{
    UIElement? DefaultFocusElement { get; }
}

/// <summary>Pages with a search / filter field (Y button, Ctrl+F).</summary>
public interface ISearchTarget
{
    bool FocusSearch();
}

/// <summary>Pages that add context-specific entries to the gamepad hints bar.</summary>
public interface IHintsProvider
{
    /// <summary>Label for the X button (e.g. "Favorite", "Wishlist"), or null to hide it.</summary>
    string? SecondaryHint { get; }

    /// <summary>Label for LT/RT (e.g. "Collection"), or null to hide it.</summary>
    string? SectionHint { get; }
}

/// <summary>Pages that want first dibs on a gamepad action (e.g. carousel paging, LT/RT).</summary>
public interface IGamepadAware
{
    bool HandlePad(PadAction action, DependencyObject? focused);
}

public static class Nav
{
    public static IShell? Shell { get; set; }

    public static void OpenStoreApp(uint appId) => Shell?.OpenStoreApp(appId);

    public static void OpenGame(uint appId) => Shell?.OpenGame(appId);

    /// <summary>Opens the library game page if owned, otherwise the store page (if we know the app).</summary>
    public static void OpenApp(uint appId)
    {
        if (Shell is null) return;
        if (DataStore.LibraryGame(appId) is not null) Shell.OpenGame(appId);
        else if (DataStore.StoreItemOrFallback(appId) is not null) Shell.OpenStoreApp(appId);
    }

    public static void SelectTab(AppTab tab) => Shell?.SelectTab(tab, false);

    public static bool GoBack() => Shell?.GoBack() ?? false;
}
