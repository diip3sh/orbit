//
//  PlannedOverlay.swift
//  Reco
//

import CoreGraphics
import CoreImage
import OSLog

/// An overlay ready to draw: its image drawn once, at the size it shows on the canvas, placed there when the render plan
/// is built.
nonisolated struct PlannedOverlay: Sendable {

    /// When it shows, in source seconds.
    let range: Range<Double>

    /// Where that is in the output.
    let output: Range<Double>

    /// In the plan's encoding, on the canvas in Core Image pixels.
    let image: CIImage

    /// Output seconds of the fade in and of the fade out, at most half of what shows. On the output, like a keystroke
    /// chip's, so it takes as long on screen at any speed. Nothing fades at a cut inside an overlay: it stays on.
    static let fadeDuration = 0.2

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "PlannedOverlay")

    /// `overlays` that aren't entirely cut, drawn side by side since a plan is rebuilt on every edit: one sorted list per
    /// used lane, lowest lane first. A picture that can't be read is left out; the inspector says so.
    static func planned(_ overlays: [VideoOverlay], timeMap: TimeMap, videoFrame: CGRect, dynamicRange: DynamicRange) async -> [[PlannedOverlay]] {
        guard !overlays.isEmpty else { return [] }
        let lanes = await withTaskGroup(of: (lane: Int, overlay: PlannedOverlay)?.self) { group in
            for overlay in overlays {
                let output = timeMap.outputTime(atSource: overlay.range.lowerBound)..<timeMap.outputTime(atSource: overlay.range.upperBound)
                guard !output.isEmpty else { continue }
                group.addTask {
                    guard let image = await image(of: overlay, videoFrame: videoFrame) else {
                        logger.error("Left out an overlay: its picture can't be read")
                        return nil
                    }
                    return (overlay.lane, PlannedOverlay(range: overlay.range, output: output, image: OverlayImages.encoded(image, in: dynamicRange)))
                }
            }
            var lanes: [Int: [PlannedOverlay]] = [:]
            for await drawn in group {
                if let drawn {
                    lanes[drawn.lane, default: []].append(drawn.overlay)
                }
            }
            return lanes
        }
        return lanes.keys.sorted().compactMap { lanes[$0]?.sorted { $0.range.lowerBound < $1.range.lowerBound } }
    }

    /// `overlay`'s frame on a canvas with the video at `videoFrame`, on whole pixels, at least one each way.
    static func rect(of frame: CGRect, in videoFrame: CGRect) -> CGRect {
        let left = (videoFrame.minX + frame.minX * videoFrame.width).rounded()
        let top = (videoFrame.maxY - frame.minY * videoFrame.height).rounded()
        let width = max((frame.width * videoFrame.width).rounded(), 1)
        let height = max((frame.height * videoFrame.height).rounded(), 1)
        return CGRect(x: left, y: top - height, width: width, height: height)
    }

    /// `overlay`'s image, placed on the canvas, in sRGB. `nil` for a picture that can't be read.
    private static func image(of overlay: VideoOverlay, videoFrame: CGRect) async -> CIImage? {
        let rect = rect(of: overlay.frame, in: videoFrame)
        let shorterSide = min(videoFrame.width, videoFrame.height)
        switch overlay.kind {
        case .text(let style):
            return OverlayImages.text(style, size: rect.size, shorterSide: shorterSide)
                .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
        case .arrow(let style):
            let (image, margin) = OverlayImages.arrow(style, size: rect.size, shorterSide: shorterSide)
            return image.transformed(by: CGAffineTransform(translationX: rect.minX - margin, y: rect.minY - margin))
        case .image(let bookmark):
            // Read no larger than it shows, so a large picture holds no more than its place on the canvas
            let needed = Int(max(rect.width, rect.height).rounded(.up))
            guard let picture = await BackgroundImageLoader.image(from: bookmark, maximumSize: needed)?.image else { return nil }
            let fitted = OverlayImages.fitted(picture, in: rect.size)
            return fitted.transformed(by: CGAffineTransform(
                translationX: rect.minX + ((rect.width - fitted.extent.width) / 2).rounded(),
                y: rect.minY + ((rect.height - fitted.extent.height) / 2).rounded()
            ))
        }
    }

    /// The overlay on a lane showing at source time `time`. Its parts in a cut never show, as no frame shows that time.
    /// - Parameter lane: Sorted and apart.
    static func visible(in lane: [PlannedOverlay], at time: Double) -> PlannedOverlay? {
        let next = lane.partitioningIndex { $0.range.lowerBound > time }
        guard next > 0, lane[next - 1].range.contains(time) else { return nil }
        return lane[next - 1]
    }

    /// How opaque it is at output time `time`, for a frame lasting `frameDuration`. A frame shows until the next one, so
    /// the first counts as already that far in and an overlay never starts with an empty frame.
    func opacity(atOutput time: Double, frameDuration: Double) -> Double {
        let fade = min(Self.fadeDuration, (output.upperBound - output.lowerBound) / 2)
        return max(min((time - output.lowerBound + frameDuration) / fade, (output.upperBound - time) / fade, 1), 0)
    }
}

nonisolated extension FrameRenderer {

    /// `image` (on the canvas) under the overlays showing at output time `time`, lowest lane first. Not blurred: they don't
    /// move with the zoom.
    static func overlaid(_ image: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        guard !plan.overlays.isEmpty else { return image }
        let source = plan.timeMap.sourceTime(atOutput: time)
        return plan.overlays.reduce(image) { image, lane in
            guard let overlay = PlannedOverlay.visible(in: lane, at: source) else { return image }
            let opacity = overlay.opacity(atOutput: time, frameDuration: 1 / plan.timeMap.frameRate)
            return (opacity < 1 ? overlay.image.fading(to: opacity) : overlay.image).composited(over: image)
        }
    }
}
