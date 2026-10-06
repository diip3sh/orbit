//
//  ExportSessionTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct ExportSessionTests {

    @Test func aTransparentCanvasStartsInTheOnlyFormatThatKeepsIt() {
        #expect(ExportSettings.initial(transparentCanvas: true).format == .proRes4444)
        #expect(ExportSettings.initial(transparentCanvas: false).format == .hevc)
        #expect(ExportSettings.initial(transparentCanvas: false).resolution == nil)
        #expect(ExportSettings.initial(transparentCanvas: false).frameRate == nil)
    }

    @Test func aSessionStartsWithTheCanvasDefaultAndNothingExported() {
        let session = ExportSession(viewModel: EditorViewModel(videoURL: URL(filePath: "/tmp/none.mov")))
        #expect(session.settings == ExportSettings.initial(transparentCanvas: false))
        #expect(!session.isExporting)
        #expect(session.exported == nil)
        #expect(session.exportedBytes == nil)
    }

    @Test func cancellingStopsTheExport() async {
        // Unloaded, so the export returns at once without writing anything
        let session = ExportSession(viewModel: EditorViewModel(videoURL: URL(filePath: "/tmp/none.mov")))
        session.start()
        #expect(session.isExporting)
        session.cancel()
        #expect(!session.isExporting)
        #expect(session.error == nil)
    }
}
