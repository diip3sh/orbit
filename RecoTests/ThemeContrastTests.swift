//
//  ThemeContrastTests.swift
//  RecoTests
//

import AppKit
import Testing
@testable import Reco

/// The theme's colour sets meet WCAG AA on every surface, in dark and light, with and without Increase Contrast.
@MainActor
struct ThemeContrastTests {

    nonisolated static let appearances: [NSAppearance.Name] = [
        .darkAqua, .aqua, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastAqua
    ]

    static let surfaces: [(String, ColorResource)] = [
        ("stage", .stage), ("panel", .panel), ("surface", .surface), ("raised", .raised), ("control", .control)
    ]

    /// Text needs 4.5:1; ink is held to 7:1 (AAA), since it is most of what is read. Faint marks and the accent's
    /// lines are non-text, 3:1.
    static let foregrounds: [String: (color: NSColor, minimum: Double)] = [
        "ink": (NSColor(resource: .ink), 7),
        "dim": (NSColor(resource: .dim), 4.5),
        "faint": (NSColor(resource: .faint), 3),
        // The asset `Color.accentColor` resolves to while the user's accent is Multicolor
        "accent": (NSColor(named: "AccentColor") ?? .clear, 3)
    ]

    @Test(arguments: appearances)
    func foregroundsReadOnEverySurface(_ appearance: NSAppearance.Name) {
        for (name, (color, minimum)) in Self.foregrounds {
            for (surfaceName, surface) in Self.surfaces {
                let ratio = contrast(color, NSColor(resource: surface), in: appearance)
                #expect(ratio >= minimum, "\(name) on \(surfaceName) in \(appearance.rawValue): \(ratio)")
            }
        }
    }

    @Test(arguments: appearances)
    func textOnTheAccentFillReads(_ appearance: NSAppearance.Name) {
        let ratio = contrast(NSColor(resource: .onAccent), NSColor(resource: .accentFill), in: appearance)
        #expect(ratio >= 7, "\(appearance.rawValue): \(ratio)")
    }

    @Test func darkIsLinearsTokens() {
        let tokens: [(ColorResource, Int)] = [
            (.stage, 0x08090A), (.surface, 0x0F1011), (.raised, 0x161718), (.control, 0x23252A),
            (.hairline, 0x23252A), (.ink, 0xE5E5E6), (.dim, 0x8A8F98), (.accentFill, 0xE4F222)
        ]
        for (resource, hex) in tokens {
            #expect(rgb(NSColor(resource: resource), in: .darkAqua) == hex)
        }
    }

    private func contrast(_ first: NSColor, _ second: NSColor, in appearance: NSAppearance.Name) -> Double {
        let lighter = max(luminance(first, in: appearance), luminance(second, in: appearance))
        let darker = min(luminance(first, in: appearance), luminance(second, in: appearance))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// WCAG 2's relative luminance of the colour as `appearance` resolves it, in sRGB.
    private func luminance(_ color: NSColor, in appearance: NSAppearance.Name) -> Double {
        let components = srgb(color, in: appearance)
        let linear = components.map { $0 <= 0.039_28 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private func rgb(_ color: NSColor, in appearance: NSAppearance.Name) -> Int {
        srgb(color, in: appearance).reduce(0) { $0 << 8 | Int(($1 * 255).rounded()) }
    }

    private func srgb(_ color: NSColor, in appearance: NSAppearance.Name) -> [Double] {
        var components: [Double] = []
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            let resolved = color.usingColorSpace(.sRGB) ?? color
            components = [resolved.redComponent, resolved.greenComponent, resolved.blueComponent].map(Double.init)
        }
        return components
    }
}
