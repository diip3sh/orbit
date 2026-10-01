//
//  InputTelemetryDecodingTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct InputTelemetryDecodingTests {

    @Test func decodesAVersion2FileWithoutCursorData() throws {
        let telemetry = try JSONDecoder().decode(InputTelemetry.self, from: Fixture.data("telemetry-v2"))

        #expect(telemetry.version == 2)
        #expect(telemetry.capture.cursorInVideo)
        #expect(telemetry.geometry.count == 1)
        #expect(telemetry.cursor.count == 2)
        #expect(telemetry.clicks.map(\.isDown) == [true, false])
        #expect(telemetry.scrolls.first?.delta == CGVector(dx: 0, dy: -4))
        #expect(telemetry.keys.first?.modifiers == ["command"])
        #expect(telemetry.cursorSprites.isEmpty)
        #expect(telemetry.cursorShapes.isEmpty)
    }

    @Test func decodesAVersion3FileWithCursorData() throws {
        let telemetry = try JSONDecoder().decode(InputTelemetry.self, from: Fixture.data("telemetry-v3"))

        #expect(telemetry.version == 3)
        #expect(telemetry.capture.kind == .window)
        #expect(!telemetry.capture.cursorInVideo)
        #expect(telemetry.geometry.first?.boundingRect == CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(telemetry.cursorSprites.map(\.kind) == [.arrow, .iBeam])
        #expect(telemetry.cursorShapes.map(\.sprite) == [0, 1])
    }

    @Test(arguments: [1, 4])
    func rejectsUnsupportedVersions(version: Int) {
        let json = """
        {
          "version": \(version), "keystrokesAvailable": false,
          "capture": { "kind": "display", "videoSize": [100, 100] },
          "geometry": [], "cursor": [], "clicks": [], "scrolls": [], "keys": []
        }
        """

        #expect(throws: UnsupportedVersionError(version: version)) {
            try JSONDecoder().decode(InputTelemetry.self, from: Data(json.utf8))
        }
    }
}
