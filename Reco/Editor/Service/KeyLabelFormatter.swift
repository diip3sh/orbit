//
//  KeyLabelFormatter.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Carbon.HIToolbox
import Foundation

/// Turns recorded key presses into labels such as "⇧⌘K", with a keyboard layout's characters.
///
/// The telemetry stores key codes, not characters, so labels follow the layout of the Mac that
/// edits the recording.
nonisolated struct KeyLabelFormatter: Sendable {

    /// The layout's `UCKeyboardLayout` data.
    private let layout: Data

    /// Names of keys without a character to show. All but Space count as special keys, which are
    /// shown even when pressed without a modifier.
    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "⏎", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓",
        kVK_UpArrow: "↑", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    /// Modifiers as ``InputTelemetry/modifierNames(_:)`` names them, in the order macOS shows them.
    private static let modifierGlyphs: [(name: String, glyph: String)] = [
        ("control", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("command", "⌘")
    ]

    /// Modifiers that make a key press a shortcut rather than typing.
    private static let shortcutModifiers: Set = ["control", "option", "command"]

    /// The keyboard layout in use. Text Input Sources are only read on the main thread.
    @MainActor
    static func current() -> KeyLabelFormatter? {
        TISCopyCurrentKeyboardLayoutInputSource().flatMap { KeyLabelFormatter($0.takeRetainedValue()) }
    }

    /// An installed layout by its input source ID, e.g. `com.apple.keylayout.US`.
    @MainActor
    static func layout(id: String) -> KeyLabelFormatter? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return sources?.first.flatMap(KeyLabelFormatter.init)
    }

    private init?(_ source: TISInputSource) {
        guard let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        layout = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue() as Data
    }

    /// The label for a key press, or `nil` when it isn't shown.
    ///
    /// Shortcuts (keys pressed with ⌘, ⌃ or ⌥) and special keys show their modifiers and the key's
    /// unshifted character, uppercased: "⇧⌘K". Typing shows only with `showsAllKeys`, as the
    /// character typed: "k", or "K" with Shift.
    func label(for key: InputTelemetry.Key, showsAllKeys: Bool) -> String? {
        let modifiers = Set(key.modifiers)
        let name = Self.keyNames[key.keyCode]
        let isSpecial = name != nil && key.keyCode != kVK_Space
        guard isSpecial || !modifiers.isDisjoint(with: Self.shortcutModifiers) else {
            guard showsAllKeys else { return nil }
            return name ?? character(for: key.keyCode, shift: modifiers.contains("shift"))
        }

        guard let keyLabel = name ?? character(for: key.keyCode, shift: false)?.uppercased() else { return nil }
        return Self.modifierGlyphs.filter { modifiers.contains($0.name) }.map(\.glyph).joined() + keyLabel
    }

    /// The character `keyCode` types in this layout, or `nil` for a key that types none.
    private func character(for keyCode: Int, shift: Bool) -> String? {
        layout.withUnsafeBytes { bytes -> String? in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            let maxLength = 4
            var characters = [UniChar](repeating: 0, count: maxLength)
            var length = 0
            var deadKeyState: UInt32 = 0
            let status = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), shift ? UInt32(shiftKey >> 8) : 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, maxLength, &length, &characters
            )
            let string = String(decoding: characters.prefix(length), as: UTF16.self)
            let isPrintable = !string.isEmpty && !string.unicodeScalars.contains { $0.properties.generalCategory == .control }
            return status == noErr && isPrintable ? string : nil
        }
    }
}
