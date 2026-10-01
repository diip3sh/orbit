//
//  LoginEnvironment.swift
//  Reco
//

import Foundation

/// The environment of the user's login shell, which agents' command lines need: their `PATH`
/// (nvm, Homebrew, `~/.local/bin`), and their logins and settings (spec 0007). An app started from
/// the Dock doesn't have it.
nonisolated enum LoginEnvironment {

    /// Printed before the environment, to tell it from what the shell's startup files print.
    static let marker = "__RECO_ENV__"

    /// What the shell runs: a constant, so nothing the user types is ever part of a shell command.
    static let command = "printf '\\n\(marker)\\n'; /usr/bin/env -0"

    /// The variables printed after the marker, or `nil` when it isn't there.
    static func parse(_ output: Data) -> [String: String]? {
        let marked = Data("\n\(marker)\n".utf8)
        guard let range = output.range(of: marked) else { return nil }
        var environment: [String: String] = [:]
        for entry in output[range.upperBound...].split(separator: 0) {
            // swiftlint:disable:next optional_data_string_conversion
            let pair = String(decoding: entry, as: UTF8.self)
            guard let separator = pair.firstIndex(of: "="), separator != pair.startIndex else { continue }
            environment[String(pair[..<separator])] = String(pair[pair.index(after: separator)...])
        }
        return environment
    }

    /// The first executable called `name` on `environment`'s `PATH`.
    static func resolve(_ name: String, in environment: [String: String], isExecutable: (String) -> Bool) -> URL? {
        for directory in environment["PATH", default: ""].split(separator: ":") {
            let url = URL(filePath: String(directory)).appending(path: name)
            if isExecutable(url.path(percentEncoded: false)) {
                return url
            }
        }
        return nil
    }
}
