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

    /// Image pixels per CSS pixel. 8× is what the plan's largest image asks for on a 4K canvas
    /// (``MotionPlan/maximumRasterScale`` 4× with about two canvas pixels per CSS pixel): linear.app's
    /// 1320×720 frame lifts to 10560×5760 px, still inside Metal's 16,384 px.
    static let scales = 1...8

    /// An asset's lift: its file, scale, and the element's size in CSS pixels.
    struct Lift: Equatable, Sendable {
        let url: URL
        let scale: Int
        let size: CGSize
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
    /// layers a progressive blur is made of (``UILiftScript/isolate``).
    static let liftVersion = 2

    private static func key(of asset: MotionAsset) -> String {
        var source = "\(asset.url.absoluteString)\n\(asset.selector)\n\(Int(asset.viewport.width))x\(Int(asset.viewport.height))"
        if asset.steps == nil {
            source += "\nlift \(liftVersion)"
        }
        if let hide = asset.hide {
            source += "\n\(hide.joined(separator: "\n"))"
        }
        if let steps = asset.steps {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let encoded = (try? encoder.encode(steps)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
            source += "\n\(encoded)\n\(asset.duration ?? 0)"
        }
        return SHA256.hash(data: Data(source.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// The sharpest lift of `asset` in `bundle`, if it was ever lifted.
    static func best(_ asset: MotionAsset, in bundle: URL) -> Lift? {
        for scale in scales.reversed() {
            let url = url(of: asset, scale: scale, in: bundle)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { continue }
            return Lift(url: url, scale: scale, size: CGSize(width: Double(width) / Double(scale), height: Double(height) / Double(scale)))
        }
        return nil
    }
}
