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

    /// What stays on screen as the page scrolls (fixed and sticky elements, outermost only): a
    /// navigation bar, or what a take may hide, like a cookie banner or a chat button.
    var overlays: [Overlay]?

    /// The page's look, for a launch video's style (spec 0010, step 3).
    var brand: Brand?

    /// The box of the first element each requested selector matches; `nil` when none were requested.
    var boxes: [String: Box]?

    /// Seconds of rendering per second of video, by scale ("1", "2"), measured on this page; `nil`
    /// until measured.
    var renderCost: [String: Double]?

    private enum CodingKeys: String, CodingKey {
        case title, url, description, viewport, elements, truncated, overlays, brand, boxes
        case pageHeight = "page_height"
        case renderCost = "render_cost"
    }

    nonisolated struct Element: Codable, Equatable, Sendable {
        var selector: String
        var role: String
        var text: String
        var box: Box

        /// Where a link goes.
        var href: String?
    }

    nonisolated struct Brand: Codable, Equatable, Sendable {

        /// `#rrggbb`: behind the page's first screen, and of its main heading.
        var background: String
        var text: String

        /// The background of the largest painted link or button on the first screen, the main call
        /// to action; `nil` without one.
        var accent: String?

        /// `serif`, `sans` or `mono`, and the family the main heading asks for first.
        var face: String
        var font: String

        /// The image or drawing in the link to the home page.
        var logo: Logo?
    }

    nonisolated struct Logo: Codable, Equatable, Sendable {
        var selector: String
        var box: Box
    }

    nonisolated struct Overlay: Codable, Equatable, Sendable {
        var selector: String

        /// `fixed` or `sticky`.
        var position: String
        var text: String
        var box: Box
    }

    nonisolated struct Box: Codable, Equatable, Sendable {
        var left: Double
        var top: Double
        var width: Double
        var height: Double

        /// The element's top-left corner radius, for the boxes of requested selectors only.
        var radius: Double?

        var rect: CGRect {
            CGRect(x: left, y: top, width: width, height: height)
        }

        // swiftlint:disable:next nesting - a wire name that is not a valid identifier here
        private enum CodingKeys: String, CodingKey {
            case left = "x"
            case top = "y"
            case width, height, radius
        }
    }

    nonisolated struct Size: Codable, Equatable, Sendable {
        var width: Double
        var height: Double
    }
}
