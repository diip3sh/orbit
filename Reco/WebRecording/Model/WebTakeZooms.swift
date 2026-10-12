//
//  WebTakeZooms.swift
//  Reco
//

import CoreGraphics
import Foundation

/// The zooms a web take's script asks for (spec 0009): a cursor clip that shows an element has the
/// view frame that element while the clip runs, in place of auto-zoom's view around wherever the
/// cursor stops. Built as the take renders, from where each element is when its clip starts.
nonisolated struct WebTakeZooms: Sendable {

    let viewport: CGSize

    /// The share of the view the shown element fills at most, so it has room around it.
    static let fill = 0.8

    /// The most the view is magnified: a page rendered at 2× stays sharp to about here.
    static let maximumScale = 3.0

    /// An element the view would magnify less than this shows the whole frame instead: there's
    /// nothing to zoom in on.
    static let minimumScale = 1.1

    /// How much of the element must be in view for the view to frame what is.
    static let visibleShare = 0.5

    private var shots: [(range: Range<Double>, frame: CGRect)] = []

    init(viewport: CGSize) {
        self.viewport = viewport
    }

    /// Whether `frame`, an element's box in viewport CSS pixels, can be framed: at least
    /// ``visibleShare`` of it is in the viewport. `nil`, a missing element, can't.
    static func canFrame(_ frame: CGRect?, in viewport: CGSize) -> Bool {
        guard let frame, frame.width > 0, frame.height > 0 else { return false }
        let visible = frame.intersection(CGRect(origin: .zero, size: viewport))
        return visible.width * visible.height >= Self.visibleShare * frame.width * frame.height
    }

    /// Frames the part of `frame`, the shown element's box in viewport CSS pixels where its clip
    /// starts, that is in view, for the clip's `range`.
    mutating func show(_ frame: CGRect, during range: Range<Double>) {
        shots.append((range, frame.intersection(CGRect(origin: .zero, size: viewport))))
    }

    /// The zooms, sorted and apart. Each lasts its clip, or until ``AutoZoomGenerator/Configuration/scrollHold``
    /// after the first of `scrolls` (a scroll's or a navigation's start) inside it, as a held rest's
    /// zoom does; one the page scrolls or changes under within ``AutoZoomGenerator/Configuration/leadTime``
    /// of its start, like a click that opens a page, is left out, since the view would only zoom in and
    /// straight back out. One that the next follows within ``AutoZoomGenerator/Configuration/mergeGap``
    /// ends where the next starts, so the view pans across. An element that would be magnified less
    /// than ``minimumScale`` makes none.
    func segments(endingAt scrolls: [Double]) -> [ZoomSegment] {
        let configuration = AutoZoomGenerator.Configuration()
        var zooms: [ZoomSegment] = shots.compactMap { shot in
            let scale = min(Self.maximumScale, Self.fill * viewport.width / shot.frame.width, Self.fill * viewport.height / shot.frame.height)
            guard scale >= Self.minimumScale else { return nil }
            var end = shot.range.upperBound
            if let scroll = scrolls.filter({ $0 >= shot.range.lowerBound && $0 < end }).min() {
                guard scroll - shot.range.lowerBound >= configuration.leadTime else { return nil }
                end = min(end, scroll + configuration.scrollHold)
            }
            let center = CGPoint(x: shot.frame.midX / viewport.width, y: shot.frame.midY / viewport.height)
            return ZoomSegment(range: shot.range.lowerBound..<end, scale: scale, focus: .fixed(center: ZoomSegment.clamped(center, scale: scale)))
        }
        zooms.sort { $0.range.lowerBound < $1.range.lowerBound }
        // Clips on the Cursor lane don't overlap, so a zoom never reaches past the next clip's start
        for index in zooms.indices.dropLast() {
            let next = zooms[index + 1].range.lowerBound
            if next - zooms[index].range.upperBound < configuration.mergeGap {
                zooms[index].range = zooms[index].range.lowerBound..<next
            }
        }
        return zooms
    }
}
