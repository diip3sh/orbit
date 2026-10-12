//
//  FontCapture.swift
//  Reco
//

import CoreText
import Foundation
import OSLog

/// Downloads the brand's font files a document names into its bundle (spec 0019), once: what's there isn't fetched again.
nonisolated enum FontCapture {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "FontCapture")

    /// A browser's: some font hosts refuse other clients.
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    /// Fetches each of `fonts` the bundle lacks. A file that fails, or isn't a font, is logged and left out: its text is set in
    /// the system's face.
    static func fetch(_ fonts: [MotionFont], into bundle: URL) async {
        for font in fonts {
            let file = BrandFonts.file(for: font, in: bundle)
            guard !FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { continue }
            do {
                var request = URLRequest(url: font.url, timeoutInterval: 20)
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                let fine = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? true
                guard fine, !(CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor] ?? []).isEmpty else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: file, options: .atomic)
            } catch {
                logger.error("Font \(font.family, privacy: .public) wasn't fetched from \(font.url, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
