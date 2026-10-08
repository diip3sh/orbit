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
        guard let data = try? Data(contentsOf: spec),
              let job = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = job["bundle"] as? String, let times = job["times"] as? [Double], let out = job["out"] as? String else { return }
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
}
