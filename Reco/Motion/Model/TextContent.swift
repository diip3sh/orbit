//
//  TextContent.swift
//  Reco
//

import Foundation

/// A text layer: drawn once per plan with Core Text in a system face (spec 0010 decided SF Pro,
/// New York and SF Mono).
nonisolated struct TextContent: Equatable, Sendable {

    nonisolated enum Face: String, Codable, Sendable {
        case sans, serif, mono
    }

    nonisolated enum Weight: String, Codable, Sendable {
        case regular, medium, semibold, bold
    }

    nonisolated enum Alignment: String, Codable, Sendable {
        case leading, center, trailing
    }

    var text: String
    var face = Face.sans
    var weight = Weight.semibold

    /// Point size in canvas pixels.
    var size = 64.0

    var color = RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    var alignment = Alignment.leading

    /// Where lines wrap, in canvas pixels; `nil` for one line per paragraph.
    var width: Double?
}

// MARK: - Codable

nonisolated extension TextContent: Codable {

    /// Only `text` is required.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        face = try container.decodeIfPresent(Face.self, forKey: .face) ?? .sans
        weight = try container.decodeIfPresent(Weight.self, forKey: .weight) ?? .semibold
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? 64
        color = try container.decodeIfPresent(RGBAColor.self, forKey: .color) ?? RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        alignment = try container.decodeIfPresent(Alignment.self, forKey: .alignment) ?? .leading
        width = try container.decodeIfPresent(Double.self, forKey: .width)
    }
}
