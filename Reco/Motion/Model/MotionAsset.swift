//
//  MotionAsset.swift
//  Reco
//

import CoreGraphics
import Foundation

/// UI lifted from a web page: the element `selector` matches on the page at `url`, laid out at
/// `viewport` CSS pixels. Captured into the bundle when a plan first needs it (``UILiftCache``).
///
/// Without `steps` it's a still, lifted at the scale it's shown, so `ui` layers stay sharp however
/// far the camera pushes in. With them it's live: a take of the page (the steps of `record_page`:
/// hover, click, type, scroll) cropped to the element's box where the page first shows it, played
/// from the start of each scene that shows it, with its cursor.
nonisolated struct MotionAsset: Equatable, Sendable, Identifiable {
    var id: String
    var url: URL
    var selector: String
    var viewport = CGSize(width: 1440, height: 900)
    var steps: [RecordPageRequest.Step]?

    /// Selectors hidden on the page first, like a cookie banner over a live take's element.
    var hide: [String]?

    /// A live take's length in seconds; when left out, as `record_page` times it.
    var duration: Double?

    /// The live take's script, timed and checked as `record_page` checks its arguments, before the
    /// page has been looked at; `nil` for a still.
    func takePlan() throws(AgentToolError) -> RecordPlan? {
        guard let steps else { return nil }
        var plan = try RecordPageRequest(url: url.absoluteString, duration: duration, steps: steps, hide: hide).plan()
        plan.viewport = viewport
        return plan
    }
}

// MARK: - Codable

nonisolated extension MotionAsset: Codable {

    /// `viewport` may be left out for a 1440×900 desktop.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        selector = try container.decode(String.self, forKey: .selector)
        viewport = try container.decodeIfPresent(CGSize.self, forKey: .viewport) ?? CGSize(width: 1440, height: 900)
        steps = try container.decodeIfPresent([RecordPageRequest.Step].self, forKey: .steps)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        hide = try container.decodeIfPresent([String].self, forKey: .hide)
    }
}
