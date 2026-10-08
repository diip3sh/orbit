//
//  ThemeContrastTests.swift
//  RecoTests
//

import Testing

/// The theme's roles meet WCAG on every surface, in dark and light, with and without Increase Contrast, as the token
/// file sets them (`ThemeTokenFileTests` holds the asset catalog to the file).
struct ThemeContrastTests {

    static let surfaces = ["stage", "panel", "surface", "raised", "control"]

    /// Text needs 4.5:1; ink is held to 7:1 (AAA), since it is most of what is read. Faint marks and the accent's
    /// lines are non-text, 3:1.
    static let foregrounds: [String: Double] = ["ink": 7, "dim": 4.5, "faint": 3, "accent": 3]

    @Test(arguments: ThemeTokens.Variant.allCases)
    func foregroundsReadOnEverySurface(_ variant: ThemeTokens.Variant) throws {
        let tokens = try ThemeTokens()
        for (foreground, minimum) in Self.foregrounds {
            for surface in Self.surfaces {
                let ratio = ThemeTokens.contrast(try tokens.hex(of: foreground, variant), try tokens.hex(of: surface, variant))
                #expect(ratio >= minimum, "\(foreground) on \(surface) in \(variant.rawValue): \(ratio)")
            }
        }
    }

    @Test(arguments: ThemeTokens.Variant.allCases)
    func textOnTheAccentFillReads(_ variant: ThemeTokens.Variant) throws {
        let tokens = try ThemeTokens()
        let ratio = ThemeTokens.contrast(try tokens.hex(of: "onAccent", variant), try tokens.hex(of: "accentFill", variant))
        #expect(ratio >= 7, "\(variant.rawValue): \(ratio)")
    }
}
