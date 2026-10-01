//
//  AgentTokenTests.swift
//  RecoTests
//

import Testing
@testable import Reco

struct AgentTokenTests {

    @Test func aTokenIs64LowercaseHexCharacters() {
        let token = AgentToken.generate()

        #expect(token.count == 64)
        #expect(token.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test func twoTokensDiffer() {
        let first = AgentToken.generate()
        let second = AgentToken.generate()

        #expect(first != second)
    }

    @Test func onlyTheSameTokenMatches() {
        let token = AgentToken.generate()

        #expect(AgentToken.matches(token, token))
        #expect(AgentToken.matches(Substring(token), token))
        #expect(!AgentToken.matches(token.dropLast(), token))
        #expect(!AgentToken.matches(token + "0", token))
        #expect(!AgentToken.matches("", token))
        #expect(!AgentToken.matches(token.uppercased(), token))
        #expect(!AgentToken.matches(String(token.dropLast()) + "g", token))
    }
}
