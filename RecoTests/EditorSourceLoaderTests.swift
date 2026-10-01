//
//  EditorSourceLoaderTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation
import Testing
@testable import Reco

struct EditorSourceLoaderTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private var video: URL {
        folder.appending(path: "recording.mov")
    }

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func aRecordingWithoutASidecarHasNoTelemetry() {
        let (telemetry, error) = EditorSourceLoader.loadTelemetry(for: video)

        #expect(telemetry == nil)
        guard case .noTelemetry = error else {
            Issue.record("Expected .noTelemetry, got \(String(describing: error))")
            return
        }
    }

    @Test func anUnreadableSidecarSaysWhy() throws {
        try Data(#"{ "version": 9 }"#.utf8).write(to: InputTelemetry.sidecarURL(for: video))

        let (telemetry, error) = EditorSourceLoader.loadTelemetry(for: video)

        #expect(telemetry == nil)
        guard case .unreadableTelemetry(let cause) = error else {
            Issue.record("Expected .unreadableTelemetry, got \(String(describing: error))")
            return
        }
        #expect(cause as? UnsupportedVersionError == UnsupportedVersionError(version: 9))
    }

    @Test func readsTheSidecar() throws {
        try Fixture.data("telemetry-v3").write(to: InputTelemetry.sidecarURL(for: video))

        let (telemetry, error) = EditorSourceLoader.loadTelemetry(for: video)

        #expect(telemetry?.version == 3)
        #expect(error == nil)
    }
}
