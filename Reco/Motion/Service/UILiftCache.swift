//
//  UILiftCache.swift
//  Reco
//

import CryptoKit
import Foundation
import ImageIO

/// Where a bundle keeps its lifted UI: `assets/lifts/<key>@<scale>x.png`, one file per scale a still
/// was lifted at, and `assets/live/<key>.mov` with its telemetry and ``TakeInfo`` for a live take.
/// The key hashes what decides the pixels (address, selector, viewport, and a take's steps), so an
/// edited asset is captured again and an unchanged one never is.
nonisolated enum UILiftCache {

    /// Image pixels per CSS pixel. 8× (``maximumScale``) is what the plan's largest image asks for on
    /// a 4K canvas (``MotionPlan/maximumRasterScale`` 4× with about two canvas pixels per CSS pixel):
    /// linear.app's 1320×720 frame lifts to 10560×5760 px, still inside Metal's 16,384 px. A small
    /// still is lifted sharper while it fits ``maximumLiftSide``: Supabase's search bar at 14×.
    static let scales = 1...32
    static let maximumScale = 8

    /// The longest side of a still lifted sharper than ``maximumScale``, in pixels.
    static let maximumLiftSide = 8192.0

    /// An asset's lift: its file, scale, and the element's size and corner radius in CSS pixels
    /// (`nil` for a lift from before radii were kept).
    struct Lift: Equatable, Sendable {
        let url: URL
        let scale: Int
        let size: CGSize
        var radius: Double?
    }

    /// What a still's lift doesn't show, written beside it: the element's corner radius in CSS pixels.
    struct Shape: Codable, Equatable, Sendable {
        var radius: Double
    }

    /// What a typing asset's lifts show (``MotionAsset/typing``), written beside them, in CSS pixels from
    /// the element's top-left corner: `<key>-typed-<length>@<scale>x.png` is the field's row with that much
    /// of the text typed, `<key>-settled-<length>@<scale>x.png` the whole element once its results settled.
    struct Typing: Codable, Equatable, Sendable {
        /// The field's row, lifted at every length.
        var row: CGRect

        /// Where the text ends at each length, from 0 (where it starts).
        var ends: [Double]

        /// The text's centre line and its font's size.
        var line: Double
        var fontSize: Double

        /// The lengths the whole element was lifted at, and its height at each.
        var settled: [Int]
        var heights: [Double]

        /// The selected result's centre line once the text is typed, then after each press of the down
        /// arrow, each lifted as `<key>-selected-<presses>@<scale>x.png`; `nil` without a selection.
        var selections: [Double]?
    }

    /// The longest side of a live take's movie: HEVC's largest.
    static let maximumMovieSide = 8192.0

    /// A live take: its movie and telemetry, and what the movie shows.
    struct Take: Sendable {
        let movie: URL
        let telemetry: InputTelemetry
        let info: TakeInfo

        /// `nil` for a take baked before mattes, cut to its corner radius instead.
        let matte: URL?
    }

    /// What a live take's movie shows, written beside it.
    struct TakeInfo: Codable, Equatable, Sendable {

        /// The element's box in the viewport when the take starts, in whole CSS pixels.
        var crop: CGRect

        /// The element's corner radius in CSS pixels.
        var radius: Double

        /// Video pixels per CSS pixel; 0 while only measured.
        var scale: Int

        /// Seconds.
        var duration: Double
    }

    static func url(of asset: MotionAsset, scale: Int, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset))@\(scale)x.png")
    }

    static func shapeURL(of asset: MotionAsset, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset)).json")
    }

    static func typingURL(of asset: MotionAsset, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset))-typing.json")
    }

    static func typedURL(of asset: MotionAsset, length: Int, scale: Int, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset))-typed-\(length)@\(scale)x.png")
    }

    static func settledURL(of asset: MotionAsset, length: Int, scale: Int, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset))-settled-\(length)@\(scale)x.png")
    }

    static func selectedURL(of asset: MotionAsset, presses: Int, scale: Int, in bundle: URL) -> URL {
        bundle.appending(path: "assets/lifts/\(key(of: asset))-selected-\(presses)@\(scale)x.png")
    }

    /// What `asset`'s typing lifts show, once they were taken.
    static func typing(_ asset: MotionAsset, in bundle: URL) -> Typing? {
        try? JSONDecoder().decode(Typing.self, from: Data(contentsOf: typingURL(of: asset, in: bundle)))
    }

    static func movieURL(of asset: MotionAsset, in bundle: URL) -> URL {
        bundle.appending(path: "assets/live/\(key(of: asset)).mov")
    }

    static func infoURL(of asset: MotionAsset, in bundle: URL) -> URL {
        movieURL(of: asset, in: bundle).deletingPathExtension().appendingPathExtension("json")
    }

    /// The element's painted shape, alone with real alpha, at the take's scale.
    static func matteURL(of asset: MotionAsset, in bundle: URL) -> URL {
        bundle.appending(path: "assets/live/\(key(of: asset))-matte.png")
    }

    /// Each of `document`'s assets' element in CSS pixels, once lifted or measured: what shots are
    /// laid out by.
    static func sizes(of document: MotionDocument, in bundle: URL) -> [String: CGSize] {
        document.assets.reduce(into: [:]) { sizes, asset in
            sizes[asset.id] = asset.steps == nil ? best(asset, in: bundle)?.size : info(asset, in: bundle)?.crop.size
            // A field typed into is as tall as its results grow
            if let size = sizes[asset.id], let tallest = typing(asset, in: bundle)?.heights.max(), tallest > size.height {
                sizes[asset.id] = CGSize(width: size.width, height: tallest)
            }
        }
    }

    /// What a live take of `asset` shows, once it was measured.
    static func info(_ asset: MotionAsset, in bundle: URL) -> TakeInfo? {
        try? JSONDecoder().decode(TakeInfo.self, from: Data(contentsOf: infoURL(of: asset, in: bundle)))
    }

    /// The live take of `asset` in `bundle`, if it was baked.
    static func take(_ asset: MotionAsset, in bundle: URL) -> Take? {
        let movie = movieURL(of: asset, in: bundle)
        guard FileManager.default.fileExists(atPath: movie.path(percentEncoded: false)),
              let info = info(asset, in: bundle), info.scale > 0,
              let telemetry = try? JSONDecoder().decode(InputTelemetry.self, from: Data(contentsOf: InputTelemetry.sidecarURL(for: movie)))
        else { return nil }
        let matte = matteURL(of: asset, in: bundle)
        return Take(movie: movie, telemetry: telemetry, info: info, matte: FileManager.default.fileExists(atPath: matte.path(percentEncoded: false)) ? matte : nil)
    }

    /// Changes when a still is lifted differently, so bundles lift theirs again: 2 hides the
    /// layers a progressive blur is made of, 3 everything inside what's hidden (``UILiftScript/isolate``),
    /// 4 fills a translucent element with the page's opaque colour (``UILiftScript/place``), 5 drops a bare
    /// element's backdrop (``UILiftScript/isolate``).
    static let liftVersion = 5

    private static func key(of asset: MotionAsset) -> String {
        var source = "\(asset.url.absoluteString)\n\(asset.selector)\n\(Int(asset.viewport.width))x\(Int(asset.viewport.height))"
        if asset.steps == nil {
            source += "\nlift \(liftVersion)"
        }
        if asset.glass == true {
            source += "\nglass"
        } else if asset.bare == true {
            source += "\nbare"
        }
        if let typing = asset.typing {
            source += "\ntyping \(typing.field)\n\(typing.text)\n\(typing.select ?? 0)"
        }
        if let before = asset.before {
            source += "\nbefore \(encoded(before))"
        }
        if let region = asset.region {
            source += "\nregion \(region.minX) \(region.minY) \(region.width) \(region.height)"
        }
        if let hide = asset.hide {
            source += "\n\(hide.joined(separator: "\n"))"
        }
        if let steps = asset.steps {
            source += "\n\(encoded(steps))\n\(asset.duration ?? 0)"
        }
        return SHA256.hash(data: Data(source.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Steps as JSON with sorted keys, the same whenever they're the same.
    private static func encoded(_ steps: [RecordPageRequest.Step]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(steps)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
    }

    /// The sharpest lift of `asset` in `bundle`, if it was ever lifted.
    static func best(_ asset: MotionAsset, in bundle: URL) -> Lift? {
        for scale in scales.reversed() {
            let url = url(of: asset, scale: scale, in: bundle)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { continue }
            let shape = try? JSONDecoder().decode(Shape.self, from: Data(contentsOf: shapeURL(of: asset, in: bundle)))
            return Lift(url: url, scale: scale, size: CGSize(width: Double(width) / Double(scale), height: Double(height) / Double(scale)), radius: shape?.radius)
        }
        return nil
    }
}
