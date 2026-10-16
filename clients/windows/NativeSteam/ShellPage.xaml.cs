using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Automation.Provider;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Navigation;
using NativeSteam.Pages;
using NativeSteam.Services;
using Windows.Foundation;
using Windows.Graphics;
using Windows.System;

namespace NativeSteam;

/// <summary>
/// The adaptive shell: custom title bar with the STEAM wordmark and a NavigationView (Top) tab strip
/// on regular widths, a bottom tab bar on compact widths, one Frame per tab, the gamepad hints bar,
/// keyboard accelerators and the input-mode tracking described in DESIGN.md §2–3.
/// </summary>
public sealed partial class ShellPage : Page, IShell
{
    private static readonly Type[] RootPages = { typeof(StorePage), typeof(LibraryPage), typeof(CommunityPage), typeof(ProfilePage) };

    private readonly Frame[] _frames;
    private readonly NavigationViewItem[] _navItems;
    private readonly Button[] _bottomButtons;

    private MainWindow? _window;
    private LaunchOptions _options = new();
    private GamepadController? _gamepad;
    private AppTab _current = AppTab.Store;
    private bool _syncingSelection;
    private readonly Dictionary<Frame, Stack<WeakReference<UIElement>>> _focusMemory = new();
    private Point? _lastPointerPosition;
    private string _lastRegionKey = "";

    public ShellPage()
    {
        string persona = "Kestrel";
        string avatar = "";
        int online = 0;
        try
        {
            persona = DataStore.Snapshot.User.PersonaName;
            avatar = DataStore.Snapshot.User.AvatarUrl;
            online = DataStore.Snapshot.Friends.Count(f => f.Status != "offline");
        }
        catch (Exception ex)
        {
            App.Log("Snapshot unavailable for shell: " + ex);
        }
        PersonaName = persona;
        PersonaUpper = persona.ToUpperInvariant();
        AvatarUrl = avatar;
        FriendsOnlineLabel = online == 1 ? "1 online" : $"{online} online";

        InitializeComponent();

        _frames = new[] { StoreFrame, LibraryFrame, CommunityFrame, ProfileFrame };
        _navItems = new[] { StoreNavItem, LibraryNavItem, CommunityNavItem, ProfileNavItem };
        _bottomButtons = new[] { StoreTabButton, LibraryTabButton, CommunityTabButton, ProfileTabButton };

        foreach (Frame frame in _frames)
        {
            frame.Navigated += OnFrameNavigated;
            frame.NavigationFailed += OnNavigationFailed;
        }

        KeyboardAcceleratorPlacementMode = KeyboardAcceleratorPlacementMode.Hidden;
        AddAccelerator(VirtualKey.Number1, VirtualKeyModifiers.Control, () => SelectTab(AppTab.Store, true));
        AddAccelerator(VirtualKey.Number2, VirtualKeyModifiers.Control, () => SelectTab(AppTab.Library, true));
        AddAccelerator(VirtualKey.Number3, VirtualKeyModifiers.Control, () => SelectTab(AppTab.Community, true));
        AddAccelerator(VirtualKey.Number4, VirtualKeyModifiers.Control, () => SelectTab(AppTab.Profile, true));
        AddAccelerator(VirtualKey.F, VirtualKeyModifiers.Control, FocusSearch);
        AddAccelerator((VirtualKey)219, VirtualKeyModifiers.Control, () => GoBack()); // Ctrl+[
        AddAccelerator(VirtualKey.Left, VirtualKeyModifiers.Menu, () => GoBack());     // Alt+Left

        RootGrid.AddHandler(PreviewKeyDownEvent, new KeyEventHandler(OnRootPreviewKeyDown), true);
        RootGrid.AddHandler(KeyDownEvent, new KeyEventHandler(OnRootKeyDown), false);
        RootGrid.AddHandler(PointerPressedEvent, new PointerEventHandler(OnRootPointerPressed), true);
        RootGrid.AddHandler(PointerMovedEvent, new PointerEventHandler(OnRootPointerMoved), true);
        RootGrid.AddHandler(PointerWheelChangedEvent, new PointerEventHandler(OnRootPointerWheel), true);

        LayoutStates.CurrentStateChanged += (_, _) => UpdateTitleBarRegions();
        AppTitleBar.LayoutUpdated += (_, _) => UpdateTitleBarRegions();
        AppTitleBar.SizeChanged += (_, _) =>
        {
            _lastRegionKey = ""; // force re-registration after window resizes / DPI changes
            UpdateTitleBarRegions();
        };
        InputModeService.Changed += OnInputModeChanged;
        Loaded += OnLoaded;
        Unloaded += (_, _) =>
        {
            _gamepad?.Dispose();
            _gamepad = null;
        };
    }

