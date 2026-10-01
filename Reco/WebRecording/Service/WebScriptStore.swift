//
//  WebScriptStore.swift
//  Reco
//

import Foundation

/// Keeps the last web script in Reco's Application Support folder, so the Web Recording window reopens with it.
nonisolated enum WebScriptStore {

    static let defaultURL = URL.recoSupport.appending(path: "WebScript.json")

    /// The saved script, or `nil` when there is none or it can't be read.
    static func read(from url: URL = defaultURL) -> WebScript? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WebScript.self, from: data)
    }

    static func write(_ script: WebScript, to url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(script).write(to: url, options: .atomic)
    }
}
