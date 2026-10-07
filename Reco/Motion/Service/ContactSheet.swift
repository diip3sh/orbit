//
//  ContactSheet.swift
//  Reco
//

import AVFoundation
import CoreGraphics

/// A frame of each beat of a motion video on one picture, for an agent to look at what it made
/// (`preview_motion`): each scene once its layers have come in, at most ``maximumFrames``.
enum ContactSheet {

    /// A frame of the sheet: which scene, and when in the video.
    nonisolated struct Moment: Equatable, Sendable {
        let scene: String
        let time: Double
    }

    nonisolated static let maximumFrames = 12
    nonisolated static let columns = 3

    /// A frame's shorter side: 3 columns of 480×270 make a 1440 px wide sheet, under the 1568 px
    /// a model's image input is scaled down to.
    static let frameShorterSide: CGFloat = 270

    nonisolated static let gap = 8

    /// Each scene's moment: 0.2 s after its last entrance ends, or 40% in when they end sooner, and
    /// a frame before it ends at the latest. More scenes than fit are picked evenly.
    nonisolated static func moments(in summary: MotionSummary) -> [Moment] {
        let moments = summary.scenes.map { scene in
            let entrances = scene.layers.flatMap(Self.moves).filter { $0.move.kind != .exit }.map(\.ends)
            let settled = max((entrances.max() ?? 0) + 0.2, 0.4 * scene.duration)
            return Moment(scene: scene.id, time: scene.start + min(settled, scene.duration - 1 / Double(summary.frameRate)))
        }
        guard moments.count > maximumFrames else { return moments }
        return (0..<maximumFrames).map { moments[$0 * (moments.count - 1) / (maximumFrames - 1)] }
    }

    nonisolated private static func moves(of layer: MotionSummary.Layer) -> [MotionSummary.Move] {
        layer.moves + (layer.layers ?? []).flatMap(moves)
    }

    /// The frames at `moments`, drawn as an export draws them, `frameShorterSide` tall.
    static func frames(of document: MotionDocument, bundle: URL, at moments: [Moment]) async throws -> [CGImage] {
        let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: frameShorterSide)
        let composition = try await MotionCompositionBuilder.composition(for: plan)
        var frames: [CGImage] = []
        for moment in moments {
            frames.append(try await ExportService.frame(of: composition, at: CMTime(seconds: moment.time, preferredTimescale: 600)))
        }
        return frames
    }

    /// `frames` in rows of ``columns``, `gap` apart on a mid grey that no frame's own background is.
    nonisolated static func sheet(of frames: [CGImage]) -> CGImage? {
        guard let first = frames.first else { return nil }
        let (width, height) = (first.width, first.height)
        let columns = min(Self.columns, frames.count)
        let rows = (frames.count + columns - 1) / columns
        let size = CGSize(width: columns * width + (columns - 1) * gap, height: rows * height + (rows - 1) * gap)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 0.35, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        for (index, frame) in frames.enumerated() {
            let (row, column) = (index / columns, index % columns)
            // Rows from the top; Core Graphics counts from the bottom
            let top = Int(size.height) - (row + 1) * height - row * gap
            context.draw(frame, in: CGRect(x: column * (width + gap), y: top, width: width, height: height))
        }
        return context.makeImage()
    }
}