    public string PersonaName { get; }
    public string PersonaUpper { get; }
    public string AvatarUrl { get; }
    public string FriendsOnlineLabel { get; }

    /// <summary>The element passed to Window.SetTitleBar (draggable caption area).</summary>
    public UIElement TitleBarElement => AppTitleBar;

    private Frame CurrentFrame => _frames[(int)_current];

    /// <summary>Called by MainWindow right after construction.</summary>
    public void Attach(MainWindow window, LaunchOptions options)
    {
        _window = window;
        _options = options;
        Nav.Shell = this;
        if (options.ForceGamepad)
        {
            InputModeService.Set(InputMode.Gamepad);
        }
        ApplyInputMode();
    }

    public void ShowFatalError(string message)
    {
        ErrorText.Text = message;
        ErrorPanel.Visibility = Visibility.Visible;
    }

    // ===================================================================== Startup

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (XamlRoot is not null)
        {
            XamlRoot.Changed += (_, _) => UpdateTitleBarRegions();
        }

        _gamepad ??= new GamepadController(DispatcherQueue, this);

        // Start-up route from the command line (used for CI screenshots).
        SelectTab(_options.Tab, false);
        try
        {
            if (_options.GameAppId is uint game && DataStore.LibraryGame(game) is not null)
            {
                Navigate(CurrentFrame, typeof(GamePage), game, new SuppressNavigationTransitionInfo());
            }
            else if (_options.StoreAppId is uint app && DataStore.StoreItemOrFallback(app) is not null)
            {
                Navigate(CurrentFrame, typeof(AppPage), app, new SuppressNavigationTransitionInfo());
            }
        }
        catch (Exception ex)
        {
            App.Log("Start-up navigation failed: " + ex);
        }

