//
//  StyleTokens.swift
//  Reco
//

import Foundation

/// The brand a document's shots are drawn in, from `inspect_page`'s `brand`: two products get
/// different videos from the same shot list without a dice roll. The background is the canvas's.
nonisolated struct StyleTokens: Equatable, Sendable {
    var text = RGBAColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)

    /// Secondary text: a subtitle, an address.
    var dim = RGBAColor(red: 0.55, green: 0.56, blue: 0.6, alpha: 1)

    /// The one accent: the end card's call to action, if the brand has one.
    var accent: RGBAColor?

    var face = TextContent.Face.sans

    /// Where titles sit: on the left of the safe area, or centred.
    var alignment = TextContent.Alignment.leading
}

// MARK: - Codable

nonisolated extension StyleTokens: Codable {

    init(from decoder: any Decoder) throws {
        let defaults = StyleTokens()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(RGBAColor.self, forKey: .text) ?? defaults.text
        dim = try container.decodeIfPresent(RGBAColor.self, forKey: .dim) ?? defaults.dim
        accent = try container.decodeIfPresent(RGBAColor.self, forKey: .accent)
        face = try container.decodeIfPresent(TextContent.Face.self, forKey: .face) ?? defaults.face
        alignment = try container.decodeIfPresent(TextContent.Alignment.self, forKey: .alignment) ?? defaults.alignment
    }
}
