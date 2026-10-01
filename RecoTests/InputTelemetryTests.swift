//
//  InputTelemetryTests.swift
//  RecoTests
//
//  Created by Diip3sh on 25.09.26.
//

import CoreGraphics
import Foundation
import ScreenCaptureKit
import Testing
@testable import Reco

struct InputTelemetryTests {

    private let capture = InputTelemetry.Capture(kind: .area, videoSize: CGSize(width: 1600, height: 1200))

    private let geometry = InputTelemetry.Geometry(
        time: 1,
        screenRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
        contentRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
        boundingRect: nil,
        contentScale: 1,
        scaleFactor: 2
    )

    // MARK: - videoTime

    @Test func videoTimeIsMeasuredFromTheAnchor() {
        #expect(InputTelemetry.videoTime(hostTime: 103.5, anchor: 100, duration: 10) == 3.5)
    }

    @Test func videoTimeDropsEventsBeforeTheAnchorOrAfterTheEnd() {
        #expect(InputTelemetry.videoTime(hostTime: 99.5, anchor: 100, duration: 10) == nil)
        #expect(InputTelemetry.videoTime(hostTime: 110.5, anchor: 100, duration: 10) == nil)
    }

    // MARK: - rebased

    @Test func rebasedMovesEventsOntoTheVideoTimeline() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: true)
        telemetry.clicks = [
            .init(time: 98, location: .zero, button: .left, isDown: true, clickCount: 1),
            .init(time: 102, location: .zero, button: .left, isDown: false, clickCount: 1)
        ]
        telemetry.scrolls = [.init(time: 105, location: .zero, delta: CGVector(dx: 0, dy: -3))]
        telemetry.keys = [.init(time: 111, keyCode: 8, modifiers: ["command"], isRepeat: false)]

        let rebased = telemetry.rebased(anchor: 100, duration: 10)

        #expect(rebased.clicks.map(\.time) == [2])
        #expect(rebased.scrolls.map(\.time) == [5])
        #expect(rebased.keys.isEmpty)
    }

    @Test func rebasedPinsTheLastCursorPositionBeforeTheAnchorToZero() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        telemetry.cursor = [
            .init(time: 99, location: CGPoint(x: 1, y: 1)),
            .init(time: 99.5, location: CGPoint(x: 2, y: 2)),
            .init(time: 101, location: CGPoint(x: 3, y: 3))
        ]

        let rebased = telemetry.rebased(anchor: 100, duration: 10)

        #expect(rebased.cursor == [
            .init(time: 0, location: CGPoint(x: 2, y: 2)),
            .init(time: 1, location: CGPoint(x: 3, y: 3))
        ])
    }

    @Test func rebasedPinsTheLastGeometryBeforeTheAnchorToZero() {
        var moved = geometry
        moved.time = 104
        moved.screenRect.origin.x = 10
        var early = geometry
        early.time = 99
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        telemetry.geometry = [early, moved]

        let rebased = telemetry.rebased(anchor: 100, duration: 10)

        #expect(rebased.geometry.map(\.time) == [0, 4])
        #expect(rebased.geometry.map(\.screenRect.minX) == [0, 10])
    }

    @Test func rebasedPinsTheLastCursorShapeBeforeTheAnchorToZero() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        telemetry.cursorShapes = [.init(time: 99, sprite: 0), .init(time: 103, sprite: 1), .init(time: 111, sprite: 0)]

        let rebased = telemetry.rebased(anchor: 100, duration: 10)

        #expect(rebased.cursorShapes == [.init(time: 0, sprite: 0), .init(time: 3, sprite: 1)])
    }

    // MARK: - Pauses

    @Test func videoTimeCutsPausedTime() {
        let pauses = [102.0..<105.0, 107.0..<Double.infinity]
        #expect(InputTelemetry.videoTime(hostTime: 101, anchor: 100, duration: 10, pauses: pauses) == 1)
        #expect(InputTelemetry.videoTime(hostTime: 103, anchor: 100, duration: 10, pauses: pauses) == nil)
        #expect(InputTelemetry.videoTime(hostTime: 106, anchor: 100, duration: 10, pauses: pauses) == 3)
        #expect(InputTelemetry.videoTime(hostTime: 108, anchor: 100, duration: 10, pauses: pauses) == nil)
    }

    @Test func rebasedDropsEventsDuringAPauseAndShiftsLaterOnes() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: true)
        telemetry.clicks = [
            .init(time: 101, location: .zero, button: .left, isDown: true, clickCount: 1),
            .init(time: 103, location: .zero, button: .left, isDown: false, clickCount: 1),
            .init(time: 106, location: .zero, button: .left, isDown: true, clickCount: 1)
        ]
        telemetry.keys = [.init(time: 104, keyCode: 8, modifiers: [], isRepeat: false)]

        let rebased = telemetry.rebased(anchor: 100, duration: 10, pauses: [102..<105])

        #expect(rebased.clicks.map(\.time) == [1, 3])
        #expect(rebased.keys.isEmpty)
    }

    @Test func rebasedMovesTheLastCursorPositionDuringAPauseToTheResumePoint() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        telemetry.cursor = [
            .init(time: 99, location: CGPoint(x: 1, y: 1)),
            .init(time: 103, location: CGPoint(x: 2, y: 2)),
            .init(time: 104, location: CGPoint(x: 3, y: 3)),
            .init(time: 106, location: CGPoint(x: 4, y: 4))
        ]

        let rebased = telemetry.rebased(anchor: 100, duration: 10, pauses: [102..<105])

        #expect(rebased.cursor == [
            .init(time: 0, location: CGPoint(x: 1, y: 1)),
            .init(time: 2, location: CGPoint(x: 3, y: 3)),
            .init(time: 3, location: CGPoint(x: 4, y: 4))
        ])
    }

    @Test func rebasedDropsTrackSamplesDuringAPauseStillInProgress() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        telemetry.cursorShapes = [.init(time: 101, sprite: 0), .init(time: 103, sprite: 1)]

        let rebased = telemetry.rebased(anchor: 100, duration: 10, pauses: [102..<Double.infinity])

        #expect(rebased.cursorShapes == [.init(time: 1, sprite: 0)])
    }

    // MARK: - CursorShapeTracker

    @Test func cursorShapesStoreEachImageOnceAndKeepOnlyChanges() {
        let arrow = CursorShapeTracker.Fingerprint(size: CGSize(width: 28, height: 40), hotspot: CGPoint(x: 4.5, y: 4), pixels: Data([1, 2]))
        var iBeam = arrow
        iBeam.pixels = Data([3, 4]) // Same size and hotspot, different image
        var tracker = CursorShapeTracker()
        var encodeCount = 0
        let png = {
            encodeCount += 1
            return Data([0x89])
        }

        tracker.record(arrow, time: 1, png: png)
        tracker.record(arrow, time: 2, png: png)
        tracker.record(iBeam, time: 3, png: png)
        tracker.record(arrow, time: 4, png: png)

        #expect(tracker.sprites.map(\.id) == [0, 1])
        #expect(tracker.sprites.map(\.hotspot) == [CGPoint(x: 4.5, y: 4), CGPoint(x: 4.5, y: 4)])
        #expect(encodeCount == 2)
        #expect(tracker.shapes == [.init(time: 1, sprite: 0), .init(time: 3, sprite: 1), .init(time: 4, sprite: 0)])
    }

    @Test func cursorShapesTakeTheKindOfAnIdenticalStandardCursor() {
        let arrow = CursorShapeTracker.Fingerprint(size: CGSize(width: 28, height: 40), hotspot: CGPoint(x: 5, y: 5), pixels: Data([1, 2]))
        var custom = arrow
        custom.pixels = Data([1, 3]) // An app's own arrow: same size and hotspot, different image
        var tracker = CursorShapeTracker(standardCursors: [(kind: .arrow, fingerprint: arrow)])

        tracker.record(arrow, time: 1) { Data() }
        tracker.record(custom, time: 2) { Data() }

        #expect(tracker.sprites.map(\.kind) == [.arrow, nil])
    }

    // MARK: - videoPixel

    @Test func videoPixelScalesADisplayCaptureByItsScaleFactor() {
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: 100.5, y: 200), geometry: geometry) == CGPoint(x: 201, y: 400))
    }

    @Test func videoPixelOffsetsAnAreaOnADisplayLeftOfThePrimary() {
        let area = InputTelemetry.Geometry(
            time: 0,
            screenRect: CGRect(x: -1820, y: 50, width: 800, height: 600),
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
            boundingRect: nil,
            contentScale: 1,
            scaleFactor: 1
        )
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: -1420, y: 350), geometry: area) == CGPoint(x: 400, y: 300))
    }

    @Test func videoPixelFollowsAWindowScaledDownAndLetterboxed() {
        // A 1000x500 pt window fitted into a 1500x1000 px (750x500 pt) frame: scaled by 0.75,
        // then centred vertically in the 125 pt left over
        let window = InputTelemetry.Geometry(
            time: 0,
            screenRect: CGRect(x: 200, y: 100, width: 1000, height: 500),
            contentRect: CGRect(x: 0, y: 62.5, width: 750, height: 375),
            boundingRect: nil,
            contentScale: 0.75,
            scaleFactor: 2
        )
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: 200, y: 100), geometry: window) == CGPoint(x: 0, y: 125))
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: 700, y: 350), geometry: window) == CGPoint(x: 750, y: 500))
    }

    @Test func videoPixelInsetsAWindowCapturedWithItsShadow() {
        // Recorded values: a 1710x1074 pt window whose shadow adds 112 pt each way, fitted into a
        // 3420x2148 px video. The cursor tip was found at this pixel in the extracted frame.
        let window = InputTelemetry.Geometry(
            time: 0,
            screenRect: CGRect(x: 0, y: 38, width: 1710, height: 1074),
            contentRect: CGRect(x: 0, y: 0, width: 1649.939255475998, height: 1073.9999763965607),
            boundingRect: nil,
            contentScale: 0.9055649042129517,
            scaleFactor: 2
        )
        let pixel = InputTelemetry.videoPixel(for: CGPoint(x: 1402.546875, y: 329.19921875), geometry: window)
        #expect(abs(pixel.x - 2641) <= 4)
        #expect(abs(pixel.y - 598) <= 4)
    }

    // MARK: - CaptureGeometryTracker

    @Test func geometryAtATimeIsTheLastEntryAtOrBeforeItOrElseTheFirst() {
        var moved = geometry
        moved.time = 5
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: .zero), keystrokesAvailable: false)
        #expect(telemetry.geometry(at: 1) == nil)

        telemetry.geometry = [geometry, moved]

        #expect(telemetry.geometry(at: 0)?.time == 1)
        #expect(telemetry.geometry(at: 4.9)?.time == 1)
        #expect(telemetry.geometry(at: 5)?.time == 5)
        #expect(telemetry.geometry(at: 100)?.time == 5)
    }

    @Test func normalizedVideoPointIsAFractionOfTheVideoWithTheGeometryAtItsTime() {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 3024, height: 1964)), keystrokesAvailable: false)
        #expect(telemetry.normalizedVideoPoint(for: .zero, at: 1) == nil)
        var moved = geometry
        moved.time = 5
        moved.screenRect.origin.x = 756
        telemetry.geometry = [geometry, moved]

        #expect(telemetry.normalizedVideoPoint(for: CGPoint(x: 756, y: 491), at: 1) == CGPoint(x: 0.5, y: 0.5))
        #expect(telemetry.normalizedVideoPoint(for: CGPoint(x: 756, y: 491), at: 5) == CGPoint(x: 0, y: 0.5))
    }

    @Test func pixelsPerPointIsTheLowestDuringTheRecording() {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: false)
        #expect(telemetry.pixelsPerPoint == nil)
        var scaledDown = geometry
        scaledDown.contentScale = 0.75

        telemetry.geometry = [geometry, scaledDown]

        #expect(telemetry.pixelsPerPoint == 1.5)
    }

    @Test func geometryIsReadOnlyFromCompleteFrames() throws {
        let screenRect = CGRect(x: -56, y: -2, width: 1892, height: 1188)
        let contentRect = CGRect(x: 0, y: 0, width: 1710, height: 1074)
        var attachments: [String: Any] = [
            SCStreamFrameInfo.status.rawValue: SCFrameStatus.complete.rawValue,
            SCStreamFrameInfo.screenRect.rawValue: screenRect.dictionaryRepresentation,
            SCStreamFrameInfo.contentRect.rawValue: contentRect.dictionaryRepresentation,
            SCStreamFrameInfo.contentScale.rawValue: NSNumber(value: 0.904),
            SCStreamFrameInfo.scaleFactor.rawValue: NSNumber(value: 2)
        ]

        let read = try #require(CaptureGeometryTracker.geometry(from: attachments, time: 12))
        #expect(read == .init(
            time: 12, screenRect: screenRect, contentRect: contentRect, boundingRect: nil, contentScale: 0.904, scaleFactor: 2
        ))

        attachments[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.idle.rawValue
        #expect(CaptureGeometryTracker.geometry(from: attachments, time: 12) == nil)
    }

    @Test func trackerKeepsOnlyChangesWhileEnabled() {
        let tracker = CaptureGeometryTracker()
        var repeated = geometry
        repeated.time = 2
        var moved = geometry
        moved.time = 3
        moved.screenRect.origin.x = 10

        tracker.append(geometry)
        #expect(tracker.track.isEmpty)

        tracker.reset(isEnabled: true)
        tracker.append(geometry)
        tracker.append(repeated)
        tracker.append(moved)
        #expect(tracker.track == [geometry, moved])
    }

    // MARK: - topLeft

    @Test func topLeftFlipsAgainstThePrimaryScreenHeight() {
        #expect(InputTelemetry.topLeft(CGPoint(x: 10, y: 100), primaryScreenHeight: 982) == CGPoint(x: 10, y: 882))
    }

    @Test func topLeftGivesNegativeYOnADisplayAboveThePrimary() {
        #expect(InputTelemetry.topLeft(CGPoint(x: 2200, y: 1200), primaryScreenHeight: 982) == CGPoint(x: 2200, y: -218))
    }

    // MARK: - modifierNames

    @Test func modifierNamesFollowTheMacOSOrder() {
        #expect(InputTelemetry.modifierNames([.maskCommand, .maskShift, .maskControl]) == ["control", "shift", "command"])
    }

    @Test func modifierNamesIgnoreNonModifierFlags() {
        #expect(InputTelemetry.modifierNames([.maskNumericPad]).isEmpty)
    }

    // MARK: - sidecarURL

    @Test func sidecarSitsNextToTheVideoWithTheSameBaseName() {
        let video = URL(filePath: "/Users/me/Movies/Reco_2026-09-25-10.00.00.mov")
        #expect(InputTelemetry.sidecarURL(for: video).path() == "/Users/me/Movies/Reco_2026-09-25-10.00.00.telemetry.json")
    }

    // MARK: - Encoding

    @Test func encodingRoundTripsAndIncludesTheVersion() throws {
        var telemetry = InputTelemetry(capture: capture, keystrokesAvailable: true)
        telemetry.capture.cursorInVideo = false
        telemetry.geometry = [geometry]
        telemetry.cursor = [.init(time: 0.5, location: CGPoint(x: 120, y: 80))]
        telemetry.clicks = [.init(time: 1, location: CGPoint(x: 120, y: 80), button: .right, isDown: true, clickCount: 2)]
        telemetry.scrolls = [.init(time: 1.5, location: CGPoint(x: 120, y: 80), delta: CGVector(dx: 0, dy: 4))]
        telemetry.keys = [.init(time: 2, keyCode: 8, modifiers: ["command"], isRepeat: false)]
        telemetry.cursorSprites = [
            .init(id: 0, kind: .arrow, size: CGSize(width: 28, height: 40), hotspot: CGPoint(x: 4.5, y: 4), png: Data([0x89, 0x50, 0x4E, 0x47]))
        ]
        telemetry.cursorShapes = [.init(time: 0, sprite: 0)]

        let data = try JSONEncoder().encode(telemetry)
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try #require(object as? [String: Any])

        #expect(json["version"] as? Int == 3)
        let capture = try #require(json["capture"] as? [String: Any])
        #expect(capture["cursorInVideo"] as? Bool == false)
        let sprites = try #require(json["cursorSprites"] as? [[String: Any]])
        #expect(sprites.first?["png"] as? String == "iVBORw==")
        #expect(sprites.first?["kind"] as? String == "arrow")
        #expect(json["geometry"] != nil)
        #expect(try JSONDecoder().decode(InputTelemetry.self, from: data) == telemetry)
    }

    @Test func decodingAFileWithoutCursorInVideoOrKindsReadsTheCursorAsInTheVideo() throws {
        let json = """
        {
          "version": 3, "keystrokesAvailable": false,
          "capture": { "kind": "display", "videoSize": [3024, 1964] },
          "geometry": [], "cursor": [], "clicks": [], "scrolls": [], "keys": [],
          "cursorSprites": [{ "id": 0, "size": [28, 40], "hotspot": [5, 5], "png": "iVBORw==" }],
          "cursorShapes": [{ "time": 0, "sprite": 0 }]
        }
        """

        let telemetry = try JSONDecoder().decode(InputTelemetry.self, from: Data(json.utf8))

        #expect(telemetry.capture.cursorInVideo)
        #expect(telemetry.cursorSprites.first?.kind == nil)
    }
}
