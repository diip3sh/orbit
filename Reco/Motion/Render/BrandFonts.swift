//
//  BrandFonts.swift
//  Reco
//

import AppKit
import CoreText
import CryptoKit

/// The brand's own faces (spec 0019), read from a bundle's `assets/fonts` and found by the family a document names them by. Text
/// is measured wherever a layer is laid out or linted, without the bundle at hand, so a face is kept for the process once read.
/// Core Text reads WOFF2, WOFF, TrueType and OpenType files alike.
nonisolated enum BrandFonts {

    /// Where `font`'s file is kept in `bundle`.
    static func file(for font: MotionFont, in bundle: URL) -> URL {
        let key = SHA256.hash(data: Data(font.url.absoluteString.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let kind = ["woff2", "woff", "ttf", "otf"].first { $0 == font.url.pathExtension.lowercased() } ?? "font"
        return bundle.appending(path: "assets/fonts/\(key).\(kind)")
    }

    /// Reads the files of `fonts` that `bundle` has and wasn't read before.
    static func load(_ fonts: [MotionFont], bundle: URL) {
        for font in fonts {
            registry.add(file(for: font, in: bundle), as: font.family)
        }
    }

    /// `family` at `size`, in the face closest to `weight` (a variable face set to it), if it has been read.
    static func font(family: String, weight: TextContent.Weight, size: Double) -> NSFont? {
        registry.font(family, weight: weight, size: size)
    }

    private static let registry = Registry()
}

/// The faces read so far, by family; reads and lookups from any thread.
nonisolated private final class Registry: @unchecked Sendable {
    private let lock = NSLock()
    private var read: Set<String> = []
    private var faces: [String: [CTFontDescriptor]] = [:]

    func add(_ file: URL, as family: String) {
        let key = family.lowercased() + "\n" + file.path
        lock.lock()
        defer { lock.unlock() }
        guard !read.contains(key), let data = try? Data(contentsOf: file) else { return }
        read.insert(key)
        faces[family.lowercased(), default: []] += CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor] ?? []
    }

    func font(_ family: String, weight: TextContent.Weight, size: Double) -> NSFont? {
        lock.lock()
        let candidates = faces[family.lowercased()] ?? []
        lock.unlock()
        let target = Self.trait(of: weight)
        guard let face = candidates.min(by: { abs(Self.trait(of: $0) - target) < abs(Self.trait(of: $1) - target) }) else { return nil }
        let font = CTFontCreateWithFontDescriptor(face, size, nil)
        let axes = CTFontCopyVariationAxes(font) as? [[CFString: Any]] ?? []
        guard axes.contains(where: { ($0[kCTFontVariationAxisIdentifierKey] as? Int) == Self.weightAxis }) else { return font as NSFont }
        // A variable face takes the weight on its axis
        let set = CTFontDescriptorCreateCopyWithVariation(face, Self.weightAxis as CFNumber, Self.cssWeight(of: weight))
        return CTFontCreateWithFontDescriptor(set, size, nil) as NSFont
    }

    /// 'wght'.
    private static let weightAxis = 0x7767_6874

    private static func trait(of face: CTFontDescriptor) -> Double {
        let traits = CTFontDescriptorCopyAttribute(face, kCTFontTraitsAttribute) as? [CFString: Any]
        return traits?[kCTFontWeightTrait] as? Double ?? 0
    }

    private static func trait(of weight: TextContent.Weight) -> Double {
        switch weight {
        case .regular: NSFont.Weight.regular.rawValue
        case .medium: NSFont.Weight.medium.rawValue
        case .semibold: NSFont.Weight.semibold.rawValue
        case .bold: NSFont.Weight.bold.rawValue
        }
    }

    private static func cssWeight(of weight: TextContent.Weight) -> Double {
        switch weight {
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        }
    }
}
