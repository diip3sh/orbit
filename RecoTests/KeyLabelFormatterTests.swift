//
//  KeyLabelFormatterTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Carbon.HIToolbox
import Testing
@testable import Reco

@MainActor
struct KeyLabelFormatterTests {

    private let formatter = KeyLabelFormatter.layout(id: "com.apple.keylayout.US")

    private func label(_ keyCode: Int, _ modifiers: [String] = [], showsAllKeys: Bool = false) throws -> String? {
        let key = InputTelemetry.Key(time: 0, keyCode: keyCode, modifiers: modifiers, isRepeat: false)
        return try #require(formatter).label(for: key, showsAllKeys: showsAllKeys)
    }

    @Test func shortcutsShowTheirModifiersInMacOSOrderAndTheKeyUppercased() throws {
        #expect(try label(kVK_ANSI_C, ["command"]) == "⌘C")
        #expect(try label(kVK_ANSI_K, ["shift", "command"]) == "⇧⌘K")
        #expect(try label(kVK_ANSI_Z, ["command", "option", "control"]) == "⌃⌥⌘Z")
        #expect(try label(kVK_Space, ["command"]) == "⌘Space")
    }

    @Test func specialKeysShowWithoutModifiers() throws {
        #expect(try label(kVK_Return) == "⏎")
        #expect(try label(kVK_Tab, ["shift"]) == "⇧⇥")
        #expect(try label(kVK_F5) == "F5")
    }

    @Test func functionAndCapsLockFlagsAreLeftOut() throws {
        // macOS sets the function flag on arrow keys
        #expect(try label(kVK_LeftArrow, ["function"]) == "←")
        #expect(try label(kVK_ANSI_Z, ["command", "capsLock"]) == "⌘Z")
    }

    @Test func typingIsHiddenUnlessAllKeysAreShown() throws {
        #expect(try label(kVK_ANSI_A) == nil)
        #expect(try label(kVK_ANSI_A, ["shift"]) == nil)
        #expect(try label(kVK_Space) == nil)

        #expect(try label(kVK_ANSI_A, showsAllKeys: true) == "a")
        #expect(try label(kVK_ANSI_A, ["shift"], showsAllKeys: true) == "A")
        #expect(try label(kVK_ANSI_1, ["shift"], showsAllKeys: true) == "!")
        #expect(try label(kVK_Space, showsAllKeys: true) == "Space")
    }
}
