//
//  TypingStretchesTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import Testing
@testable import Reco

struct TypingStretchesTests {

    /// A press every `interval` seconds from `start` to `end`, both included.
    private func typing(from start: Double, to end: Double, every interval: Double = 0.5) -> [InputTelemetry.Key] {
        stride(from: start, through: end, by: interval).map { InputTelemetry.Key(time: $0, keyCode: 0, modifiers: [], isRepeat: false) }
    }

    @Test func findsTypingOfThreeSecondsOrMore() {
        #expect(TypingStretches.speedUps(for: typing(from: 1, to: 5)) == [SpeedRange(range: 1..<5, rate: 2)])
        #expect(TypingStretches.speedUps(for: typing(from: 1, to: 3.5)).isEmpty)
    }

    @Test func aPauseOfASecondEndsAStretch() {
        let keys = typing(from: 0, to: 4) + typing(from: 5, to: 9)

        #expect(TypingStretches.speedUps(for: keys).map(\.range) == [0..<4, 5..<9])
    }

    @Test func aShortcutEndsAStretchAndRepeatsAreIgnored() {
        var keys = typing(from: 0, to: 4) + typing(from: 4.5, to: 8)
        keys.insert(InputTelemetry.Key(time: 4.2, keyCode: 1, modifiers: ["shift", "command"], isRepeat: false), at: 9)
        keys.append(InputTelemetry.Key(time: 8.4, keyCode: 0, modifiers: [], isRepeat: true))
        keys.append(InputTelemetry.Key(time: 8.8, keyCode: 0, modifiers: [], isRepeat: true))

        #expect(TypingStretches.speedUps(for: keys).map(\.range) == [0..<4, 4.5..<8])
    }

    @Test func shiftIsTyping() {
        let keys = typing(from: 0, to: 4).map { InputTelemetry.Key(time: $0.time, keyCode: 0, modifiers: ["shift"], isRepeat: false) }

        #expect(TypingStretches.speedUps(for: keys).count == 1)
    }

    @Test func longerStretchesPlayFaster() {
        #expect(TypingStretches.speedUps(for: typing(from: 0, to: 7)).map(\.rate) == [3])
        #expect([3, 5.9, 6, 11.9, 12, 60].map(TypingStretches.rate(forDuration:)) == [2, 2, 3, 3, 4, 4])
    }
}
