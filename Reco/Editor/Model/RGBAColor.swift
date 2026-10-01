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
