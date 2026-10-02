//
//  USKeyCodes.swift
//  Reco
//

/// The key that types a character on a US keyboard, for a web take's telemetry: its keys are
/// scripted text, so no keyboard was pressed to read codes from.
nonisolated enum USKeyCodes {

    /// The virtual key code and whether Shift is held, or `nil` for a character a US keyboard has
    /// no key for.
    static func key(for character: Character) -> (keyCode: Int, shift: Bool)? {
        if let code = plain[character] {
            return (code, false)
        }
        if let code = plain[Character(character.lowercased())], character.isUppercase {
            return (code, true)
        }
        return shifted[character].flatMap { plain[$0] }.map { ($0, true) }
    }

    private static let plain: [Character: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "\n": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "\t": 48, " ": 49, "`": 50
    ]

    /// Each character typed with Shift, and the key's character without.
    private static let shifted: [Character: Character] = [
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", "_": "-", "+": "=",
        "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`"
    ]
}
