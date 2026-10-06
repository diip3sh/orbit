//
//  LayoutRules.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Where things go on the canvas and how large type is: one place, used by the shots and the lint.
nonisolated enum LayoutRules {

    /// Graphics stay inside 90% of the frame (EBU R95).
    static func safeArea(of canvas: CGSize) -> CGRect {
        CGRect(origin: .zero, size: canvas).insetBy(dx: canvas.width * 0.05, dy: canvas.height * 0.05)
    }

    /// Where left-aligned titles start, inside the safe area.
    static func margin(of canvas: CGSize) -> Double {
        canvas.width * 0.08
    }

    /// A headline's point size: its capitals 6.7% of the frame's height, the reference films' median
    /// (2.8–8.9%), with SF Pro's capitals at 0.7 of the size.
    static func headlineSize(of canvas: CGSize) -> Double {
        canvas.height * 0.095
    }

    /// A line under a headline, and a feature's text.
    static func detailSize(of canvas: CGSize) -> Double {
        canvas.height * 0.04
    }

    static func featureSize(of canvas: CGSize) -> Double {
        canvas.height * 0.06
    }

    /// Body text is at least 32 px at 1080p (HyperFrames, BBC).
    static func minimumTextSize(of canvas: CGSize) -> Double {
        32 * canvas.height / 1080
    }

    /// The smallest headline capital the reference films show: 2.8% of the frame's height.
    static func minimumCapHeight(of canvas: CGSize) -> Double {
        canvas.height * 0.028
    }

    /// Contrast text needs over its background (WCAG, as Remocn's design check): 4.5:1, 3:1 from 24 px
    /// at 1080p.
    static func minimumContrast(forSize size: Double, canvas: CGSize) -> Double {
        size >= 24 * canvas.height / 1080 ? 3 : 4.5
    }

    /// WCAG's contrast ratio between two opaque colors.
    static func contrast(_ first: RGBAColor, _ second: RGBAColor) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: RGBAColor) -> Double {
        let linear = { (value: Double) in value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// A UI element's width fitted into `box`, at its `size`'s aspect ratio (16:10 until it's lifted).
    static func fittedWidth(of size: CGSize?, in box: CGSize) -> Double {
        let aspect = size.map { $0.height / max($0.width, 1) } ?? 0.625
        return min(box.width, box.height / aspect)
    }
}
