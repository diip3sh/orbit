//
//  EditorViewModel+Overlays.swift
//  Reco
//

import CoreGraphics
import Foundation

// MARK: - Overlays

extension EditorViewModel {

    /// The selected overlay, for the inspector's controls and the stage's handles. Each change is an edit; a drag is one
    /// undo step, and so is typing without a pause.
    var selectedOverlay: VideoOverlay? {
        get {
            guard case .overlay(let id) = selection else { return nil }
            return project.overlays.first { $0.id == id }
        }
        set {
            guard let newValue else { return }
            edit("Overlay", coalescing: true) { $0.overlays = $0.overlays.replacing(newValue) }
        }
    }

    /// Selects an overlay and, when it isn't showing, shows it.
    func selectOverlay(_ id: VideoOverlay.ID) {
        selection = .overlay(id)
        if let overlay = selectedOverlay, !overlay.range.contains(playheadSourceTime) {
            show(overlay)
        }
    }

    /// Adds a text overlay in the middle of the frame at the playhead and selects it, or says why it can't.
    func addTextOverlay() {
        add(.text(TextOverlayStyle()), frame: VideoOverlay.defaultTextFrame)
    }

    /// Adds an arrow in the middle of the frame at the playhead and selects it, or says why it can't.
    func addArrowOverlay() {
        add(.arrow(ArrowOverlayStyle()), frame: VideoOverlay.defaultArrowFrame)
    }

    /// Whether a new overlay would fit at the playhead. If not, says why: before the open panel, so nobody picks a
    /// picture for nothing.
    func canAddOverlay() -> Bool {
        guard let source else { return false }
        if overlayPlacement != nil {
            return true
        }
        // Past the last place the shortest fits, a free lane wouldn't help
        let outOfRoom = playheadSourceTime + VideoOverlay.minimumDuration > source.duration
        fail(outOfRoom ? .noRoomForOverlay : .noFreeOverlayLane)
        return false
    }

    /// Adds the picture at `url`, chosen by the user, in its own shape in the middle of the frame at the playhead, and
    /// selects it. A file that can't be read shows its reason and changes nothing.
    func addImageOverlay(from url: URL) async {
        guard let videoSize, let bookmark = try? BackgroundImageLoader.bookmark(for: url),
              let picture = await BackgroundImageLoader.image(from: bookmark)?.image else {
            fail(.unreadableOverlayImage)
            return
        }
        let size = CGSize(width: picture.width, height: picture.height)
        add(.image(bookmark: bookmark), frame: VideoOverlay.imageFrame(pictureSize: size, videoSize: videoSize))
    }

    /// Makes the selected picture overlay show the picture at `url` instead, in the same frame.
    func replaceOverlayImage(from url: URL) async {
        guard let bookmark = try? BackgroundImageLoader.bookmark(for: url), await BackgroundImageLoader.image(from: bookmark) != nil else {
            fail(.unreadableOverlayImage)
            return
        }
        selectedOverlay?.kind = .image(bookmark: bookmark)
    }

    /// Moves an overlay by `offset` seconds, up to its neighbours on its lane and the recording's ends.
    func moveOverlay(_ id: VideoOverlay.ID, by offset: Double) {
        guard let source else { return }
        edit("Move Overlay") { $0.overlays = $0.overlays.movingOnLane(id, by: offset, duration: source.duration) }
    }

    func moveOverlayStart(_ id: VideoOverlay.ID, to time: Double) {
        edit("Resize Overlay") { $0.overlays = $0.overlays.movingStartOnLane(of: id, to: time) }
    }

    func moveOverlayEnd(_ id: VideoOverlay.ID, to time: Double) {
        guard let source else { return }
        edit("Resize Overlay") { $0.overlays = $0.overlays.movingEndOnLane(of: id, to: time, duration: source.duration) }
    }

    func deleteOverlay(_ id: VideoOverlay.ID) {
        edit("Delete Overlay") { $0.overlays = $0.overlays.removing(id) }
    }

    /// The selected overlay's frame in the stage's view, or `nil` when none is selected.
    func overlayRect(inViewOf viewSize: CGSize) -> CGRect? {
        guard let overlay = selectedOverlay, let videoSize else { return nil }
        let frames = CanvasLayout.frames(for: videoSize, style: project.canvas)
        return CameraBubbleLayout.viewRect(of: PlannedOverlay.rect(of: overlay.frame, in: frames.video), canvas: frames.canvas, viewSize: viewSize)
    }

    /// A drag of `translation` points in the stage's view, as fractions of the video.
    private func overlayShare(of translation: CGSize, viewSize: CGSize) -> CGSize? {
        videoSize.map { videoSize in
            let frames = CanvasLayout.frames(for: videoSize, style: project.canvas)
            return CameraBubbleLayout.videoShare(of: translation, viewSize: viewSize, canvas: frames.canvas, videoSize: frames.video.size)
        }
    }

    /// Moves `edges` of the selected overlay `translation` points in the stage's view from how it was at `start`; all four
    /// move it whole.
    func dragOverlay(from start: VideoOverlay, edges: RegionDrag.Edges, by translation: CGSize, viewSize: CGSize) {
        guard let share = overlayShare(of: translation, viewSize: viewSize) else { return }
        selectedOverlay?.frame = RegionDrag.dragged(start.frame, edges: edges, by: share, minimumSize: VideoOverlay.minimumSize)
    }

    /// Moves the selected arrow's tail or tip `translation` points in the stage's view from how it was at `start`.
    func dragArrow(from start: VideoOverlay, movingTip: Bool, by translation: CGSize, viewSize: CGSize) {
        guard let style = start.arrowStyle, let share = overlayShare(of: translation, viewSize: viewSize) else { return }
        var (tail, tip) = (start.videoPoint(of: style.start), start.videoPoint(of: style.end))
        if movingTip {
            tip = CGPoint(x: tip.x + share.width, y: tip.y + share.height)
        } else {
            tail = CGPoint(x: tail.x + share.width, y: tail.y + share.height)
        }
        selectedOverlay = start.arrow(from: tail, to: tip)
    }

    /// Where a new overlay goes at the playhead. It's asked for ``VideoOverlay/defaultDuration`` on screen, so a part
    /// played fast or a cut after the playhead doesn't make it flash by.
    private var overlayPlacement: (lane: Int, range: Range<Double>)? {
        guard let source else { return nil }
        let time = timeMap.snapped(playheadSourceTime)
        let end = timeMap.sourceTime(atOutput: timeMap.outputTime(atSource: time) + VideoOverlay.defaultDuration)
        return project.overlays.placement(at: time, length: end - time, duration: source.duration)
    }

    private func add(_ kind: VideoOverlay.Kind, frame: CGRect) {
        guard canAddOverlay(), let placement = overlayPlacement else { return }
        let overlay = VideoOverlay(range: placement.range, lane: placement.lane, frame: frame, kind: kind)
        edit("Add Overlay") { $0.overlays.append(overlay) }
        selection = .overlay(overlay.id)
        show(overlay)
    }

    /// Shows the frame where `overlay` has faded in, unless playing, since it would otherwise be nearly invisible.
    private func show(_ overlay: VideoOverlay) {
        guard !playback.isPlaying else { return }
        let output = timeMap.outputTime(atSource: overlay.range.lowerBound)
        let end = timeMap.outputTime(atSource: overlay.range.upperBound)
        playback.seek(to: min(output + PlannedOverlay.fadeDuration, (output + end) / 2))
    }
}
