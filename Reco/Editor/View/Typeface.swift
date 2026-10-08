//
//  Typeface.swift
//  Reco
//

import AppKit

/// Reco's two typefaces, variable fonts bundled in `Fonts/` (SIL OFL 1.1) and registered at launch by
/// `ATSApplicationFontsPath`.
nonisolated enum Typeface: Sendable {
    /// Inter: every label, title and control.
    case sans
    /// JetBrains Mono: times, shortcuts, sizes and other values read digit by digit.
    case mono

    var family: String {
        switch self {
        case .sans: "Inter Variable"
        case .mono: "JetBrains Mono"
        }
    }

    /// The OpenType `wght` axis.
    private static let weightAxis = 0x7767_6874

    /// The font at `size` and `weight` (the `wght` axis' value, 100–900), or the system font if the bundled one
    /// is missing.
    func font(size: CGFloat, weight: CGFloat) -> NSFont {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .variation: [NSNumber(value: Self.weightAxis): weight],
        ])
        if let font = NSFont(descriptor: descriptor, size: size), font.familyName == family {
            return font
        }
        return switch self {
        case .sans: .systemFont(ofSize: size, weight: NSFont.Weight(weight: weight))
        case .mono: .monospacedSystemFont(ofSize: size, weight: NSFont.Weight(weight: weight))
        }
    }
}

private extension NSFont.Weight {
    /// The system weight nearest a `wght` value.
    nonisolated init(weight: CGFloat) {
        self = switch weight {
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        default: .bold
        }
    }
}
