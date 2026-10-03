//
//  PageInspection.swift
//  Reco
//

import CoreGraphics

/// What ``WebInspectScript`` found in a page, at scroll 0: the page's size, its visible interactive
/// elements and the boxes of the selectors asked for. Boxes are in page CSS pixels.
nonisolated struct PageInspection: Codable, Equatable, Sendable {
    var title: String
    var url: String

    /// The page's own summary (its meta or Open Graph description), for an agent learning what
    /// the product does; `nil` when it has none.
    var description: String?
    var viewport: Size
    var pageHeight: Double
    var elements: [Element]

    /// Whether the page had more elements than ``elements`` lists.
    var truncated: Bool

    /// The box of the first element each requested selector matches; `nil` when none were requested.
    var boxes: [String: Box]?

    private enum CodingKeys: String, CodingKey {
        case title, url, description, viewport, elements, truncated, boxes
        case pageHeight = "page_height"
    }

    nonisolated struct Element: Codable, Equatable, Sendable {
        var selector: String
        var role: String
        var text: String
        var box: Box

        /// Where a link goes.
        var href: String?
    }

    nonisolated struct Box: Codable, Equatable, Sendable {
        var left: Double
        var top: Double
        var width: Double
        var height: Double

        var rect: CGRect {
            CGRect(x: left, y: top, width: width, height: height)
        }

        // swiftlint:disable:next nesting - a wire name that is not a valid identifier here
        private enum CodingKeys: String, CodingKey {
            case left = "x"
            case top = "y"
            case width, height
        }
    }

    nonisolated struct Size: Codable, Equatable, Sendable {
        var width: Double
        var height: Double
    }
}
