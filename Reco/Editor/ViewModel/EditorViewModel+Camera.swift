//
//  EditorViewModel+Camera.swift
//  Reco
//

import CoreGraphics
import Foundation

extension EditorViewModel {

    /// The camera bubble's style, for the inspector's controls. Each change is an edit; a drag is one undo step.
    var cameraStyle: CameraOverlayStyle {
        get { project.camera }
        set { edit("Camera", coalescing: true) { $0.camera = newValue } }
    }

    /// The canvas and the video's place on it at the preview's size, or `nil` while the recording loads.
    private var cameraFrames: (canvas: CGSize, video: CGRect)? {
        videoSize.map { CanvasLayout.frames(for: $0, style: project.canvas) }
    }

    /// Snaps the bubble to a corner of the video.
    func moveCameraBubble(to corner: CameraOverlayStyle.Corner) {
        guard let cameraFrames else { return }
        cameraStyle.center = CameraBubbleLayout.center(of: corner, size: project.camera.size, in: cameraFrames.video.size)
    }

    /// Where a drag can grab the bubble in the stage's view, or `nil` when none shows. The size at rest, also while a
    /// zoom shrinks it.
    func cameraBubbleRect(inViewOf viewSize: CGSize) -> CGRect? {
        guard source?.camera != nil, project.camera.isEnabled, let cameraFrames else { return nil }
        let rect = CameraBubbleLayout.rect(of: project.camera, in: cameraFrames.video)
        return CameraBubbleLayout.viewRect(of: rect, canvas: cameraFrames.canvas, viewSize: viewSize)
    }

    /// Moves the bubble `translation` points in the stage's view from where it was at `start`.
    func dragCameraBubble(from start: CGPoint, by translation: CGSize, viewSize: CGSize) {
        guard let cameraFrames else { return }
        let video = cameraFrames.video.size
        let share = CameraBubbleLayout.videoShare(of: translation, viewSize: viewSize, canvas: cameraFrames.canvas, videoSize: video)
        cameraStyle.center = CameraBubbleLayout.clamped(CGPoint(x: start.x + share.width, y: start.y + share.height), size: project.camera.size, in: video)
    }

    /// Hides the footage. The file stays, so it can come back with Restore or undo.
    func removeCameraFootage() {
        cameraStyle.isEnabled = false
    }

    /// Makes a copy of the video at `url` the recording's footage, starting with the recording, saving pending edits
    /// first, and reopens it where it was. A file that can't be used shows its reason and changes nothing.
    func addCameraFootage(from url: URL) async {
        guard source != nil else { return }
        playback.pause()
        let playhead = playheadSourceTime
        await flushSave()
        do {
            try await CameraFootageStore.install(url, for: videoURL)
        } catch {
            fail(.cameraFootageNotAdded(error))
            return
        }
        await load(reloadingAt: playhead)
        edit("Add Camera Footage") {
            $0.camera.isEnabled = true
            $0.camera.timeOffset = 0
        }
    }
}
