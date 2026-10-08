//
//  DebugShotTests.swift
//  RecoTests
//
//  Temporary: renders look-dev films for spec 0012's looks. Delete before committing.
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct DebugShotTests {

    static let scratch = "/private/tmp/claude-501/-Users-divyendra-orca-ssentch/00e31081-8885-4c36-a94f-be1c70a565c8/scratchpad"

    @Test(arguments: [String]())
    func renderLook(name: String) async throws {
        let bundle = URL(filePath: Self.scratch + "/looks/\(name).motion")
        guard FileManager.default.fileExists(atPath: bundle.path()) else { return }
        let data = try Data(contentsOf: bundle.appending(path: "document.json"))
        let document = try JSONDecoder().decode(MotionDocument.self, from: data)
        try document.validate()
        for finding in MotionLint.findings(in: document) {
            print("LINT \(name) \(finding.scene): \(finding.message)")
        }
        var settings = ExportSettings()
        settings.resolution = 2160
        settings.format = .h264
        do {
            let url = try await MotionExporter.export(document, bundle: bundle, settings: settings) { _ in }
            print("EXPORTED \(url.path())")
        } catch {
            print("EXPORT FAILED \(error) \((error as NSError).userInfo)")
            throw error
        }
    }
}
