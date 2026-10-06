//
//  ShapeContent.swift
//  Reco
//

import CoreGraphics

/// A filled rounded rectangle, generated at any scale without a bitmap.
nonisolated struct ShapeContent: Equatable, Sendable {
    var size: CGSize
    var cornerRadius = 0.0
    var color: RGBAColor
}

// MARK: - Codable

nonisolated extension ShapeContent: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decode(CGSize.self, forKey: .size)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        color = try container.decode(RGBAColor.self, forKey: .color)
    }
}
