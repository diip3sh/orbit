//
//  LoginEnvironmentTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct LoginEnvironmentTests {

    private func output(_ text: String) -> Data {
        Data(text.utf8)
    }

    @Test func readsWhatFollowsTheMarkerAndIgnoresTheShellsNoise() throws {
        let data = output("Last login: today\nnvm is loading\n\n__RECO_ENV__\nPATH=/a:/b\0HOME=/Users/x\0")

        let environment = try #require(LoginEnvironment.parse(data))

        #expect(environment == ["PATH": "/a:/b", "HOME": "/Users/x"])
    }

    @Test func aValueMayHoldEqualsSignsAndNewlines() throws {
        let data = output("\n__RECO_ENV__\nTOKEN=a=b==\0MULTI=one\ntwo\0EMPTY=\0")

        let environment = try #require(LoginEnvironment.parse(data))

        #expect(environment == ["TOKEN": "a=b==", "MULTI": "one\ntwo", "EMPTY": ""])
    }

    @Test func entriesWithoutAKeyAreSkippedAndNoMarkerMeansNoEnvironment() throws {
        let environment = try #require(LoginEnvironment.parse(output("\n__RECO_ENV__\n=x\0noequals\0A=1\0")))

        #expect(environment == ["A": "1"])
        #expect(LoginEnvironment.parse(output("PATH=/a\0")) == nil)
    }

    @Test func theCommandIsAConstantThatPrintsTheMarker() {
        #expect(LoginEnvironment.command == "printf '\\n__RECO_ENV__\\n'; /usr/bin/env -0")
    }

    @Test func resolveTakesTheFirstExecutableOnPathInOrder() throws {
        let environment = ["PATH": "/first::/second:/third"]
        let executables: Set<String> = ["/second/claude", "/third/claude"]

        let url = LoginEnvironment.resolve("claude", in: environment) { executables.contains($0) }

        #expect(try #require(url).path(percentEncoded: false) == "/second/claude")
    }

    @Test func resolveSkipsNonExecutablesAndFindsNothingWithoutAPath() {
        #expect(LoginEnvironment.resolve("claude", in: ["PATH": "/a:/b"]) { _ in false } == nil)
        #expect(LoginEnvironment.resolve("claude", in: [:]) { _ in true } == nil)
    }
}
