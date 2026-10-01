//
//  LineBuffer.swift
//  Reco
//

import Foundation

/// Splits a byte stream into lines, as MCP's stdio framing is one JSON message per line.
nonisolated struct LineBuffer: Sendable {
    private var pending = Data()

    /// Adds `data` and returns the lines it completed, without their line ends and without empty
    /// lines. A partial last line waits for the next call.
    mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var lines: [Data] = []
        while let end = pending.firstIndex(of: UInt8(ascii: "\n")) {
            var line = pending[pending.startIndex..<end]
            pending = Data(pending[(end + 1)...])
            if line.last == UInt8(ascii: "\r") {
                line = line.dropLast()
            }
            if !line.isEmpty {
                lines.append(Data(line))
            }
        }
        return lines
    }
}
