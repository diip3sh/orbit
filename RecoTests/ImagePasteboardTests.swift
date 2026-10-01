//
//  ImagePasteboardTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import Testing
@testable import Reco

@MainActor
struct ImagePasteboardTests {

    @Test func copiesOnlyThePNGAsOneItem() {
        let pasteboard = NSPasteboard(name: .init("ImagePasteboardTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let png = Data([0x89, 0x50, 0x4E, 0x47])

        ImagePasteboard.copy(png: png, to: pasteboard)

        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(pasteboard.data(forType: .png) == png)
        #expect(pasteboard.availableType(from: [.fileURL]) == nil)
    }

    @Test func replacesPreviousContents() {
        let pasteboard = NSPasteboard(name: .init("ImagePasteboardTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)

        ImagePasteboard.copy(png: Data(), to: pasteboard)

        #expect(pasteboard.string(forType: .string) == nil)
    }
}
