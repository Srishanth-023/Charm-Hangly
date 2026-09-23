//
//  WrapPanel.cs
//  Hangly
//
//  A WinUI panel that arranges children in lines and wraps to the next line when width is exhausted.
//

using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace Hangly.App.Controls;

public class WrapPanel : Panel
{
    public static readonly DependencyProperty HorizontalSpacingProperty =
        DependencyProperty.Register(
            nameof(HorizontalSpacing),
            typeof(double),
            typeof(WrapPanel),
            new PropertyMetadata(0.0, OnSpacingChanged));

    public static readonly DependencyProperty VerticalSpacingProperty =
        DependencyProperty.Register(
            nameof(VerticalSpacing),
            typeof(double),
            typeof(WrapPanel),
            new PropertyMetadata(0.0, OnSpacingChanged));

    public double HorizontalSpacing
    {
        get => (double)GetValue(HorizontalSpacingProperty);
        set => SetValue(HorizontalSpacingProperty, value);
    }

    public double VerticalSpacing
    {
        get => (double)GetValue(VerticalSpacingProperty);
        set => SetValue(VerticalSpacingProperty, value);
    }

    private static void OnSpacingChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is WrapPanel panel)
        {
            panel.InvalidateMeasure();
            panel.InvalidateArrange();
        }
    }

    protected override Size MeasureOverride(Size availableSize)
    {
        double hSpacing = HorizontalSpacing;
        double vSpacing = VerticalSpacing;

        double currentLineWidth = 0;
        double currentLineHeight = 0;
        double maxLineWidth = 0;
        double totalHeight = 0;

        bool isFirstInLine = true;

        foreach (UIElement child in Children)
        {
            child.Measure(availableSize);
            Size desired = child.DesiredSize;

            double itemWidth = desired.Width;
            double itemHeight = desired.Height;

            double widthWithSpacing = isFirstInLine ? itemWidth : itemWidth + hSpacing;

            if (!isFirstInLine && currentLineWidth + widthWithSpacing > availableSize.Width && availableSize.Width > 0)
            {
                // Wrap to next line
                maxLineWidth = Math.Max(maxLineWidth, currentLineWidth);
                totalHeight += currentLineHeight + vSpacing;

                currentLineWidth = itemWidth;
                currentLineHeight = itemHeight;
                isFirstInLine = false;
            }
            else
            {
                currentLineWidth += widthWithSpacing;
                currentLineHeight = Math.Max(currentLineHeight, itemHeight);
                isFirstInLine = false;
            }
        }

        maxLineWidth = Math.Max(maxLineWidth, currentLineWidth);
        totalHeight += currentLineHeight;

        return new Size(
            double.IsInfinity(availableSize.Width) ? maxLineWidth : Math.Min(maxLineWidth, availableSize.Width),
            totalHeight);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        double hSpacing = HorizontalSpacing;
        double vSpacing = VerticalSpacing;

        double currentX = 0;
        double currentY = 0;
        double currentLineHeight = 0;
        bool isFirstInLine = true;

        foreach (UIElement child in Children)
        {
            Size desired = child.DesiredSize;
            double itemWidth = desired.Width;
            double itemHeight = desired.Height;

            double widthWithSpacing = isFirstInLine ? itemWidth : itemWidth + hSpacing;

            if (!isFirstInLine && currentX + widthWithSpacing > finalSize.Width && finalSize.Width > 0)
            {
                // Move down to next line
                currentY += currentLineHeight + vSpacing;
                currentX = 0;
                currentLineHeight = itemHeight;
                isFirstInLine = true;
            }

            if (!isFirstInLine)
            {
                currentX += hSpacing;
            }

            child.Arrange(new Rect(currentX, currentY, itemWidth, itemHeight));

            currentX += itemWidth;
            currentLineHeight = Math.Max(currentLineHeight, itemHeight);
            isFirstInLine = false;
        }

        return finalSize;
    }
}
