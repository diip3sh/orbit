//
//  ThemeTokenFileTests.swift
//  RecoTests
//

import AppKit
import Testing
@testable import Reco

/// `theme/theme.tokens.json` is the theme's source: the asset catalog, the typefaces and the radii must match it, so a
/// theme edited there and not applied (`scripts/apply-theme.py`) fails here.
@MainActor
struct ThemeTokenFileTests {

    @Test func colourSetsMatchTheFile() throws {
        let tokens = try ThemeTokens()
        let roles = try tokens.roles
        #expect(!roles.isEmpty)
        for role in roles {
            let colourSet = try ThemeTokens.colourSet(of: role)
            for variant in ThemeTokens.Variant.allCases {
                #expect(colourSet[variant] == (try tokens.hex(of: role, variant)), "\(role) \(variant.rawValue)")
            }
        }
    }

    /// The built app resolves each role by appearance as the file says (dark and light; see `ThemeTokens` for why
    /// Increase Contrast can't be resolved here).
    @Test(arguments: [(ThemeTokens.Variant.dark, NSAppearance.Name.darkAqua), (.light, .aqua)])
    func builtColoursFollowTheAppearance(_ variant: ThemeTokens.Variant, _ appearance: NSAppearance.Name) throws {
        let tokens = try ThemeTokens()
        for role in try tokens.roles {
            let name = role == "accent" ? "AccentColor" : role.prefix(1).uppercased() + role.dropFirst()
            let color = try #require(NSColor(named: name), "no colour set for \(role)")
            #expect(hex(color, in: appearance) == (try tokens.hex(of: role, variant)), "\(role) \(variant.rawValue)")
        }
    }

    @Test func typefacesMatchTheFile() throws {
        let fonts = try ThemeTokens().group("font")
        #expect(fonts["sans"]?["$value"] as? String == Typeface.sans.family)
        #expect(fonts["mono"]?["$value"] as? String == Typeface.mono.family)
    }

    @Test func radiiMatchTheFile() throws {
        let radii = try ThemeTokens().group("radius")
        func points(_ key: String) -> CGFloat? {
            (radii[key]?["$value"] as? String).flatMap { Double($0.replacing("px", with: "")) }.map { CGFloat($0) }
        }
        #expect(points("md") == EditorTheme.smallRadius)
        #expect(points("xl") == EditorTheme.radius)
        #expect(points("2xl") == EditorTheme.largeRadius)
    }

    private func hex(_ color: NSColor, in appearance: NSAppearance.Name) -> String {
        var result = ""
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            let resolved = color.usingColorSpace(.sRGB) ?? color
            let bytes = [resolved.redComponent, resolved.greenComponent, resolved.blueComponent].map { Int(($0 * 255).rounded()) }
            result = "#" + bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
        }
        return result
    }
}
