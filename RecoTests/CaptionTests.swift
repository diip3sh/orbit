//
//  CaptionTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

// MARK: - Helpers

func word(_ text: String, _ start: Double, _ end: Double, confidence: Double = 0.9) -> CaptionWord {
    CaptionWord(text: text, range: start..<end, confidence: confidence)
}

/// A cue saying `text`, one second per word from `start`.
func cue(_ text: String, from start: Double) -> CaptionCue {
    let words = text.split(separator: " ").enumerated().map { index, token in
        word(String(token), start + Double(index), start + Double(index) + 1)
    }
    return CaptionCue(range: start..<start + Double(words.count), text: text, words: words)
}

func temporaryFolder() throws -> URL {
    let folder = URL.temporaryDirectory.appending(path: "CaptionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

// MARK: - Segmenting

struct CaptionSegmenterTests {

    @Test func aPauseEndsACue() {
        let cues = CaptionSegmenter.cues(from: [word(" one", 0, 0.5), word(" two", 0.5, 1), word(" three", 2, 2.5)])
        #expect(cues.map(\.text) == ["one two", "three"])
        #expect(cues[0].words.map(\.text) == ["one", "two"])
    }

    @Test func aSentenceEndsACueOnceItIsLongEnough() {
        let cues = CaptionSegmenter.cues(from: [
            word(" Yes.", 0, 0.2), word(" That", 0.2, 0.4), word(" sounds", 0.4, 0.6), word(" fine", 0.6, 0.8), word(" today.", 0.8, 1), word(" Next", 1, 1.2)
        ])
        #expect(cues.map(\.text) == ["Yes. That sounds fine today.", "Next"])
    }

    @Test func longSpeechIsDivided() throws {
        let words = (0..<60).map { word(" word\($0)", Double($0) * 0.3, Double($0) * 0.3 + 0.3) }
        let cues = CaptionSegmenter.cues(from: words)
        #expect(cues.count > 1)
        for cue in cues {
            #expect(cue.text.count <= CaptionSegmenter.maximumCharacters)
            #expect(cue.range.upperBound - cue.range.lowerBound <= CaptionSegmenter.maximumDuration)
        }
        // Every word is in a cue, once
        #expect(cues.flatMap(\.words).count == 60)
    }

    @Test func cuesAreApartAndHoldLongEnoughWhenThereIsRoom() {
        let cues = CaptionSegmenter.cues(from: [word(" Hi", 1, 1.2), word(" there", 2, 2.2), word(" you", 2.5, 2.7)])
        #expect(cues.count == 2)
        // A second, or up to the next cue
        #expect(cues[0].range == 1..<2)
        #expect(cues[1].range.upperBound == 3)
        for (first, second) in zip(cues, cues.dropFirst()) {
            #expect(first.range.upperBound <= second.range.lowerBound)
        }
    }

    @Test func languagesWithoutSpacesStayAsTheyAre() {
        let cues = CaptionSegmenter.cues(from: [word("今日", 0, 0.5), word("は", 0.5, 0.7), word("晴れ", 0.7, 1)])
        #expect(cues.map(\.text) == ["今日は晴れ"])
        #expect(cues[0].words.count == 3)
    }

    @Test func punctuationJoinsTheWordBefore() {
        var words: [CaptionWord] = []
        CaptionSegmenter.append(text: " Hello", range: 0..<0.5, confidence: 0.8, to: &words)
        CaptionSegmenter.append(text: ",", range: 0.5..<0.6, confidence: 0.9, to: &words)
        CaptionSegmenter.append(text: " world", range: 0.6..<1, confidence: nil, to: &words)
        CaptionSegmenter.append(text: "!", range: nil, confidence: nil, to: &words)
        CaptionSegmenter.append(text: "  ", range: 1..<1.1, confidence: nil, to: &words)
        #expect(words.map(\.text) == [" Hello,", " world!"])
        #expect(words[0].range == 0..<0.6)
        #expect(words[1].confidence == 1)
    }
}

// MARK: - Editing

struct CaptionCueEditingTests {

    @Test func correctingAWordKeepsEveryWordsTime() throws {
        let edited = try #require(cue("the quick brown fox", from: 10).editing(text: "the quick red fox"))
        #expect(edited.text == "the quick red fox")
        #expect(edited.words.map(\.range) == [10..<11, 11..<12, 12..<13, 13..<14])
        // Unchanged words keep their confidence; the typed one is certain
        #expect(edited.words.map(\.confidence) == [0.9, 0.9, 1, 0.9])
    }

    @Test func anotherNumberOfWordsSpreadsThemByLength() throws {
        let original = cue("one two", from: 0)
        let edited = try #require(original.editing(text: "a bbb c"))
        #expect(edited.words.map(\.text) == ["a", "bbb", "c"])
        // 1, 3 and 1 characters over 2 seconds
        #expect(edited.words[0].range == 0..<0.4)
        #expect(edited.words[1].range == 0.4..<1.6)
        #expect(edited.words[2].range == 1.6..<2)
        #expect(edited.range == original.range)
    }

    @Test func spreadWordsFillTheCueExactlyAndInOrder() throws {
        let edited = try #require(cue("one two three", from: 3.3).editing(text: "seven words of unequal length go here"))
        #expect(edited.words.first?.range.lowerBound == 3.3)
        #expect(edited.words.last?.range.upperBound == edited.range.upperBound)
        for (first, second) in zip(edited.words, edited.words.dropFirst()) {
            #expect(first.range.upperBound == second.range.lowerBound)
        }
    }

    @Test func spacesAreTidiedAndBlankTextIsRefused() throws {
        #expect(try #require(cue("one two", from: 0).editing(text: "  one \n  two ")).text == "one two")
        #expect(cue("one two", from: 0).editing(text: " \n ") == nil)
    }

    @Test func movingACueCarriesItsWords() {
        var moved = cue("one two", from: 0)
        moved.range = 5..<7
        #expect(moved.words.map(\.range) == [5..<6, 6..<7])
    }

    @Test func resizingACueScalesItsWords() {
        var resized = cue("one two", from: 2)
        resized.range = 2..<3
        #expect(resized.words.map(\.range) == [2..<2.5, 2.5..<3])
    }

    @Test func theLaneMovesCuesUpToTheirNeighbours() {
        let cues = [cue("one two", from: 0), cue("three", from: 5)]
        let moved = cues.moving(cues[0].id, by: 10, duration: 20)
        #expect(moved[0].range == 3..<5)
        #expect(moved[0].words[0].range == 3..<4)
    }
}

// MARK: - Subtitle files

struct SubtitleFileTests {

    /// 20 s, with 4–6 s cut and 10–14 s at 2×, so at output: 0–4, 6–10 → 4–8, 10–14 → 8–10, 14–20 → 10–16.
    private let timeMap = TimeMap(
        cuts: [4..<6], speeds: [SpeedRange(range: 10..<14, rate: 2)], sourceDuration: 20, frameRate: 30
    )

    @Test func srtAcrossACutAndASpeed() {
        let cues = [
            cue("before the cut", from: 0),
            cue("gone", from: 4.5),
            cue("across cut", from: 3),
            cue("in the fast part", from: 10),
            cue("after it", from: 14)
        ].sorted { $0.range.lowerBound < $1.range.lowerBound }
        var gone = cues
        gone[2].range = 4.5..<5.5

        #expect(SubtitleFile.srt(for: gone, timeMap: timeMap) == """
        1
        00:00:00,000 --> 00:00:03,000
        before the cut

        2
        00:00:03,000 --> 00:00:04,000
        across cut

        3
        00:00:08,000 --> 00:00:10,000
        in the fast part

        4
        00:00:10,000 --> 00:00:12,000
        after it

        """)
    }

    @Test func vttUsesAPeriodAndEscapes() {
        let map = TimeMap(cuts: [], sourceDuration: 4000, frameRate: 30)
        let tom = CaptionCue(range: 3661.5..<3662.25, text: "Tom & <Jerry>", words: [])
        #expect(SubtitleFile.vtt(for: [tom], timeMap: map) == """
        WEBVTT

        01:01:01.500 --> 01:01:02.250
        Tom &amp; &lt;Jerry&gt;

        """)
    }

    @Test func allCutLeavesAnEmptyFile() {
        let gone = [CaptionCue(range: 4.5..<5.5, text: "gone", words: [])]
        #expect(SubtitleFile.srt(for: gone, timeMap: timeMap).isEmpty)
        #expect(SubtitleFile.vtt(for: gone, timeMap: timeMap) == "WEBVTT\n")
    }

    @Test func rollsOverIntoTheNextSecondWhenRounding() {
        let map = TimeMap(cuts: [], sourceDuration: 100, frameRate: 30)
        let entries = SubtitleFile.entries(for: [CaptionCue(range: 59.9996..<60.5, text: "x", words: [])], timeMap: map)
        #expect(entries[0].range == 60_000..<60_500)
    }
}

// MARK: - The project

struct CaptionProjectTests {

    @Test func anOldProjectDecodesWithoutCaptions() throws {
        let project = try JSONDecoder().decode(EditorProject.self, from: Data(#"{"version":1,"cuts":[]}"#.utf8))
        #expect(project.captions == CaptionTrack())
    }

    @Test func captionsRoundTrip() throws {
        var project = EditorProject()
        project.captions.cues = [cue("one two", from: 1)]
        project.captions.style.position = .top
        project.captions.hasEditedCues = true
        #expect(try JSONDecoder().decode(EditorProject.self, from: JSONEncoder().encode(project)) == project)
    }

    @Test func aNewTakeKeepsTheStyleNotTheWords() {
        var other = EditorProject()
        other.captions.style.size = 0.07
        other.captions.cues = [cue("not mine", from: 0)]
        let styled = EditorProject().styled(like: other)
        #expect(styled.captions.style.size == 0.07)
        #expect(styled.captions.cues.isEmpty)
    }

    @Test func theTabIsAvailableOnThisSystem() {
        if #available(macOS 26, *) {
            #expect(InspectorTab.caption.isAvailable)
        } else {
            #expect(!InspectorTab.caption.isAvailable)
        }
        #expect(InspectorTab.caption.unavailableReason.contains("macOS 26"))
    }
}

// MARK: - Layout

struct CaptionLayoutTests {

    private static let long = "This caption is long enough that it will not fit on one line at any sensible size at all"

    private func layout(_ text: String, in frame: CGSize, size: Double = CaptionStyle().size) -> CaptionLayout {
        CaptionLayout(
            text: text, words: text.split(separator: " ").map(String.init), fontSize: min(frame.width, frame.height) * size,
            maximumWidth: frame.width * PlannedCaptions.widthFraction
        )
    }

    @Test(arguments: [
        CGSize(width: 1280, height: 720), CGSize(width: 3840, height: 2160), CGSize(width: 1080, height: 1920),
        CGSize(width: 720, height: 720), CGSize(width: 320, height: 180), CGSize(width: 180, height: 320)
    ])
    func staysInTheFrameOnAtMostTwoLines(frame: CGSize) {
        for size in [CaptionStyle.sizes.lowerBound, CaptionStyle().size, CaptionStyle.sizes.upperBound] {
            let layout = layout(Self.long, in: frame, size: size)
            #expect(layout.lines.count <= 2)
            #expect(layout.size.width <= frame.width)
            #expect(layout.size.height <= frame.height)
            // Words are all placed, inside the box
            #expect(layout.wordRects.count == Self.long.split(separator: " ").count)
            for rect in layout.wordRects {
                #expect(rect.minX >= -1 && rect.maxX <= layout.size.width + 1)
                #expect(rect.minY >= -1 && rect.maxY <= layout.size.height + 1)
            }
        }
    }

    @Test func aShortCaptionTakesOneLineAndALongOneTwo() {
        #expect(layout("Short", in: CGSize(width: 1920, height: 1080)).lines.count == 1)
        #expect(layout(Self.long, in: CGSize(width: 1280, height: 720), size: 0.08).lines.count == 2)
    }

    @Test func aSingleHugeWordShrinksToFit() {
        let frame = CGSize(width: 320, height: 180)
        let layout = layout(String(repeating: "x", count: 200), in: frame)
        #expect(layout.lines.count == 1)
        #expect(layout.size.width <= frame.width)
    }

    @Test func wordsOnTheSecondLineAreBelowTheFirst() {
        let text = Self.long
        let layout = layout(text, in: CGSize(width: 1280, height: 720), size: 0.08)
        #expect(layout.wordRects[0].minY > layout.wordRects[layout.wordRects.count - 1].minY)
    }

    @Test func aCaptionStaysClearOfTheKeystrokeChip() {
        let video = CGRect(x: 40, y: 20, width: 1200, height: 675)
        let origin = PlannedCaptions.origin(of: CGSize(width: 600, height: 60), position: .bottom, in: video, hasChips: true)
        // As FrameRenderer places a chip: 0.8 of its height (6% of the shorter side) over the edge, and as tall again
        let chip = min(video.width, video.height) * 0.06
        #expect(origin.y >= video.minY + chip * 1.8)
        // Without chips it can sit lower
        #expect(PlannedCaptions.origin(of: CGSize(width: 600, height: 60), position: .bottom, in: video, hasChips: false).y < origin.y)
        #expect(origin.x == 340)
    }

    @Test func positionsStayInTheVideo() {
        let video = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let size = CGSize(width: 800, height: 100)
        for position in CaptionStyle.Position.allCases {
            let origin = PlannedCaptions.origin(of: size, position: position, in: video, hasChips: true)
            #expect(video.contains(CGRect(origin: origin, size: size)))
        }
    }
}

// MARK: - The view model

@MainActor
struct CaptionViewModelTests {

    private func viewModel(withAudio: Bool = false) async throws -> EditorViewModel {
        let url = try temporaryFolder().appending(path: "video.mov")
        try await TestRecording.write(to: url, size: CGSize(width: 320, height: 180), frameCount: 300, frameRate: 30, withTone: withAudio)
        let viewModel = EditorViewModel(videoURL: url)
        await viewModel.load()
        return viewModel
    }

    @Test func editsAreUndoableAndMarkTheCuesEdited() async throws {
        let viewModel = try await viewModel()
        let first = cue("one two", from: 1)
        viewModel.edit("Generate Captions") { $0.captions.cues = [first, cue("three", from: 5)] }
        #expect(!viewModel.captions.hasEditedCues)
        // No run loop turns here, so the undo manager would group this with the edit below
        viewModel.undoManager.removeAllActions()

        viewModel.selectCaption(first.id)
        viewModel.setCaptionText(first.id, to: "one too many")
        #expect(viewModel.captions.cues[0].words.count == 3)
        #expect(viewModel.captions.hasEditedCues)
        // Still selected, so the next edit is of the same caption
        #expect(viewModel.selection == .caption(first.id))

        viewModel.undoManager.undo()
        #expect(viewModel.captions.cues[0] == first)
        #expect(!viewModel.captions.hasEditedCues)
        await viewModel.close()
    }

    @Test func theSameTextIsNoEdit() async throws {
        let viewModel = try await viewModel()
        let first = cue("one two", from: 1)
        viewModel.edit("Generate Captions") { $0.captions.cues = [first] }
        viewModel.setCaptionText(first.id, to: "one two")
        viewModel.setCaptionText(first.id, to: "   ")
        #expect(!viewModel.captions.hasEditedCues)
        #expect(viewModel.captions.cues == [first])
        await viewModel.close()
    }

    @Test func deleteKeyRemovesTheSelectedCaption() async throws {
        let viewModel = try await viewModel()
        let first = cue("one two", from: 1)
        viewModel.edit("Generate Captions") { $0.captions.cues = [first] }
        viewModel.selectCaption(first.id)
        #expect(viewModel.canDeleteSelection)
        viewModel.deleteSelection()
        #expect(viewModel.captions.cues.isEmpty)
        #expect(viewModel.selection == nil)
        await viewModel.close()
    }

    @Test func theLaneMovesAndResizes() async throws {
        let viewModel = try await viewModel()
        let first = cue("one two", from: 1)
        viewModel.edit("Generate Captions") { $0.captions.cues = [first] }
        viewModel.moveCaption(first.id, by: 2)
        #expect(viewModel.captions.cues[0].range == 3..<5)
        viewModel.moveCaptionEnd(first.id, to: 4)
        #expect(viewModel.captions.cues[0].words.map(\.range) == [3..<3.5, 3.5..<4])
        viewModel.moveCaptionStart(first.id, to: 2)
        #expect(viewModel.captions.cues[0].range == 2..<4)
        await viewModel.close()
    }

    @Test func noAudioSaysSo() async throws {
        guard #available(macOS 26, *) else { return }
        let viewModel = try await viewModel()
        await viewModel.loadCaptionLanguages()
        viewModel.captionGeneration.language = "en_US"
        viewModel.generateCaptions()
        #expect(viewModel.captionGeneration.notice?.contains("no audio") == true)
        #expect(viewModel.captionTask == nil)
        await viewModel.close()
    }

    @Test func exportWritesSubtitlesBesideTheMovieWhenAsked() async throws {
        let viewModel = try await viewModel()
        viewModel.edit("Generate Captions") { $0.captions.cues = [cue("one two", from: 3)] }
        viewModel.edit("Cut") { $0.cuts = [0..<1] }
        var settings = ExportSettings(writesSubtitles: true)
        let movie = try #require(try await viewModel.export(settings))
        let srt = try String(contentsOf: movie.deletingPathExtension().appendingPathExtension("srt"), encoding: .utf8)
        let vtt = try String(contentsOf: movie.deletingPathExtension().appendingPathExtension("vtt"), encoding: .utf8)
        #expect(srt == "1\n00:00:02,000 --> 00:00:04,000\none two\n")
        #expect(vtt == "WEBVTT\n\n00:00:02.000 --> 00:00:04.000\none two\n")

        try FileManager.default.removeItem(at: movie.deletingPathExtension().appendingPathExtension("srt"))
        settings.writesSubtitles = false
        _ = try await viewModel.export(settings)
        #expect(!FileManager.default.fileExists(atPath: movie.deletingPathExtension().appendingPathExtension("srt").path()))
        await viewModel.close()
    }
}
