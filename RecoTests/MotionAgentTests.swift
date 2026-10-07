//
//  MotionAgentTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Reco

/// What an agent edits motion videos with (spec 0011, phase 4): operations, the summary it reads
/// back, the contact sheet and the design check.
@MainActor
struct MotionAgentTests {

    private func grammar() throws -> MotionDocument {
        try JSONDecoder().decode(MotionDocument.self, from: Fixture.data("motion-grammar"))
    }

    private func edits(_ json: String) throws -> [MotionEdit] {
        try JSONDecoder().decode([MotionEdit].self, from: Data(json.utf8))
    }

    private func edited(_ document: MotionDocument, _ json: String) throws -> MotionDocument {
        try EditMotionRequest(operations: edits(json)).edited(document)
    }

    // MARK: - Operations

    @Test func settingAShotLayersMovesKeepsItsLayout() throws {
        let document = try grammar()
        let before = DocumentExpansion.laidOut(document, scene: 0, sizes: [:]).layers[0]
        let result = try edited(document, #"[{"op":"set_moves","id":"title","target":"title.headline","moves":[{"move":"wordByWord","start":0.3}]}]"#)

        let after = DocumentExpansion.laidOut(result, scene: 0, sizes: [:]).layers[0]
        #expect(after.moves == [MotionMove(.wordByWord, start: 0.3)])
        #expect(after.transform == before.transform)
        #expect(after.content == before.content)
        // Nothing else changed
        var unchanged = result
        unchanged.scenes[0].shotMoves = [:]
        #expect(unchanged == document)
    }

    @Test func theCameraOfAShotTakesItsMovesInPlaceOfTheShots() throws {
        let document = try grammar()
        let result = try edited(document, #"[{"op":"set_moves","id":"hero","target":"camera","moves":[{"move":"push"}]}]"#)
        #expect(DocumentExpansion.laidOut(result, scene: 2, sizes: [:]).camera.moves == [MotionMove(.push)])

        // Removing it goes back to the shot's
        let restored = try edited(result, #"[{"op":"remove","id":"hero","target":"camera"}]"#)
        #expect(restored == document)
    }

    @Test func aBatchAppliesWholeOrNotAtAll() throws {
        let document = try grammar()
        #expect {
            try edited(document, #"[{"op":"set_scene","id":"title","duration":4},{"op":"set_moves","id":"nope","target":"x","moves":[]}]"#)
        } throws: { error in
            let message = error.localizedDescription
            return message.contains("Operation 1 (set_moves)") && message.contains("title, hook, hero")
        }
        // Valid alone, but the video can't be drawn with it: a hook needs text
        #expect {
            try edited(document, #"[{"op":"set_scene","id":"hook","shot":{"shot":"hook"}}]"#)
        } throws: { error in
            error.localizedDescription.contains("hook needs text")
        }
    }

    @Test func textAShotDoesntShowIsRefusedNotDropped() throws {
        #expect {
            try edited(grammar(), #"[{"op":"set_scene","id":"focus","shot":{"shot":"uiFocus","ui":"card","text":"Plan less"}}]"#)
        } throws: { error in
            error.localizedDescription.contains("uiFocus shows no text")
        }
    }

    @Test func aMoveTheLayerCantTakeIsRefused() throws {
        #expect(throws: AgentToolError.self) {
            try edited(grammar(), #"[{"op":"set_moves","id":"hero","target":"hero.product","moves":[{"move":"blurWipe"}]}]"#)
        }
    }

    @Test func scenesAreAddedMovedAndRemoved() throws {
        let document = try grammar()
        let result = try edited(document, #"""
            [{"op":"add_scene","index":0,"scene":{"id":"open","duration":2,"shot":{"shot":"hook","text":"Plan less."}}},
             {"op":"move_scene","id":"end","index":1},
             {"op":"remove","id":"roll"},
             {"op":"set_style","style":{"accent":"#5E6AD2","face":"serif"}},
             {"op":"set_canvas","canvas":{"pacing":"beats"}}]
            """#)
        #expect(result.scenes.map(\.id) == ["open", "end", "title", "hook", "hero", "focus", "cascade", "features"])
        #expect(result.style.accent == RGBAColor(red: 94 / 255, green: 106 / 255, blue: 210 / 255, alpha: 1))
        #expect(result.style.face == .serif)
        #expect(result.style.text == document.style.text)
        #expect(result.canvas.pacing == .beats)
        #expect(result.canvas.size == document.canvas.size)
    }

    @Test func aSceneOwnLayerIsReplacedByIDInsideItsGroup() throws {
        let document = try grammar()
        let roll = try #require(document.scenes.first { $0.id == "roll" })
        let id = try #require(roll.layers.first?.id)
        let result = try edited(document, #"[{"op":"set_moves","id":"roll","target":"\#(id)","moves":[{"move":"fadeUp"}]}]"#)
        #expect(result.scenes[6].layers.first?.moves == [MotionMove(.fadeUp)])
        #expect(throws: AgentToolError.self) {
            try edited(document, #"[{"op":"remove","id":"title","target":"title.headline"}]"#)
        }
    }

    @Test func colorsReadAsHex() throws {
        #expect(RGBAColor(hex: "#ff8000") == RGBAColor(red: 1, green: 128 / 255, blue: 0, alpha: 1))
        #expect(RGBAColor(hex: "#ff800080")?.alpha == 128.0 / 255)
        #expect(RGBAColor(hex: "orange") == nil)
        #expect(try JSONDecoder().decode(RGBAColor.self, from: Data(##""#000000""##.utf8)) == RGBAColor(red: 0, green: 0, blue: 0, alpha: 1))
    }

    @Test func aNewVideosNameIsMadeSafeAndUnique() throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = EditMotionRequest.newBundle(named: "Linear: Agents/Launch", in: folder)
        #expect(first.lastPathComponent == "Linear AgentsLaunch.motion")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        #expect(EditMotionRequest.newBundle(named: "Linear: Agents/Launch", in: folder).lastPathComponent == "Linear AgentsLaunch 2.motion")
        #expect(EditMotionRequest.newBundle(named: nil, in: folder).lastPathComponent.hasPrefix("Reco_Motion_"))
    }

    // MARK: - Summary

    @Test func theSummaryListsEachShotsLayersAndWhenTheirMovesRun() throws {
        let document = try grammar()
        let summary = MotionSummary(document, bundle: URL(filePath: "/tmp/a.motion"), sizes: ["card": CGSize(width: 600, height: 350)])
        #expect(summary.scenes.map(\.id) == document.scenes.map(\.id))
        #expect(summary.scenes[1].start == 3)
        let headline = try #require(summary.scenes[0].layers.first)
        #expect(headline.id == "title.headline")
        #expect(headline.fromShot)
        #expect(headline.kind == "text")
        let reveal = try #require(headline.moves.first)
        #expect(reveal.starts == MoveExpansion.entranceStart)
        #expect(reveal.ends > reveal.starts)
        #expect(summary.assets == [MotionSummary.Asset(id: "card", live: false, size: CGSize(width: 600, height: 350))])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try #require(String(data: encoder.encode(summary), encoding: .utf8))
        #expect(json.contains(#""from_shot":true"#))
        #expect(json.contains(#""frame_rate":60"#))
    }

    // MARK: - Word by word

    @Test func wordByWordRevealsAWordAtATime() throws {
        var context = MoveContext(sceneDuration: 3, canvas: CGSize(width: 1920, height: 1080))
        context.words = 4
        let move = MotionMove(.wordByWord)
        #expect(MoveExpansion.timing(of: move, in: context).duration == 0.12 * 3 + 0.45)
        let reveal = try #require(MoveExpansion.effect(of: move, in: context).reveal)
        #expect(reveal.style == .word)
        #expect(abs(reveal.stagger - 0.12) < 1e-9)
        #expect(reveal.partDuration == 0.45)
    }

    // MARK: - Contact sheet and design check

    @Test func eachSceneIsSeenOnceItsLayersAreIn() throws {
        let document = try grammar()
        let summary = MotionSummary(document, bundle: URL(filePath: "/tmp/a.motion"), sizes: [:])
        let moments = ContactSheet.moments(in: summary)
        #expect(moments.map(\.scene) == document.scenes.map(\.id))
        for (moment, scene) in zip(moments, summary.scenes) {
            #expect(moment.time > scene.start && moment.time < scene.start + scene.duration)
        }

        var long = document
        long.scenes = (0..<20).map { MotionScene(id: "s\($0)", duration: 1, shot: MotionShot(.title, text: "Scene \($0)")) }
        let every = ContactSheet.moments(in: MotionSummary(long, bundle: URL(filePath: "/tmp/a.motion"), sizes: [:]))
        #expect(every.count == 20)
        let picked = ContactSheet.picked(every)
        #expect(picked.count == ContactSheet.maximumFrames)
        #expect(picked.first?.scene == "s0")
        #expect(picked.last?.scene == "s19")
    }

    @Test func theDesignCheckFindsAnEmptyFrameAndTooMuchAccent() throws {
        let moment = ContactSheet.Moment(scene: "a", time: 1)
        let accent = RGBAColor(red: 0.37, green: 0.42, blue: 0.82, alpha: 1)
        let flat = try image { context in
            context.setFillColor(CGColor(srgbRed: 0.03, green: 0.03, blue: 0.04, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 192, height: 108))
        }
        let findings = DesignCheck.findings(in: [flat], at: [moment], accent: accent)
        #expect(findings.count == 1)
        #expect(findings.first?.contains("flat") == true)

        // A tenth of the frame in the accent, beside white text
        let loud = try image { context in
            context.setFillColor(CGColor(srgbRed: 0.03, green: 0.03, blue: 0.04, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 192, height: 108))
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 20, y: 60, width: 150, height: 20))
            context.setFillColor(accent.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 192, height: 11))
        }
        let accentFindings = DesignCheck.findings(in: [loud], at: [moment], accent: accent)
        #expect(accentFindings.count == 1)
        #expect(accentFindings.first?.contains("the accent covers") == true)
        #expect(DesignCheck.findings(in: [loud], at: [moment], accent: nil).isEmpty)
    }

    /// A scene whose only layer comes in at 1 s opens on its bare ground; the grammar's shots don't.
    @Test func theDesignCheckFindsABareOpening() async throws {
        let (url, grammar) = try MotionTestBundle.makeGrammar()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(grammar, bundle: url, shorterSide: 270)
        #expect(DesignCheck.bareOpenings(in: plan, scenes: grammar.scenes.map(\.id)).isEmpty)

        let late = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "scenes": [{ "id": "late", "duration": 3, "layers": [
            { "id": "a", "content": { "text": { "text": "Comes in late", "size": 120 } }, "transform": { "position": [960, 540, 0] },
              "moves": [{ "move": "fadeUp", "start": 1 }] }
          ] }]
        }
        """#.utf8))
        let findings = DesignCheck.bareOpenings(in: await MotionPlan.build(late, bundle: URL.temporaryDirectory), scenes: ["late"])
        #expect(findings.count == 1 && findings.first?.hasPrefix("late") == true)
    }

    private func image(_ draw: (CGContext) -> Void) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 192, height: 108, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        draw(context)
        return try #require(context.makeImage())
    }

    // MARK: - Tools

    @Test func editMotionWritesTheBundleAndPreviewLooksAtIt() async throws {
        let (url, _) = try MotionTestBundle.makeGrammar(scale: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let tools = AgentTools(settings: SettingsStore()) { _ in }
        var edited: [URL] = []
        tools.onMotionEdited = { edited.append($0) }
        let path = url.path(percentEncoded: false)

        let edit = await tools.call("edit_motion", arguments: Data(#"""
            {"bundle":"\#(path)","operations":[{"op":"set_scene","id":"title","duration":3.5}]}
            """#.utf8))
        #expect(!edit.isError, "\(edit.text)")
        #expect(edit.text.contains(#""id":"title.headline""#))
        #expect(try await MotionStore.read(url).scenes[0].duration == 3.5)
        #expect(tools.motionEdits == 1)
        #expect(edited == [url])

        let refused = await tools.call("edit_motion", arguments: Data(#"{"bundle":"\#(path)","operations":[{"op":"remove","id":"nothing"}]}"#.utf8))
        #expect(refused.isError)
        #expect(tools.motionEdits == 1)

        let start = ContinuousClock.now
        let preview = await tools.call("preview_motion", arguments: Data(#"{"bundle":"\#(path)"}"#.utf8))
        #expect(!preview.isError, "\(preview.text)")
        let image = try #require(preview.image)
        let decoded = try #require(CGImageSourceCreateWithData(image as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        // 8 scenes: 3 rows of 480×270, 8 px apart
        #expect(decoded.width == 3 * 480 + 2 * 8)
        #expect(decoded.height == 3 * 270 + 2 * 8)
        #expect(preview.text.contains(#""status":"done""#))
        print("MEASURE preview_motion \(ContinuousClock.now - start), sheet \(image.count / 1024) KB")
    }
}
