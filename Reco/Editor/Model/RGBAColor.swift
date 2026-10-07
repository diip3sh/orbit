//
//  RGBAColor.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics

/// A color as sRGB components, so it can be saved in a project.
nonisolated struct RGBAColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    /// The color as a `CGColor`. Setting a color that can't be converted to sRGB, like a pattern,
    /// keeps the current one.
    var cgColor: CGColor {
        get { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
        set { self = RGBAColor(newValue) ?? self }
    }
}

extension RGBAColor {

    /// Converts `color` to sRGB, or returns `nil` when it can't be.
    nonisolated init?(_ color: CGColor) {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let components = color.converted(to: sRGB, intent: .defaultIntent, options: nil)?.components,
              components.count == 4 else {
            return nil
        }
        self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3])
    }
}

// MARK: - Hex

extension RGBAColor {

    /// `#rrggbb` or `#rrggbbaa`, as `inspect_page`'s brand writes colors; `nil` for anything else.
    nonisolated init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
        let component = { (shift: UInt64) in Double((value >> shift) & 0xFF) / 255 }
        let shift: UInt64 = digits.count == 8 ? 8 : 0
        self.init(red: component(16 + shift), green: component(8 + shift), blue: component(shift), alpha: digits.count == 8 ? component(0) : 1)
    }

    /// Reads an object of components, or a hex string, which agents write.
    nonisolated init(from decoder: any Decoder) throws {
        if let hex = try? decoder.singleValueContainer().decode(String.self) {
            guard let color = RGBAColor(hex: hex) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A color is #rrggbb or #rrggbbaa"))
            }
            self = color
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red), green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue), alpha: try container.decode(Double.self, forKey: .alpha)
        )
    }
}
