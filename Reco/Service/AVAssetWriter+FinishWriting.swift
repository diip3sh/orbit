//
//  AVAssetWriter+FinishWriting.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

extension AVAssetWriter {

    /// `finishWriting()` with an explicit continuation instead of Swift's async import of it.
    ///
    /// The import's completion-handler thunk has the same symbol as the one in the back-deployed
    /// body of `AVAssetExportSession.export(to:as:)`, which the editor's `ExportService` compiles
    /// into this module while it targets macOS < 26. The two aren't compatible and the linker keeps
    /// one: with the export's copy, `AssetWriter.finishWriting()` crashed on every call (all of
    /// `AssetWriterTests`).
    nonisolated func finishWritingWithoutAsyncImport() async {
        await withCheckedContinuation { continuation in
            finishWriting { continuation.resume() }
        }
    }
}
