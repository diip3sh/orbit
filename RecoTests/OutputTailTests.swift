//
//  OutputTailTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct OutputTailTests {

    @Test func keepsOnlyTheLastBytes() {
        var tail = OutputTail(limit: 8)

        tail.append(Data("0123456789".utf8))
        tail.append(Data("abc".utf8))

        #expect(tail.text == "56789abc")
    }

    @Test func staysUnderTheLimitHoweverMuchIsAppended() {
        var tail = OutputTail()

        for _ in 0..<100 {
            tail.append(Data(repeating: 65, count: 1_000))
        }

        #expect(tail.data.count == OutputTail.defaultLimit)
    }

    @Test func stripsColorsAndTakesTheLastFiveLines() {
        let stderr = "one\ntwo\n\u{1B}[31mthree\u{1B}[0m\n\n four \nfive\nsix\n"

        #expect(OutputTail.reason(stdout: "ignored", stderr: stderr) == "two three four five six")
    }

    @Test func usesStdoutWhenStderrHasNothing() {
        #expect(OutputTail.reason(stdout: "Not logged in\n", stderr: " \n\u{1B}[0m\n") == "Not logged in")
    }

    @Test func replacesSecretsAndSkipsEmptyOnes() {
        let reason = OutputTail.reason(stdout: "", stderr: "token abc123 rejected; abc123 again", redacting: ["abc123", ""])

        #expect(reason == "token … rejected; … again")
    }

    @Test func keepsTheEndOf300Characters() {
        let reason = OutputTail.reason(stdout: "", stderr: String(repeating: "a", count: 400) + "END")

        #expect(reason.count == 300)
        #expect(reason.hasSuffix("aaEND"))
    }
}
