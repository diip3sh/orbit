//
//  OKLCH.swift
//  Reco
//

import Foundation

/// A colour in OKLCH, OKLab's polar form (Björn Ottosson, 2020): perceived lightness 0–1, chroma,
/// and hue in degrees. Fields are coloured in it: changing a colour's hue or chroma keeps its
/// lightness, which sRGB doesn't.
nonisolated struct OKLCH: Equatable, Sendable {
    var lightness: Double
    var chroma: Double
    var hue: Double

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    /// `color`'s sRGB components; its alpha is dropped.
    init(_ color: RGBAColor) {
        let (red, green, blue) = (Self.linear(color.red), Self.linear(color.green), Self.linear(color.blue))
        let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
        let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
        let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
        lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
        let greenRed = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
        let blueYellow = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
        chroma = hypot(greenRed, blueYellow)
        hue = (atan2(blueYellow, greenRed) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// In sRGB, opaque: with the chroma lowered as little as it takes to fit, so the lightness and
    /// hue stay.
    var rgba: RGBAColor {
        if let color = Self.srgb(lightness, chroma, hue) {
            return color
        }
        var (fits, misses) = (0.0, chroma)
        for _ in 0..<24 {
            let middle = (fits + misses) / 2
            if Self.srgb(lightness, middle, hue) == nil {
                misses = middle
            } else {
                fits = middle
            }
        }
        return Self.srgb(lightness, fits, hue) ?? RGBAColor(red: lightness, green: lightness, blue: lightness, alpha: 1)
    }

    /// The colour in sRGB, or `nil` when it's outside it.
    private static func srgb(_ lightness: Double, _ chroma: Double, _ hue: Double) -> RGBAColor? {
        let angle = hue * .pi / 180
        let (greenRed, blueYellow) = (chroma * cos(angle), chroma * sin(angle))
        let long = pow(lightness + 0.3963377774 * greenRed + 0.2158037573 * blueYellow, 3)
        let medium = pow(lightness - 0.1055613458 * greenRed - 0.0638541728 * blueYellow, 3)
        let short = pow(lightness - 0.0894841775 * greenRed - 1.2914855480 * blueYellow, 3)
        let linear = [
            4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
            -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
            -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short
        ]
        // A hair outside from rounding is inside
        guard linear.allSatisfy({ (-1e-6...1 + 1e-6).contains($0) }) else { return nil }
        let encoded = linear.map { encode(min(max($0, 0), 1)) }
        return RGBAColor(red: encoded[0], green: encoded[1], blue: encoded[2], alpha: 1)
    }

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func encode(_ value: Double) -> Double {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}
