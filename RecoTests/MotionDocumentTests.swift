//
//  MotionDocumentTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct MotionDocumentTests {

    @Test func decodesAHandWrittenDocumentWithDefaults() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Fixture.data("motion-demo"))

        #expect(document.canvas.frameRate == 60)
        #expect(document.duration == 5)
        let headline = document.scenes[0].layers[0]
        #expect(headline.name == "headline")
        #expect(headline.opacity == 1)
        #expect(headline.transform.anchor == CGPoint(x: 0.5, y: 0.5))
        #expect(headline.keyframes[.opacity]?.first?.easing == .cubicBezier(0.33, 1, 0.68, 1))
        guard case .text(let text) = headline.content else {
            Issue.record("Not text")
            return
        }
        #expect(text.face == .sans)
        guard case .group(let children) = document.scenes[1].layers[0].content else {
            Issue.record("Not a group")
            return
        }
        #expect(children.map(\.id) == ["card", "badge"])
        #expect(throws: Never.self) { try document.validate() }
    }

    @Test func roundTripsThroughJSON() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Fixture.data("motion-demo"))

        #expect(try JSONDecoder().decode(MotionDocument.self, from: JSONEncoder().encode(document)) == document)
    }

    @Test func refusesOtherVersions() {
        #expect(throws: UnsupportedVersionError(version: 2)) {
            try JSONDecoder().decode(MotionDocument.self, from: Data(#"{"version": 2, "scenes": []}"#.utf8))
        }
    }

    @Test func validationNamesTheFirstProblem() throws {
        var document = try JSONDecoder().decode(MotionDocument.self, from: Fixture.data("motion-demo"))
        var duplicated = document
        duplicated.scenes[1].layers.append(document.scenes[1].layers[0])
        #expect(throws: MotionDocumentError.duplicateID("ui")) { try duplicated.validate() }

        var short = document
        short.scenes[0].duration = 0.001
        #expect(throws: MotionDocumentError.invalidDuration("title")) { try short.validate() }

        var turning = document
        turning.scenes[1].camera.keyframes[.rotationX] = [Keyframe(time: 0, value: 10)]
        #expect(throws: MotionDocumentError.invalidCameraProperty("plane")) { try turning.validate() }

        document.scenes[0].layers[0].keyframes[.scale] = [Keyframe(time: 0, value: 0)]
        #expect(throws: MotionDocumentError.invalidScale("headline")) { try document.validate() }

        #expect(throws: MotionDocumentError.noScenes) { try MotionDocument().validate() }
    }

    @Test func decodesUILayersAndTheirAssets() throws {
        let json = #"""
        {
          "version": 1,
          "assets": [{ "id": "card", "url": "https://linear.app", "selector": ".card" }],
          "scenes": [{ "id": "one", "duration": 1, "layers": [{ "id": "ui", "content": { "ui": { "asset": "card", "width": 900 } } }] }]
        }
        """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))

        #expect(document.assets == [MotionAsset(id: "card", url: try #require(URL(string: "https://linear.app")), selector: ".card")])
        #expect(document.assets[0].viewport == CGSize(width: 1440, height: 900))
        #expect(document.scenes[0].layers[0].content == .lifted(UIContent(asset: "card", width: 900)))
        try document.validate()
    }

    @Test func validatesAssets() throws {
        let url = try #require(URL(string: "https://linear.app"))
        let layer = MotionLayer(id: "ui", content: .lifted(UIContent(asset: "card")))
        var document = MotionDocument(scenes: [MotionScene(id: "one", duration: 1, layers: [layer])])
        #expect(throws: MotionDocumentError.unknownAsset("ui")) { try document.validate() }

        document.assets = [MotionAsset(id: "card", url: url, selector: ".card"), MotionAsset(id: "card", url: url, selector: ".other")]
        #expect(throws: MotionDocumentError.duplicateID("card")) { try document.validate() }

        document.assets = [MotionAsset(id: "card", url: URL(filePath: "/tmp/page.html"), selector: ".card")]
        #expect(throws: MotionDocumentError.invalidAsset("card")) { try document.validate() }

        document.assets = [MotionAsset(id: "card", url: url, selector: ".card", steps: [RecordPageRequest.Step(action: "type", selector: "#field")])]
        #expect(throws: MotionDocumentError.self) { try document.validate() }

        document.assets = [MotionAsset(id: "card", url: url, selector: ".card")]
        document.scenes[0].layers[0].content = .lifted(UIContent(asset: "card", width: 0))
        #expect(throws: MotionDocumentError.invalidSize("ui")) { try document.validate() }
    }

    @Test func storeWritesAndReadsABundle() async throws {
        let (url, document) = try MotionTestBundle.make()
        defer { try? FileManager.default.removeItem(at: url) }
        var changed = document
        changed.scenes[0].duration = 1.5

        try await MotionStore.write(changed, to: url)

        #expect(try await MotionStore.read(url) == changed)
    }
}
