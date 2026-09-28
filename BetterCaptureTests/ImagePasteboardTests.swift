//
//  ImagePasteboardTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import Testing
@testable import BetterCapture

@MainActor
struct ImagePasteboardTests {

    @Test func copiesThePNGAndTheFileURLAsOneItem() {
        let pasteboard = NSPasteboard(name: .init("ImagePasteboardTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let url = URL(fileURLWithPath: "/tmp/example.png")

        ImagePasteboard.copy(png: png, fileURL: url, to: pasteboard)

        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(pasteboard.data(forType: .png) == png)
        #expect(pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] == [url])
    }

    @Test func replacesPreviousContents() {
        let pasteboard = NSPasteboard(name: .init("ImagePasteboardTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)

        ImagePasteboard.copy(png: Data(), fileURL: URL(fileURLWithPath: "/tmp/example.png"), to: pasteboard)

        #expect(pasteboard.string(forType: .string) == nil)
    }
}
