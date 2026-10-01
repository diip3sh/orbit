//
//  AgentTOMLConfig.swift
//  Reco
//

import Foundation

/// Adds Reco's `[mcp_servers.reco]` table to an agent's TOML settings (Codex, Grok Build), and takes
/// it out again, leaving every other line as it is.
///
/// ponytail: line-based editing. It is safe for our own table, which Reco writes in one shape, and
/// it refuses other ways of spelling a `reco` server (dotted keys, inline tables) rather than guess.
/// A header-like line inside a multi-line array can fool it. A real TOML parser is the upgrade path.
nonisolated enum AgentTOMLConfig {

    nonisolated enum EditError: Error, Equatable {

        /// `reco` is written in a form this editor doesn't rewrite, e.g. `mcp_servers.reco.command = "…"`.
        case unrecognisedEntry
    }

    private static let tablePrefix = "[mcp_servers.reco"

    /// The table that starts Reco, without a trailing newline.
    static func table(for command: AgentServerCommand) -> String {
        """
        [mcp_servers.reco]
        command = \(quoted(command.executable))
        args = [\(quoted(AgentBridgeClient.argument))]
        env = { \(AgentServerCommand.tokenVariable) = \(quoted(command.token)) }
        """
    }

    /// `text` as a TOML basic string.
    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{8}": result += "\\b"
            case "\u{C}": result += "\\f"
            case _ where scalar.value < 0x20 || scalar.value == 0x7F:
                let hex = String(scalar.value, radix: 16, uppercase: true)
                result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    /// `text` without Reco's table and its sub-tables, and the table's lines; `nil` when there was none.
    static func removing(_ text: String) -> (text: String, removed: String?) {
        let scan = Self.scan(text)
        return (scan.kept.joined(separator: "\n"), scan.removed.isEmpty ? nil : scan.removed.joined(separator: "\n"))
    }

    /// `text` with Reco's table: where it was, else at the end after a blank line.
    static func connecting(_ text: String?, command: AgentServerCommand) throws -> String {
        let scan = Self.scan(text ?? "")
        try refuseOtherForms(in: scan.kept)
        var lines = scan.kept
        let table = table(for: command).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let blank: [String] = [""]
        if let insertion = scan.insertion {
            lines.insert(contentsOf: insertion.blankBefore ? blank + table : table, at: insertion.index)
        } else {
            // A file with something in it ends its last line, then leaves a blank one
            if lines.last?.isEmpty == true {
                lines.removeLast()
            }
            let needsBlank = !(lines.last.map(isBlank) ?? true)
            lines += needsBlank ? blank + table : table
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// `text` without Reco's table, or `nil` when it had none.
    static func disconnecting(_ text: String) -> String? {
        let result = removing(text)
        return result.removed == nil ? nil : result.text
    }

    static func state(of text: String, expected command: AgentServerCommand) -> AgentConnectionState {
        guard let removed = removing(text).removed else { return .notConnected }
        return removed.trimmingCharacters(in: .whitespacesAndNewlines) == table(for: command) ? .connected : .outdated
    }

    // MARK: - Scanning

    private struct Scan {
        var kept: [String] = []
        var removed: [String] = []

        /// Where Reco's first table was in `kept`, and whether a blank line before it was dropped.
        var insertion: (index: Int, blankBefore: Bool)?
    }

    private static func scan(_ text: String) -> Scan {
        var scan = Scan()
        var inBlock = false
        // Blank and comment lines after our table's last line: the next table's, so they stay
        var trailing: [String] = []
        for substring in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(substring)
            if let header = header(of: line) {
                if header == "[mcp_servers.reco]" || header.hasPrefix(tablePrefix + ".") {
                    if inBlock {
                        scan.removed += trailing
                        trailing = []
                    } else {
                        inBlock = true
                        var blankBefore = false
                        if let last = scan.kept.last, isBlank(last) {
                            scan.kept.removeLast()
                            blankBefore = true
                        }
                        scan.insertion = scan.insertion ?? (scan.kept.count, blankBefore)
                    }
                    scan.removed.append(line)
                } else {
                    scan.kept += trailing
                    trailing = []
                    inBlock = false
                    scan.kept.append(line)
                }
            } else if !inBlock {
                scan.kept.append(line)
            } else if isBlank(line) || line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                trailing.append(line)
            } else {
                scan.removed += trailing
                trailing = []
                scan.removed.append(line)
            }
        }
        scan.kept += trailing
        return scan
    }

    /// The table a line starts, without spaces and quotes, or `nil` for any other line.
    private static func header(of line: String) -> String? {
        var text = Substring(line)
        if let comment = text.firstIndex(of: "#") {
            text = text[..<comment]
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
        return stripped(trimmed)
    }

    private static func stripped(_ text: String) -> String {
        text.filter { !$0.isWhitespace && $0 != "\"" && $0 != "'" }
    }

    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }

    /// Throws when `lines` still declare a `reco` server in a way the scan doesn't remove.
    private static func refuseOtherForms(in lines: [String]) throws {
        var table: String?
        for line in lines {
            if let header = header(of: line) {
                table = header
                continue
            }
            let key = stripped(line)
            let dotted = key.hasPrefix("mcp_servers.reco") && ".=".contains(key.dropFirst("mcp_servers.reco".count).first ?? " ")
            let inline = key.hasPrefix("mcp_servers=") && key.contains("reco=")
            let inTable = table == "[mcp_servers]" && (key.hasPrefix("reco=") || key.hasPrefix("reco."))
            if dotted || inline || inTable {
                throw EditError.unrecognisedEntry
            }
        }
    }
}
