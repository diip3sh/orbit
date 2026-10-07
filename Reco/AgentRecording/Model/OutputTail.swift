//
//  OutputTail.swift
//  Reco
//

import Foundation

/// The end of what a process printed, kept small however long it runs.
nonisolated struct OutputTail: Sendable {

    static let defaultLimit = 16 * 1024

    private(set) var data = Data()
    private let limit: Int

    init(limit: Int = defaultLimit) {
        self.limit = limit
    }

    mutating func append(_ chunk: Data) {
        data.append(chunk)
        if data.count > limit {
            data = Data(data.suffix(limit))
        }
    }

    var text: String {
        // Lossy on purpose: the cut may split a character, which must not lose the rest
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
    }

    /// A few words on why a run failed, from what the agent printed: the last lines of `stderr`, or
    /// of `stdout` when `stderr` has none. Colors are stripped, each of `secrets` is replaced by "…",
    /// and only the last 300 characters stay.
    static func reason(stdout: String, stderr: String, redacting secrets: [String] = []) -> String {
        func lines(_ text: String) -> [Substring] {
            plain(text)
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { Substring($0) }
        }
        var chosen = lines(stderr)
        if chosen.isEmpty {
            chosen = lines(stdout)
        }
        var text = chosen.suffix(5).joined(separator: " ")
        for secret in secrets where !secret.isEmpty {
            text = text.replacing(secret, with: "…")
        }
        return String(text.suffix(300))
    }

    /// `text` without the terminal's color and cursor codes.
    static func plain(_ text: String) -> String {
        text.replacing(/\e\[[0-9;?]*[ -\/]*[@-~]/, with: "")
    }
}
