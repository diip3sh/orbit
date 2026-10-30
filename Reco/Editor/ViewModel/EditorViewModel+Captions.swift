//
//  EditorViewModel+Captions.swift
//  Reco
//

import Foundation
import OSLog

// MARK: - Captions

extension EditorViewModel {

    /// Whether captions show and how, for the inspector's controls. Each change is an edit, and a drag is one undo step.
    var captions: CaptionTrack {
        get { project.captions }
        set { edit("Captions", coalescing: true) { $0.captions = newValue } }
    }

    /// The selected caption.
    var selectedCaption: CaptionCue? {
        guard case .caption(let id) = selection else { return nil }
        return project.captions.cues.first { $0.id == id }
    }

    func selectCaption(_ id: CaptionCue.ID) {
        selection = .caption(id)
    }

    /// Selects a caption and shows the frame where it starts.
    func seekToCaption(_ id: CaptionCue.ID) {
        guard let cue = project.captions.cues.first(where: { $0.id == id }) else { return }
        selection = .caption(id)
        seek(toSource: cue.range.lowerBound)
    }

    /// Moves a caption by `offset` seconds, up to its neighbours and the recording's ends.
    func moveCaption(_ id: CaptionCue.ID, by offset: Double) {
        guard let source else { return }
        editCaptions("Move Caption") { $0.moving(id, by: offset, duration: source.duration) }
    }

    func moveCaptionStart(_ id: CaptionCue.ID, to time: Double) {
        editCaptions("Resize Caption") { $0.movingStart(of: id, to: time) }
    }

    func moveCaptionEnd(_ id: CaptionCue.ID, to time: Double) {
        guard let source else { return }
        editCaptions("Resize Caption") { $0.movingEnd(of: id, to: time, duration: source.duration) }
    }

    func deleteCaption(_ id: CaptionCue.ID) {
        editCaptions("Delete Caption") { $0.removing(id) }
    }

    /// Makes a caption say `text`, its words' times following (``CaptionCue/editing(text:)``). Blank text changes nothing.
    func setCaptionText(_ id: CaptionCue.ID, to text: String) {
        guard let cue = project.captions.cues.first(where: { $0.id == id }), let edited = cue.editing(text: text), edited != cue else { return }
        editCaptions("Edit Caption") { $0.replacing(edited) }
    }

    private func editCaptions(_ actionName: String, _ change: ([CaptionCue]) -> [CaptionCue]) {
        let cues = change(project.captions.cues)
        guard cues != project.captions.cues else { return }
        edit(actionName) {
            $0.captions.cues = cues
            $0.captions.hasEditedCues = true
        }
    }

    /// Writes the captions beside the exported `movie` when `settings` asks and it's a movie in the recording's folder.
    func writeSubtitles(for settings: ExportSettings, to destination: ExportDestination, beside movie: URL, timeMap: TimeMap) throws {
        guard case .recordingFolder = destination, settings.writesSubtitles, settings.format != .gif, !project.captions.cues.isEmpty else { return }
        try SubtitleFile.write(project.captions.cues, timeMap: timeMap, beside: movie)
    }

    /// Reads the languages on offer and picks the Mac's, once.
    func loadCaptionLanguages() async {
        guard #available(macOS 26, *), captionGeneration.languages.isEmpty else { return }
        captionGeneration.languages = await Transcriber.languages()
        if captionGeneration.language == nil {
            captionGeneration.language = await Transcriber.preferredLanguage() ?? captionGeneration.languages.first
        }
    }

    /// Transcribes the voice track in the chosen language and replaces the captions in one undo step, keeping their
    /// style. Failing, being cancelled or hearing nothing leaves them as they are and says why.
    func generateCaptions() {
        guard #available(macOS 26, *), let source, let language = captionGeneration.language, captionTask == nil else { return }
        captionGeneration.notice = nil
        guard !source.audioTrackIDs.isEmpty else {
            captionGeneration.notice = "This recording has no audio to transcribe."
            return
        }
        let track = source.audioTrackIDs[source.voiceTrackIndex ?? 0]
        captionGeneration.progress = .transcribing(0)
        captionTask = Task {
            defer {
                captionGeneration.progress = nil
                captionTask = nil
            }
            do {
                let words = try await Transcriber.transcribe(trackID: track, of: source.asset, language: language) { progress in
                    self.captionGeneration.progress = progress
                }
                guard !Task.isCancelled else { return }
                let cues = CaptionSegmenter.cues(from: words)
                guard !cues.isEmpty else {
                    captionGeneration.notice = "No speech came back. Check the language, and that the recording's voice isn't muted or silent."
                    return
                }
                edit("Generate Captions") {
                    $0.captions.cues = cues
                    $0.captions.hasEditedCues = false
                    $0.captions.isEnabled = true
                }
            } catch is CancellationError {
                // Nothing to say: whoever cancelled knows
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Captions for \(self.videoURL.lastPathComponent) failed: \(error.localizedDescription)")
                captionGeneration.notice = error.localizedDescription
            }
        }
    }

    func cancelGeneratingCaptions() {
        captionTask?.cancel()
    }
}
