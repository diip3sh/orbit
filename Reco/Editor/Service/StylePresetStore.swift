//
//  StylePresetStore.swift
//  Reco
//

import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A saved style, `.recostyle`: JSON, declared in `Info.plist` so Finder opens one in Orbit.
    static let recoStyle = UTType(exportedAs: "com.diip3sh.reco.style", conformingTo: .json)
}

/// Keeps the saved styles in Reco's Application Support folder, one `.recostyle` file each, named by the style.
nonisolated enum StylePresetStore {

    static let defaultFolder = URL.recoSupport.appending(path: "Styles")

    /// The file a style named `name` is kept in: the name, with the characters a file name can't hold replaced.
    static func fileName(for name: String) -> String {
        name.replacing(/[\/:]/, with: "-") + "." + StylePreset.fileExtension
    }

    static func url(of preset: StylePreset, in folder: URL = defaultFolder) -> URL {
        folder.appending(path: fileName(for: preset.name))
    }

    /// Every readable style in `folder`, by name.
    static func list(in folder: URL = defaultFolder) -> [StylePreset] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == StylePreset.fileExtension }
            .compactMap { try? read(from: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The style in the file at `url`, which may be one the user picked or dropped.
    static func read(from url: URL) throws -> StylePreset {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try JSONDecoder().decode(StylePreset.self, from: Data(contentsOf: url))
    }

    /// Writes `preset` into `folder`, replacing a style of the same name.
    @discardableResult
    static func save(_ preset: StylePreset, in folder: URL = defaultFolder) throws -> URL {
        let url = url(of: preset, in: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preset).write(to: url, options: .atomic)
        return url
    }

    static func delete(_ preset: StylePreset, in folder: URL = defaultFolder) throws {
        try FileManager.default.removeItem(at: url(of: preset, in: folder))
    }
}
