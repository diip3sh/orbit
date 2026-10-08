//
//  ThemeTokens.swift
//  RecoTests
//

import Foundation
import Testing

/// `theme/theme.tokens.json` and the asset catalog's colour sets as they are in the repository, for the theme tests.
/// Read from source: AppKit resolves a colour set's Increase Contrast variant only for the system's own effective
/// appearance, never for `NSAppearance(named: .accessibilityHighContrastDarkAqua)` (measured 2026-10-08: every role
/// came back with its normal value), so the files are the only place all four variants can be checked.
struct ThemeTokens {

    enum Variant: String, CaseIterable, Sendable {
        case dark, light, darkHighContrast, lightHighContrast
    }

    static let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    let json: [String: Any]

    init() throws {
        let data = try Data(contentsOf: Self.repository.appending(path: "theme/theme.tokens.json"))
        json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func group(_ name: String) throws -> [String: [String: Any]] {
        try #require(json[name] as? [String: [String: Any]], "no `\(name)` group")
    }

    var roles: [String] {
        get throws { try group("role").keys.sorted() }
    }

    /// The role's `#rrggbb` in `variant`, aliases followed.
    func hex(of role: String, _ variant: Variant) throws -> String {
        let token = try #require(try group("role")[role], "no role \(role)")
        let value = variant == .dark
            ? token["$value"] as? String
            : (token["$extensions"] as? [String: [String: String]])?["com.reco.theme"]?[variant.rawValue]
        return try resolve(try #require(value, "\(role) has no \(variant.rawValue)"))
    }

    /// What the role's colour set in `Reco/Assets.xcassets` holds, by variant.
    static func colourSet(of role: String) throws -> [Variant: String] {
        let folder = role == "accent" ? "AccentColor.colorset" : "Theme/\(role.prefix(1).uppercased() + role.dropFirst()).colorset"
        let url = repository.appending(path: "Reco/Assets.xcassets/\(folder)/Contents.json")
        let contents = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var variants: [Variant: String] = [:]
        for entry in try #require(contents["colors"] as? [[String: Any]]) {
            let appearances = (entry["appearances"] as? [[String: String]] ?? []).compactMap { $0["value"] }
            let variant: Variant = switch (appearances.contains("dark"), appearances.contains("high")) {
            case (true, true): .darkHighContrast
            case (false, true): .lightHighContrast
            case (true, false): .dark
            case (false, false): .light
            }
            let components = try #require((entry["color"] as? [String: Any])?["components"] as? [String: String])
            variants[variant] = "#" + ["red", "green", "blue"].compactMap { components[$0]?.dropFirst(2).lowercased() }.joined()
        }
        return variants
    }

    /// WCAG 2's contrast ratio between two `#rrggbb` colours.
    static func contrast(_ first: String, _ second: String) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ hex: String) -> Double {
        let channels = [1, 3, 5].map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return Double(Int(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16) ?? 0) / 255
        }
        let linear = channels.map { $0 <= 0.039_28 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private func resolve(_ value: String) throws -> String {
        guard value.hasPrefix("{"), value.hasSuffix("}") else { return value.lowercased() }
        var node: Any = json
        for key in value.dropFirst().dropLast().split(separator: ".") {
            node = try #require((node as? [String: Any])?[String(key)], "\(value) points at nothing")
        }
        return try resolve(try #require((node as? [String: Any])?["$value"] as? String))
    }
}
