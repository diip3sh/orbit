//
//  EditorViewModel+Crop.swift
//  Reco
//

import CoreGraphics

extension EditorViewModel {

    /// The part of the video kept, for the inspector's crop pad. Each change is an edit; a drag is one undo step.
    var crop: CGRect {
        get { project.crop }
        set { edit("Crop", coalescing: true) { $0.crop = VideoCrop.clamped(newValue) } }
    }

    /// The video as the canvas sees it: the crop's size in pixels, or `nil` while the recording loads.
    var videoSize: CGSize? {
        source.map { VideoCrop.pixels(of: project.crop, in: $0.naturalSize).size }
    }

    /// The telemetry with every position in the crop, for automatic zooms.
    var croppedTelemetry: InputTelemetry? {
        guard let source else { return nil }
        return source.telemetry?.cropped(to: VideoCrop.pixels(of: project.crop, in: source.naturalSize))
    }

    /// Once a crop drag ends: automatic zooms aim at fractions of the crop, so they're made again for the new one,
    /// in the same undo step. Not on every drag step: generating takes ~34 ms for 10 minutes.
    func cropDidSettle() {
        guard let source, let telemetry = croppedTelemetry, project.zooms.contains(where: \.isAutomatic) else { return }
        let generated = AutoZoomGenerator.segments(for: telemetry, duration: source.duration)
        edit("Crop", coalescing: true) { $0.zooms = $0.zooms.regenerated(with: generated) }
    }

    func resetCrop() {
        crop = VideoCrop.full
        cropDidSettle()
    }

    /// The filmstrip's picture at source time `time`, cut to the crop, for pictures of what the canvas shows.
    func croppedThumbnail(at time: Double) -> CGImage? {
        guard let image = thumbnail(at: time) else { return nil }
        let crop = VideoCrop.clamped(project.crop)
        guard crop != VideoCrop.full else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        return image.cropping(to: CGRect(x: crop.minX * width, y: crop.minY * height, width: crop.width * width, height: crop.height * height).integral)
    }
}
