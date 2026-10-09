//
//  DebugShotTests.swift
//  RecoTests
//
//  Temporary: renders look-dev frames for spec 0012's looks. Delete before committing.
//

import CoreImage
import Foundation
import Testing
@testable import Reco

@MainActor
struct DebugShotTests {

    static let scratch = "/private/tmp/claude-501/-Users-divyendra-orca-ssentch/00e31081-8885-4c36-a94f-be1c70a565c8/scratchpad"

    /// `frames.json`: {"bundle": path, "times": [s], "side": px, "out": path}; frames drawn as an export draws them.
    @Test func renderFrames() async throws {
        let spec = URL(filePath: Self.scratch + "/frames.json")
        guard let data = try? Data(contentsOf: spec), let object = try? JSONSerialization.jsonObject(with: data) else { return }
        for job in (object as? [[String: Any]]) ?? [object as? [String: Any] ?? [:]] {
            try await renderJob(job)
        }
    }

    private func renderJob(_ job: [String: Any]) async throws {
        guard let path = job["bundle"] as? String, let times = job["times"] as? [Double], let out = job["out"] as? String else { return }
        let bundle = URL(filePath: path)
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
        for finding in MotionLint.findings(in: document) {
            print("LINT \(finding.scene): \(finding.message)")
        }
        let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: CGFloat(job["side"] as? Double ?? 540), frameRate: 30)
        let frames = try await ContactSheet.frames(of: plan, at: times.map { ContactSheet.Moment(scene: "", time: $0) })
        for (index, frame) in frames.enumerated() {
            try await ScreenshotService.writePNG(frame, to: URL(filePath: out + "-\(index).png"))
        }
        print("FRAMES \(frames.count)")
    }

    /// `checks.json`: [bundle paths]; the text design checks of each.
    @Test func textChecks() async throws {
        guard let data = try? Data(contentsOf: URL(filePath: Self.scratch + "/checks.json")),
              let paths = try JSONSerialization.jsonObject(with: data) as? [String] else { return }
        for path in paths {
            let bundle = URL(filePath: path)
            let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
            let plan = await MotionPlan.build(document, bundle: bundle)
            let ids = document.scenes.map(\.id)
            print("CHECK \(bundle.lastPathComponent): \(DesignCheck.overlappingText(in: plan, document: DocumentExpansion.expanded(document, sizes: UILiftCache.sizes(of: document, in: bundle))) + DesignCheck.cutText(in: plan, scenes: ids))")
        }
    }

    /// `sound.json`: {"bundle": path, "out": folder}; the plan's cue sheet and its sound written there.
    @Test func dumpSound() async throws {
        let spec = URL(filePath: Self.scratch + "/sound.json")
        guard let data = try? Data(contentsOf: spec),
              let job = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = job["bundle"] as? String, let out = job["out"] as? String else { return }
        let bundle = URL(filePath: path)
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
        let clock = ContinuousClock()
        var plan: MotionPlan?
        let built = try await clock.measure { plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 1080) }
        let sheet = try #require(plan?.sound)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(sheet).write(to: URL(filePath: out + "/sheet.json"))
        var sound = StereoSound(silence: 0)
        let rendered = clock.measure { sound = ScoreRenderer.render(sheet) }
        try SoundCache.write(sound, to: URL(filePath: out + "/engine.caf"))
        let plan2 = try #require(plan)
        print("WHIPS \(SoundCueSheet.cameraWhips(in: plan2, until: plan2.duration))")
        print("SOUND plan \(built), render \(rendered), \(sheet.cues.count) cues, LUFS \(Loudness.integrated(sound)), TP \(Loudness.truePeak(sound))")
    }

    @Test func auroraStill() async throws {
        let style = StyleTokens(accent: RGBAColor(hex: "#5b6ff8"), gradient: ["#5b6ff8", "#a783f5", "#f582e9", "#ed3c55", "#ef6720"].compactMap { RGBAColor(hex: $0) })
        let palette = FieldPalette(.aurora, style: style, background: RGBAColor(red: 0, green: 0, blue: 0, alpha: 1))
        print("AURORA palette \(palette.colors.count)")
        let image = FieldRenderer.image(.aurora, palette: palette, at: 1, size: CGSize(width: 960, height: 540), shot: FieldRenderer.Shot(index: 1, start: 0.5))
        print("AURORA extent \(image.extent)")
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        let cg = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: 960, height: 540))
        print("AURORA cg \(cg != nil)")
        if let cg { try await ScreenshotService.writePNG(cg, to: URL(filePath: Self.scratch + "/look/aurora-still.png")) }
    }

    @Test func auroraDraw() async throws {
        let bundle = URL(filePath: NSHomeDirectory() + "/Movies/Reco/quality/story/Aurora.motion")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
        let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 540, frameRate: 30)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 960, 540, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
        do {
            try MotionFrameRenderer.draw(at: 1, plan: plan, into: try #require(buffer), context: context)
            print("AURORA drawn")
        } catch {
            print("AURORA error \(error)")
        }
    }

    @Test func gradientStill() async throws {
        let colors = ["#5b6ff8", "#a783f5", "#f582e9", "#ed3c55", "#ef6720"].compactMap { RGBAColor(hex: $0) }
        let image = MotionFrameRenderer.gradient(colors, from: 100, to: 800, over: CGRect(x: 0, y: 0, width: 900, height: 200))
        print("AURORA gradient extent \(image.extent)")
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        if let cg = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: 900, height: 200)) {
            try await ScreenshotService.writePNG(cg, to: URL(filePath: Self.scratch + "/look/gradient-still.png"))
            print("AURORA gradient written")
        }
    }

    /// `export.json`: {"bundle": path, "side": px}; the bundle exported as HEVC next to it.
    @Test func exportMovie() async throws {
        let spec = URL(filePath: Self.scratch + "/export.json")
        guard let data = try? Data(contentsOf: spec),
              let job = try JSONSerialization.jsonObject(with: data) as? [String: Any], let path = job["bundle"] as? String else { return }
        let bundle = URL(filePath: path)
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
        var settings = ExportSettings(format: (job["format"] as? String).flatMap(ExportFormat.init(rawValue:)) ?? .hevc)
        settings.resolution = job["side"] as? Int ?? 1080
        let clock = ContinuousClock()
        var url: URL?
        let took = try await clock.measure { url = try await MotionExporter.export(document, bundle: bundle, settings: settings) { _ in } }
        print("EXPORT \(url?.path ?? "") in \(took)")
    }

    @Test func dumpForm() async throws {
        let bundle = URL(filePath: NSHomeDirectory() + "/Movies/Reco/quality/story/Lovable Rebuild.motion")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: bundle.appending(path: "document.json")))
        let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: 540, frameRate: 30)
        let expanded = DocumentExpansion.expanded(document, sizes: [:])
        for shot in SoundCueSheet.shots(of: plan, document: expanded) {
            print("AURORA shot \(shot.start) \(shot.end) words \(shot.isWords)")
        }
    }
}
