//
//  EditorViewModel+Zooming.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

// MARK: - Zooming

extension EditorViewModel {

    /// The selected zoom, for the inspector's controls. Each change is an edit, which makes it manual.
    var selectedZoom: ZoomSegment? {
        get {
            guard case .zoom(let id) = selection else { return nil }
            return project.zooms.first { $0.id == id }
        }
        set {
            guard let newValue else { return }
            edit("Zoom", coalescing: true) { $0.zooms = $0.zooms.replacing(newValue) }
        }
    }

    /// Whether a zoom can start at the playhead: it's outside the others, with room for the shortest.
    var canAddZoom: Bool {
        newZoomAtPlayhead != nil
    }

    func selectZoom(_ id: ZoomSegment.ID) {
        selection = .zoom(id)
    }

    /// Adds a zoom at the playhead and selects it. It follows the cursor when there is one to follow.
    func addZoom() {
        guard let zoom = newZoomAtPlayhead else { return }
        edit("Add Zoom") { $0.zooms = $0.zooms.inserting(zoom) }
        selection = .zoom(zoom.id)
    }

    /// Moves a zoom by `offset` seconds, up to its neighbours and the recording's ends.
    func moveZoom(_ id: ZoomSegment.ID, by offset: Double) {
        guard let source else { return }
        edit("Move Zoom") { $0.zooms = $0.zooms.moving(id, by: offset, duration: source.duration) }
    }

    func moveZoomStart(_ id: ZoomSegment.ID, to time: Double) {
        edit("Resize Zoom") { $0.zooms = $0.zooms.movingStart(of: id, to: time) }
    }

    func moveZoomEnd(_ id: ZoomSegment.ID, to time: Double) {
        guard let source else { return }
        edit("Resize Zoom") { $0.zooms = $0.zooms.movingEnd(of: id, to: time, duration: source.duration) }
    }

    /// Replaces the automatic zooms with new ones from the telemetry, keeping the manual ones.
    func regenerateZooms() {
        guard let source, let telemetry = croppedTelemetry else { return }
        let generated = AutoZoomGenerator.segments(for: telemetry, duration: source.duration)
        edit("Regenerate Zooms") { $0.zooms = $0.zooms.regenerated(with: generated) }
    }

    /// Whether zoomed parts look soft: the recording has fewer than 2 video pixels per screen
    /// point, e.g. a Retina display recorded without Native Resolution.
    var zoomsLookSoft: Bool {
        (source?.telemetry?.pixelsPerPoint ?? 2) < 2
    }

    /// The filmstrip's picture nearest source time `time`, once loaded.
    func thumbnail(at time: Double) -> CGImage? {
        guard !thumbnails.isEmpty, timeMap.sourceDuration > 0 else { return nil }
        let index = Int(time / timeMap.sourceDuration * Double(thumbnails.count))
        return thumbnails[min(max(index, 0), thumbnails.count - 1)]
    }

    private var newZoomAtPlayhead: ZoomSegment? {
        guard let source else { return nil }
        let focus: ZoomSegment.Focus = source.telemetry?.cursor.isEmpty == false ? .followCursor : .fixed(center: CGPoint(x: 0.5, y: 0.5))
        return project.zooms.newZoom(at: timeMap.snapped(playheadSourceTime), focus: focus, duration: source.duration)
    }
}
