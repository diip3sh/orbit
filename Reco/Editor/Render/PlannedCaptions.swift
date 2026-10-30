//
//  PlannedCaptions.swift
//  Reco
//

import CoreGraphics
import CoreImage

/// A render plan's captions: one coverage image per caption and the colors they're drawn in.
nonisolated struct PlannedCaptions: Sendable {

    /// Sorted and apart. Empty when they're off or all cut.
    var captions: [PlannedCaption] = []

    /// The colors as endless images, in the plan's encoding.
    var textColor = CIImage.empty()

    /// `nil` when words aren't highlighted.
    var highlightColor: CIImage?

    static let none = PlannedCaptions()

    /// How far a caption's box may reach across the video, as a share of its width.
    static let widthFraction = 0.9

    /// How far a box sits from the video's top or bottom edge, as a share of the video's shorter side.
    static let edgeMargin = 0.05

    /// How far a bottom caption sits from the bottom edge when keystroke chips can show. A chip's top is at 0.108 of
    /// the shorter side (``FrameRenderer`` puts it 0.8 of its height, 0.06, above the edge). Fixed for the whole
    /// recording, so captions don't jump as chips come and go.
    static let marginAboveChips = 0.125

    /// Draws `track`'s captions that aren't entirely cut, side by side, since a plan is rebuilt on every edit. 300
    /// captions at 4K, about 10 minutes' worth (Debug, load average 4), take 44 ms, against 107 ms one after the other,
    /// and hold 122 MB; RGBA images in two colors would hold 976 MB. A frame showing one costs no more than one without
    /// (2.6 ms p50 either way).
    static func planned(_ track: CaptionTrack, timeMap: TimeMap, videoFrame: CGRect, hasChips: Bool, dynamicRange: DynamicRange) async -> PlannedCaptions {
        guard track.isEnabled else { return .none }
        let cues = track.cues.filter { cue in
            !cue.text.isEmpty && timeMap.keptRanges.contains { $0.overlaps(cue.range) }
        }
        guard !cues.isEmpty else { return .none }
        let style = track.style
        let shorterSide = min(videoFrame.width, videoFrame.height)
        let captions = await withTaskGroup(of: (Int, PlannedCaption).self) { group in
            for (index, cue) in cues.enumerated() {
                group.addTask { (index, caption(for: cue, style: style, videoFrame: videoFrame, shorterSide: shorterSide, hasChips: hasChips)) }
            }
            var drawn: [(Int, PlannedCaption)] = []
            for await caption in group {
                drawn.append(caption)
            }
            return drawn.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return PlannedCaptions(
            captions: captions,
            textColor: OverlayImages.encoded(OverlayImages.solid(style.textColor.cgColor), in: dynamicRange).clampedToExtent(),
            highlightColor: style.highlightsWords
                ? OverlayImages.encoded(OverlayImages.solid(style.highlightColor.cgColor), in: dynamicRange).clampedToExtent()
                : nil
        )
    }

    /// Where a box of `size` goes on the video, in whole pixels.
    static func origin(of size: CGSize, position: CaptionStyle.Position, in videoFrame: CGRect, hasChips: Bool) -> CGPoint {
        let shorterSide = min(videoFrame.width, videoFrame.height)
        let bottom = switch position {
        case .top: videoFrame.maxY - shorterSide * edgeMargin - size.height
        case .middle: videoFrame.midY - size.height / 2
        case .bottom: videoFrame.minY + shorterSide * (hasChips ? marginAboveChips : edgeMargin)
        }
        return CGPoint(x: (videoFrame.midX - size.width / 2).rounded(), y: bottom.rounded())
    }

    private static func caption(for cue: CaptionCue, style: CaptionStyle, videoFrame: CGRect, shorterSide: CGFloat, hasChips: Bool) -> PlannedCaption {
        let layout = CaptionLayout(
            text: cue.text, words: cue.words.map(\.text), fontSize: shorterSide * style.size, maximumWidth: videoFrame.width * widthFraction
        )
        let origin = origin(of: layout.size, position: style.position, in: videoFrame, hasChips: hasChips)
        let placement = CGAffineTransform(translationX: origin.x, y: origin.y)
        return PlannedCaption(
            range: cue.range,
            mask: OverlayImages.captionMask(of: layout).transformed(by: placement),
            box: box(size: layout.size, origin: origin, opacity: style.backgroundOpacity),
            words: zip(cue.words, layout.wordRects).map { word, rect in
                PlannedCaption.Word(start: word.range.lowerBound, rect: rect.applying(placement))
            }
        )
    }

    /// A rounded box, which Core Image generates when drawn. Black, the same in every encoding.
    private static func box(size: CGSize, origin: CGPoint, opacity: Double) -> CIImage? {
        guard opacity > 0 else { return nil }
        return CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: CGRect(origin: origin, size: size)),
            "inputRadius": min(size.height / 4, 24),
            kCIInputColorKey: CIColor(red: 0, green: 0, blue: 0, alpha: opacity)
        ])?.outputImage
    }
}
