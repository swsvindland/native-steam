using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace NativeSteam.Controls;

/// <summary>
/// Stacks its children on top of each other (like a single-cell Grid) but reports a desired width
/// of zero, so a card's overlay text never widens the cells of a <see cref="UniformGridLayout"/>
/// (which sizes every cell from the first item). Children are arranged to the full final size and
/// keep their own alignment and margins.
/// </summary>
public sealed class OverlayPanel : Panel
{
    protected override Size MeasureOverride(Size availableSize)
    {
        double height = 0;
        foreach (UIElement child in Children)
        {
            child.Measure(availableSize);
            height = Math.Max(height, child.DesiredSize.Height);
        }
        if (!double.IsInfinity(availableSize.Height)) height = Math.Min(height, availableSize.Height);
        return new Size(0, height);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        var rect = new Rect(0, 0, finalSize.Width, finalSize.Height);
        foreach (UIElement child in Children)
        {
            child.Arrange(rect);
        }
        return finalSize;
    }
}
