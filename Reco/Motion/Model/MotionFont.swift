//
//  MotionFont.swift
//  Reco
//

import Foundation

/// A face of the brand's own type (spec 0019): a font file from its website (`inspect_page`'s `brand.fonts`), by the family
/// text layers and `style.font` name it with. Several files may share a family, one a weight.
nonisolated struct MotionFont: Codable, Equatable, Sendable {
    var family: String
    var url: URL
}
