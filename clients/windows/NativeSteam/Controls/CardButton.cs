using System;
using System.Numerics;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using NativeSteam.Services;
using Windows.Foundation;

namespace NativeSteam.Controls;

/// <summary>
/// The focusable, invokable unit for every card / row in the app. Adds the DESIGN.md §3 focus
/// treatment on top of a plain <see cref="Button"/>: 1.04 scale with a 120 ms ease-out when focused
/// by keyboard or gamepad, a small lift on mouse hover, and "bring into view with lookahead" so
/// shelves keep about one card of context visible while navigating with arrows / D-pad.
/// Descendants named <c>Reveal</c> are shown only while hovered or focused (e.g. names on covers).
/// </summary>
public class CardButton : Button
{
    private static readonly TimeSpan AnimationDuration = TimeSpan.FromMilliseconds(120);

    private FrameworkElement? _reveal;
    private bool _revealSearched;
    private bool _hovered;
    private bool _focused;

    public CardButton()
    {
        DefaultStyleKey = typeof(Button);
        ScaleTransition = new Vector3Transition { Duration = AnimationDuration };
        TranslationTransition = new Vector3Transition { Duration = AnimationDuration };
        SizeChanged += OnSizeChanged;
        Loaded += (_, _) => UpdateReveal();
    }

    /// <summary>Scale applied while focused by keyboard / gamepad.</summary>
    public double FocusScale { get; set; } = 1.04;

    /// <summary>Extra room (in card widths) kept visible on each side when focus moves along a shelf.</summary>
    public double Lookahead { get; set; } = 0.6;

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        CenterPoint = new Vector3((float)(e.NewSize.Width / 2), (float)(e.NewSize.Height / 2), 0f);
    }

    protected override void OnGotFocus(RoutedEventArgs e)
    {
        base.OnGotFocus(e);
        if ((FocusState == FocusState.Keyboard || FocusState == FocusState.Programmatic) && InputModeService.IsFocusDriven)
        {
            _focused = true;
            float s = (float)FocusScale;
            Scale = new Vector3(s, s, 1f);
            BringIntoViewWithLookahead();
        }
        UpdateReveal();
    }

    protected override void OnLostFocus(RoutedEventArgs e)
    {
        base.OnLostFocus(e);
        _focused = false;
        Scale = Vector3.One;
        UpdateReveal();
    }

    protected override void OnPointerEntered(PointerRoutedEventArgs e)
    {
        base.OnPointerEntered(e);
        if (e.Pointer.PointerDeviceType == PointerDeviceType.Mouse)
        {
            _hovered = true;
            Translation = new Vector3(0f, -3f, 0f);
            UpdateReveal();
        }
    }

    protected override void OnPointerExited(PointerRoutedEventArgs e)
    {
        base.OnPointerExited(e);
        _hovered = false;
        Translation = Vector3.Zero;
        UpdateReveal();
    }

    protected override void OnPointerCaptureLost(PointerRoutedEventArgs e)
    {
        base.OnPointerCaptureLost(e);
        _hovered = false;
        Translation = Vector3.Zero;
        UpdateReveal();
    }

    private void BringIntoViewWithLookahead()
    {
        double w = ActualWidth, h = ActualHeight;
        if (w <= 0 || h <= 0) return;
        double pad = w * Lookahead;
        StartBringIntoView(new BringIntoViewOptions
        {
            AnimationDesired = true,
            TargetRect = new Rect(-pad, -32, w + 2 * pad, h + 64),
        });
    }

    private void UpdateReveal()
    {
        if (!_revealSearched)
        {
            _revealSearched = true;
            _reveal = FindNamed(this, "Reveal", 0);
        }
        if (_reveal is not null)
        {
            _reveal.Opacity = _hovered || _focused ? 1.0 : 0.0;
        }
    }

    private static FrameworkElement? FindNamed(DependencyObject root, string name, int depth)
    {
        if (depth > 12) return null;
        int count = VisualTreeHelper.GetChildrenCount(root);
        for (int i = 0; i < count; i++)
        {
            DependencyObject child = VisualTreeHelper.GetChild(root, i);
            if (child is FrameworkElement fe && fe.Name == name) return fe;
            FrameworkElement? found = FindNamed(child, name, depth + 1);
            if (found is not null) return found;
        }
        return null;
    }
}