        UpdateTitleBarRegions();
        if (InputModeService.Current == InputMode.Gamepad)
        {
            // Give the page a moment to realize its items, then show the focus ring.
            FocusDefaultSoon(250);
        }
    }

    // ===================================================================== Tabs & navigation (IShell)

    public void SelectTab(AppTab tab, bool focusContent)
    {
        _current = tab;
        for (int i = 0; i < _frames.Length; i++)
        {
            _frames[i].Visibility = i == (int)tab ? Visibility.Visible : Visibility.Collapsed;
        }

        Frame frame = CurrentFrame;
        if (frame.Content is null)
        {
            Navigate(frame, RootPages[(int)tab], null, new SuppressNavigationTransitionInfo());
        }

        _syncingSelection = true;
        try
        {
            TopNav.SelectedItem = _navItems[(int)tab];
        }
        finally
        {
            _syncingSelection = false;
        }

        UpdateBottomTabs();
        UpdateBackButton();
        if (focusContent && InputModeService.IsFocusDriven)
        {
            FocusDefaultSoon(60);
        }
    }

    public void OpenStoreApp(uint appId) =>
        Navigate(CurrentFrame, typeof(AppPage), appId, new SlideNavigationTransitionInfo { Effect = SlideNavigationTransitionEffect.FromRight });

    public void OpenGame(uint appId) =>
        Navigate(CurrentFrame, typeof(GamePage), appId, new SlideNavigationTransitionInfo { Effect = SlideNavigationTransitionEffect.FromRight });

    public bool GoBack()
    {
        Frame frame = CurrentFrame;
        if (!frame.CanGoBack) return false;
        frame.GoBack(new SlideNavigationTransitionInfo { Effect = SlideNavigationTransitionEffect.FromLeft });
        return true;
    }

    public void FocusSearch()
    {
        if (CurrentFrame.Content is ISearchTarget target && target.FocusSearch()) return;

        // Search lives on the Store (and the Library filter); jump to the Store like Steam does.
        if (_current != AppTab.Store) SelectTab(AppTab.Store, false);
        else PopToRoot();
        DispatcherQueueTimerHelper.Run(DispatcherQueue, TimeSpan.FromMilliseconds(120), () =>
        {
            if (StoreFrame.Content is ISearchTarget store) store.FocusSearch();
        });
    }

    private void PopToRoot()
    {
        Frame frame = CurrentFrame;
        if (!frame.CanGoBack) return;
        while (frame.BackStack.Count > 1) frame.BackStack.RemoveAt(frame.BackStack.Count - 1);
        frame.GoBack(new SlideNavigationTransitionInfo { Effect = SlideNavigationTransitionEffect.FromLeft });
    }

    private void Navigate(Frame frame, Type pageType, object? parameter, NavigationTransitionInfo transition)
    {
        try
        {
            // Remember what had focus so Back can restore it (root pages are cached, so the element survives).
            if (frame.Content is not null && XamlRoot is not null && FocusManager.GetFocusedElement(XamlRoot) is UIElement focused)
            {
                if (!_focusMemory.TryGetValue(frame, out Stack<WeakReference<UIElement>>? stack))
                {
                    stack = new Stack<WeakReference<UIElement>>();
                    _focusMemory[frame] = stack;
                }
                stack.Push(new WeakReference<UIElement>(focused));
            }
            frame.Navigate(pageType, parameter, transition);
        }
        catch (Exception ex)
        {
            App.Log($"Navigation to {pageType.Name} failed: {ex}");
            ShowFatalError($"Could not open {pageType.Name}.\n\n{ex}");
        }
    }

    private void OnFrameNavigated(object sender, NavigationEventArgs e)
    {
        UpdateBackButton();
        if (sender is not Frame frame || !ReferenceEquals(frame, CurrentFrame) || !InputModeService.IsFocusDriven) return;

        UIElement? restore = null;
        if (e.NavigationMode == NavigationMode.Back && _focusMemory.TryGetValue(frame, out Stack<WeakReference<UIElement>>? stack))
        {
            // Pop to the entry for the page we returned to (PopToRoot may skip several).
            while (stack.Count > frame.BackStackDepth + 1) stack.Pop();
            if (stack.Count > 0 && stack.Pop().TryGetTarget(out UIElement? element)) restore = element;
        }

        DispatcherQueueTimerHelper.Run(DispatcherQueue, TimeSpan.FromMilliseconds(80), () =>
        {
            if (restore is not null && restore.XamlRoot is not null && restore.Focus(FocusState.Keyboard)) return;
            FocusDefault();
        });
    }

    private void OnNavigationFailed(object sender, NavigationFailedEventArgs e)
    {
        e.Handled = true;
        App.Log($"Navigation failed: {e.SourcePageType?.Name}: {e.Exception}");
        ShowFatalError($"Could not open {e.SourcePageType?.Name}.\n\n{e.Exception}");
    }

    private void UpdateBackButton()
    {
        BackButton.Visibility = CurrentFrame.CanGoBack ? Visibility.Visible : Visibility.Collapsed;
        UpdateHints();
    }

    /// <summary>Context-specific X and LT/RT entries in the hints bar.</summary>
    private void UpdateHints()
    {
        var provider = CurrentFrame.Content as IHintsProvider;
        string? secondary = provider?.SecondaryHint;
        string? section = provider?.SectionHint;
        XHint.Visibility = secondary is null ? Visibility.Collapsed : Visibility.Visible;
        XHintLabel.Text = secondary ?? "";
        TriggerHint.Visibility = section is null ? Visibility.Collapsed : Visibility.Visible;
        TriggerHintLabel.Text = section ?? "";
    }

    private void UpdateBottomTabs()
    {
        for (int i = 0; i < _bottomButtons.Length; i++)
        {
            bool selected = i == (int)_current;
            _bottomButtons[i].Foreground = selected ? Palette.Brush(Palette.TextTitle) : Palette.Brush(Palette.TextSecondary);
            _bottomButtons[i].Background = selected ? Palette.Brush("#1A1A9FFF") : Palette.Brush(Windows.UI.Color.FromArgb(0, 0, 0, 0));
        }
    }

    private void OnTopNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (_syncingSelection) return;
        int index = Array.IndexOf(_navItems, args.SelectedItemContainer as NavigationViewItem);
        if (index < 0) index = Array.IndexOf(_navItems, args.SelectedItem as NavigationViewItem);
        if (index >= 0 && index != (int)_current)
        {
            SelectTab((AppTab)index, false);
        }
    }

    private void OnTopNavItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        int index = Array.IndexOf(_navItems, args.InvokedItemContainer as NavigationViewItem);
        if (index >= 0 && index == (int)_current)
        {
            PopToRoot(); // re-selecting the active tab pops to its root, like the mobile clients
        }
    }

    private void OnBottomTabClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string tag } && int.TryParse(tag, out int index) && index is >= 0 and < 4)
        {
            if (index == (int)_current) PopToRoot();
            else SelectTab((AppTab)index, false);
        }
    }

    private void OnBackClick(object sender, RoutedEventArgs e) => GoBack();

    private void OnSearchClick(object sender, RoutedEventArgs e) => FocusSearch();

    private void OnFriendsClick(object sender, RoutedEventArgs e) => SelectTab(AppTab.Community, false);

    private void OnAvatarClick(object sender, RoutedEventArgs e) => SelectTab(AppTab.Profile, false);

    // ===================================================================== Focus helpers

    private void FocusDefaultSoon(int delayMs)
    {
        DispatcherQueueTimerHelper.Run(DispatcherQueue, TimeSpan.FromMilliseconds(delayMs), FocusDefault);
    }

    /// <summary>Focus the current page's preferred element (or its first focusable element).</summary>
    public void FocusDefault() => FocusDefault(attempt: 0);

    private void FocusDefault(int attempt)
    {
        object? content = CurrentFrame.Content;
        UIElement? target = (content as IFocusTarget)?.DefaultFocusElement;
        if (target is null && content is IFocusTarget && attempt < 6)
        {
            // Items may not be realized yet right after navigation; try again shortly.
            DispatcherQueueTimerHelper.Run(DispatcherQueue, TimeSpan.FromMilliseconds(150), () => FocusDefault(attempt + 1));
            return;
        }
        if (target is null && content is DependencyObject page)
        {
            target = FocusManager.FindFirstFocusableElement(page) as UIElement;
        }
        target?.Focus(FocusState.Keyboard);
    }

    private void FocusTabBar()
    {
        if (TopNav.Visibility == Visibility.Visible)
        {
            _navItems[(int)_current].Focus(FocusState.Keyboard);
        }
        else
        {
            _bottomButtons[(int)_current].Focus(FocusState.Keyboard);
        }
    }

    private bool IsInContent(DependencyObject? element)
    {
        for (DependencyObject? cur = element; cur is not null; cur = VisualTreeHelper.GetParent(cur))
        {
            if (cur == ContentHost || cur == AppTitleBar || cur == BottomTabs) return true;
        }
        return false;
    }

    // ===================================================================== Gamepad (called by GamepadController)

    public void HandlePad(PadAction action)
    {
        DependencyObject? focused = XamlRoot is null ? null : FocusManager.GetFocusedElement(XamlRoot) as DependencyObject;

        if (focused is null || !IsInContent(focused))
        {
            if (action is PadAction.Up or PadAction.Down or PadAction.Left or PadAction.Right or PadAction.Accept)
            {
                FocusDefault();
                return;
            }
        }

        if (CurrentFrame.Content is IGamepadAware aware && aware.HandlePad(action, focused)) return;

        switch (action)
        {
            case PadAction.Up: MoveFocus(FocusNavigationDirection.Up); break;
            case PadAction.Down: MoveFocus(FocusNavigationDirection.Down); break;
            case PadAction.Left: MoveFocus(FocusNavigationDirection.Left); break;
            case PadAction.Right: MoveFocus(FocusNavigationDirection.Right); break;
            case PadAction.Accept:
                if (focused is NavigationViewItem navItem && Array.IndexOf(_navItems, navItem) is int navIndex && navIndex >= 0)
                {
                    SelectTab((AppTab)navIndex, true);
                }
                else
                {
                    Activate(focused);
                }
                break;
            case PadAction.Back:
                if (!GoBack()) FocusTabBar();
                break;
            case PadAction.Search: FocusSearch(); break;
            case PadAction.PreviousTab: SelectTab((AppTab)(((int)_current + 3) % 4), true); break;
            case PadAction.NextTab: SelectTab((AppTab)(((int)_current + 1) % 4), true); break;
        }
    }

    private void MoveFocus(FocusNavigationDirection direction)
    {
        if (XamlRoot?.Content is not DependencyObject root) return;
        var options = new FindNextElementOptions { SearchRoot = root };
        FocusManager.TryMoveFocus(direction, options);
    }

    /// <summary>Gamepad A: invoke the focused element through its automation peer.</summary>
    private static void Activate(DependencyObject? focused)
    {
        if (focused is not UIElement element) return;
        AutomationPeer? peer = FrameworkElementAutomationPeer.FromElement(element)
                               ?? FrameworkElementAutomationPeer.CreatePeerForElement(element);
        if (peer is null) return;

        if (peer.GetPattern(PatternInterface.Invoke) is IInvokeProvider invoke)
        {
            invoke.Invoke();
        }
        else if (peer.GetPattern(PatternInterface.Toggle) is IToggleProvider toggle)
        {
            toggle.Toggle();
        }
        else if (peer.GetPattern(PatternInterface.SelectionItem) is ISelectionItemProvider selection)
        {
            selection.Select();
        }
        else if (peer.GetPattern(PatternInterface.ExpandCollapse) is IExpandCollapseProvider expand)
        {
            if (expand.ExpandCollapseState == ExpandCollapseState.Collapsed) expand.Expand();
            else expand.Collapse();
        }
    }

    // ===================================================================== Input mode

    private void OnInputModeChanged(object? sender, InputMode mode)
    {
        if (DispatcherQueue.HasThreadAccess) ApplyInputMode();
        else DispatcherQueue.TryEnqueue(ApplyInputMode);
    }

    private void ApplyInputMode()
    {
        bool gamepad = InputModeService.Current == InputMode.Gamepad;
        HintsBar.Visibility = gamepad ? Visibility.Visible : Visibility.Collapsed;
        Visibility glyphs = gamepad || InputModeService.GamepadPresent ? Visibility.Visible : Visibility.Collapsed;
        LbGlyph.Visibility = glyphs;
        RbGlyph.Visibility = glyphs;
        ControllerLabel.Text = _gamepad?.ControllerName ?? "Controller";
    }

    private void OnRootPreviewKeyDown(object sender, KeyRoutedEventArgs e)
    {
        int key = (int)e.Key;
        if (key >= 195 && key <= 218)
        {
            // GamepadA..GamepadRightThumbstickLeft: the poller owns gamepad input; don't let XAML act twice.
            InputModeService.Set(InputMode.Gamepad);
            e.Handled = true;
            return;
        }
        // A lone modifier (e.g. Alt+Tab away mid-game) isn't keyboard navigation.
        if (e.Key is VirtualKey.Shift or VirtualKey.Control or VirtualKey.Menu
            or VirtualKey.LeftShift or VirtualKey.RightShift
            or VirtualKey.LeftControl or VirtualKey.RightControl
            or VirtualKey.LeftMenu or VirtualKey.RightMenu
            or VirtualKey.LeftWindows or VirtualKey.RightWindows)
        {
            return;
        }
        InputModeService.Set(InputMode.Keyboard);
    }

    private void OnRootKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Handled) return;
        switch (e.Key)
        {
            case VirtualKey.Escape:
                if (!GoBack()) FocusTabBar();
                e.Handled = true;
                break;
            case VirtualKey.Back:
                object? focusedElement = XamlRoot is null ? null : FocusManager.GetFocusedElement(XamlRoot);
                if (focusedElement is not (TextBox or PasswordBox) && GoBack())
                {
                    e.Handled = true;
                }
                break;
            case VirtualKey.GoBack:
                e.Handled = GoBack();
                break;
        }
    }

    private void OnRootPointerPressed(object sender, PointerRoutedEventArgs e)
    {
        PointerPoint point = e.GetCurrentPoint(RootGrid);
        if (point.Properties.IsXButton1Pressed)
        {
            GoBack();
            e.Handled = true;
        }
        InputModeService.Set(e.Pointer.PointerDeviceType == PointerDeviceType.Mouse ? InputMode.Mouse : InputMode.Touch);
    }

    private void OnRootPointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (e.Pointer.PointerDeviceType != PointerDeviceType.Mouse) return;

        // Windows synthesizes mouse moves when content changes under a resting cursor, so only a
        // real move of a few pixels (relative to the last known position) switches back to mouse mode.
        Point p = e.GetCurrentPoint(RootGrid).Position;
        Point? last = _lastPointerPosition;
        _lastPointerPosition = p;

        if (InputModeService.Current == InputMode.Mouse) return;
        if (_options.ForceGamepad && InputModeService.Current == InputMode.Gamepad) return;
        if (last is Point previous)
        {
            double dx = p.X - previous.X, dy = p.Y - previous.Y;
            if (dx * dx + dy * dy > 144) InputModeService.Set(InputMode.Mouse);
        }
    }

    private void OnRootPointerWheel(object sender, PointerRoutedEventArgs e)
    {
        if (e.Pointer.PointerDeviceType == PointerDeviceType.Mouse) InputModeService.Set(InputMode.Mouse);
    }

    private void AddAccelerator(VirtualKey key, VirtualKeyModifiers modifiers, Action action)
    {
        var accelerator = new KeyboardAccelerator { Key = key, Modifiers = modifiers };
        accelerator.Invoked += (_, args) =>
        {
            args.Handled = true;
            InputModeService.Set(InputMode.Keyboard);
            action();
        };
        KeyboardAccelerators.Add(accelerator);
    }

    // ===================================================================== Title bar drag / passthrough regions

    /// <summary>
    /// The whole title bar row is the caption (drag) area; the tab strip and the buttons on it are
    /// registered as passthrough so they stay clickable (Windows App SDK InputNonClientPointerSource).
    /// </summary>
    private void UpdateTitleBarRegions()
    {
        if (_window is null || XamlRoot is null) return;
        double scale = XamlRoot.RasterizationScale;
        if (scale <= 0) return;

        try
        {
            var titleBar = _window.AppWindow.TitleBar;
            double right = Math.Max(0, titleBar.RightInset / scale);
            double left = Math.Max(0, titleBar.LeftInset / scale);
            if (Math.Abs(RightInsetColumn.Width.Value - right) > 0.5) RightInsetColumn.Width = new GridLength(right);
            if (Math.Abs(LeftInsetColumn.Width.Value - left) > 0.5) LeftInsetColumn.Width = new GridLength(left);

            var rects = new List<RectInt32>();
            AddRect(rects, BackButton, scale);
            if (TopNav.Visibility == Visibility.Visible)
            {
                foreach (NavigationViewItem item in _navItems) AddRect(rects, item, scale);
            }
            AddRect(rects, RightCluster, scale);

            string key = string.Join(";", rects.Select(r => $"{r.X},{r.Y},{r.Width},{r.Height}"));
            if (key == _lastRegionKey) return;
            _lastRegionKey = key;

            InputNonClientPointerSource source = InputNonClientPointerSource.GetForWindowId(_window.AppWindow.Id);
            source.SetRegionRects(NonClientRegionKind.Passthrough, rects.ToArray());
        }
        catch (Exception ex)
        {
            App.Log("UpdateTitleBarRegions: " + ex.Message);
        }
    }

    private static void AddRect(List<RectInt32> rects, FrameworkElement element, double scale)
    {
        if (element.Visibility != Visibility.Visible || element.ActualWidth <= 0 || element.ActualHeight <= 0) return;
        GeneralTransform transform = element.TransformToVisual(null);
        Rect bounds = transform.TransformBounds(new Rect(0, 0, element.ActualWidth, element.ActualHeight));
        rects.Add(new RectInt32(
            (int)Math.Round(bounds.X * scale),
            (int)Math.Round(bounds.Y * scale),
            (int)Math.Round(bounds.Width * scale),
            (int)Math.Round(bounds.Height * scale)));
    }
}
