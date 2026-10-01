//
//  StandardCursorsTests.swift
//  RecoTests
//

import AppKit
import Testing
@testable import Reco

@MainActor
struct StandardCursorsTests {

    @Test func everyStandardCursorHasAFingerprint() {
        // 14 single cursors, 3 column resize, 3 row resize, 8 positions x 3 directions of frame resize
        #expect(StandardCursors.fingerprints.count == 44)
    }

    @Test func identicalImagesShareTheirKind() {
        // Opposite frame resize cursors are one image, e.g. top inward and bottom outward
        let fingerprints = StandardCursors.fingerprints
        for (index, entry) in fingerprints.enumerated() {
            let twins = fingerprints[(index + 1)...].filter { $0.fingerprint == entry.fingerprint }
            #expect(twins.allSatisfy { $0.kind == entry.kind })
        }
    }

    @Test func theArrowIsRecognisedFromItsImage() throws {
        let arrow = try #require(StandardCursors.fingerprint(of: .arrow))
        var tracker = CursorShapeTracker(standardCursors: StandardCursors.fingerprints)

        tracker.record(arrow, time: 0) { Data() }

        #expect(tracker.sprites.first?.kind == .arrow)
    }
}
