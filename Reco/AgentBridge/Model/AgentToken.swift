//
//  AgentToken.swift
//  Reco
//

import Foundation

/// The secret that lets an agent's `--mcp` process talk to the app's socket. Anything that can read
/// the agent's settings has it; the socket's folder is also the user's own.
nonisolated enum AgentToken {

    /// 256 random bits as 64 lowercase hex characters, a nibble each, from the system's secure
    /// generator.
    static func generate() -> String {
        (0..<64).map { _ in String(UInt8.random(in: 0..<16), radix: 16) }.joined()
    }

    /// Whether `presented` is `expected`, taking as long for any wrong value of the same length.
    static func matches(_ presented: some StringProtocol, _ expected: String) -> Bool {
        let left = Array(presented.utf8)
        let right = Array(expected.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for (leftByte, rightByte) in zip(left, right) {
            difference |= leftByte ^ rightByte
        }
        return difference == 0
    }
}
