//
//  ClipOrderTests.swift
//  RecoTests
//

import AVFoundation
import CoreGraphics
import Testing
@testable import Reco

// MARK: - The time map

struct ClipOrderTimeMapTests {

    /// 10 s at 10 fps, so times are exact frames.
    private func map(cuts: [Range<Double>] = [], speeds: [SpeedRange] = [], sequence: [Range<Double>]) -> TimeMap {
        TimeMap(cuts: cuts, speeds: speeds, sequence: sequence, sourceDuration: 10, frameRate: 10)
    }

    private func close(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 1e-9
    }

    @Test func anEmptySequenceIsSourceOrder() {
        let map = map(cuts: [2..<3], sequence: [])
        #expect(map.playedRanges == map.keptRanges)
        #expect(map.playedRanges == [0..<2, 3..<10])
    }

    @Test func aSequenceInSourceOrderChangesNothing() {
        #expect(map(sequence: [0..<4, 4..<10]) == TimeMap(cuts: [], sourceDuration: 10, frameRate: 10))
    }

    @Test func itPlaysInTheSequencesOrder() {
        let map = map(sequence: [6..<10, 0..<6])
        #expect(map.playedRanges == [6..<10, 0..<6])
        #expect(map.pieces.map(\.range) == [6..<10, 0..<6])
        #expect(map.keptRanges == [0..<10])
        #expect(map.outputDuration == 10)
    }

    @Test func itMapsBothWays() {
        let map = map(sequence: [6..<10, 0..<6])
        #expect(close(map.outputTime(atSource: 7), 1))
        #expect(close(map.outputTime(atSource: 1), 5))
        #expect(close(map.sourceTime(atOutput: 1), 7))
        #expect(close(map.sourceTime(atOutput: 5), 1))
    }

    @Test func everyFrameRoundTrips() {
        let map = map(cuts: [3..<4], speeds: [SpeedRange(range: 5..<7, rate: 2)], sequence: [7..<10, 0..<3, 4..<7])
        for frame in 0..<100 {
            let source = Double(frame) / 10
            guard let output = map.outputTime(ifKept: source) else {
                #expect((3..<4).contains(source))
                continue
            }
            #expect(close(map.sourceTime(atOutput: output), source))
        }
    }

    @Test func aCutTimeLandsOnTheContentAfterItInTheSource() {
        let map = map(cuts: [3..<4], sequence: [4..<10, 0..<3])
        #expect(map.outputTime(ifKept: 3.5) == nil)
        #expect(close(map.outputTime(atSource: 3.5), 0))
    }

    @Test func speedsDividePiecesInTheirClips() {
        let map = map(speeds: [SpeedRange(range: 1..<8, rate: 2)], sequence: [6..<10, 0..<6])
        #expect(map.pieces == [
            SpeedRange(range: 6..<8, rate: 2), SpeedRange(range: 8..<10, rate: 1),
            SpeedRange(range: 0..<1, rate: 1), SpeedRange(range: 1..<6, rate: 2)
        ])
        #expect(close(map.outputDuration, 1 + 2 + 1 + 2.5))
    }

    // MARK: Reconciling

    @Test func aCutInsideAClipShortensItInPlace() {
        #expect(map(cuts: [7..<8], sequence: [6..<10, 0..<6]).playedRanges == [6..<7, 8..<10, 0..<6])
    }

    @Test func aClipEntirelyCutDropsOut() {
        #expect(map(cuts: [6..<10], sequence: [6..<10, 0..<6]).playedRanges == [0..<6])
    }

    @Test func aRestoredTailStaysWithItsClip() {
        // Clip 6..<8 was moved first with 8..<10 cut, then the cut went away
        #expect(map(sequence: [6..<8, 0..<6]).playedRanges == [6..<10, 0..<6])
    }

    @Test func aRestoredHeadStaysWithItsClip() {
        // 2..<3 continues nothing, so it goes before what continues it, not after what's earlier in the source
        #expect(map(cuts: [1..<2], sequence: [3..<5, 0..<1, 5..<10]).playedRanges == [2..<5, 0..<1, 5..<10])
    }

    @Test func anOverlappingEntryPlaysOnce() {
        let map = map(sequence: [4..<6, 0..<5, 6..<10])
        #expect(map.playedRanges == [4..<6, 0..<4, 6..<10])
        #expect(map.outputDuration == 10)
    }

    @Test func aStaleSequenceBeyondTheEndIsClamped() {
        #expect(map(sequence: [8..<20, 0..<8]).playedRanges == [8..<10, 0..<8])
    }

    // MARK: Output ranges

    @Test func aRangeCrossingAJumpShowsInTwoPlaces() {
        // Source 5..<7 straddles the clips 6..<10 and 0..<6
        #expect(map(sequence: [6..<10, 0..<6]).outputRanges(ofSource: 5..<7) == [0..<1, 9..<10])
    }

    @Test func aRangeAcrossACutIsOnePlace() {
        let map = TimeMap(cuts: [3..<4], sourceDuration: 10, frameRate: 10)
        #expect(map.outputRanges(ofSource: 2..<5) == [2..<4])
    }

    @Test func aRangeEntirelyCutShowsNowhere() {
        #expect(TimeMap(cuts: [3..<6], sourceDuration: 10, frameRate: 10).outputRanges(ofSource: 4..<5).isEmpty)
    }

    @Test func theSameInSourceOrderAsTheEndsAlways() {
        let map = TimeMap(cuts: [2..<3, 7..<8], speeds: [SpeedRange(range: 4..<6, rate: 2)], sourceDuration: 10, frameRate: 10)
        for range in [0..<1.5, 1..<5, 2.5..<7.5, 5..<10, 0..<10] {
            let ranges = map.outputRanges(ofSource: range)
            #expect(ranges.count == 1)
            #expect(close(ranges[0].lowerBound, map.outputTime(atSource: range.lowerBound)))
            #expect(close(ranges[0].upperBound, map.outputTime(atSource: range.upperBound)))
        }
    }

    @Test func whatPlaysFromATime() {
        #expect(map(sequence: [6..<10, 0..<6]).sourceRanges(fromOutput: 8) == [4..<6])
        #expect(map(sequence: [6..<10, 0..<6]).sourceRanges(fromOutput: 2) == [8..<10, 0..<6])
    }

    // MARK: Moving clips

    @Test func movingAClipLeavesTheOthersInOrder() {
        let map = TimeMap(cuts: [], sourceDuration: 10, frameRate: 10)
        let splits = [3.0, 6.0]
        #expect(map.clips(splitAt: splits) == [0..<3, 3..<6, 6..<10])
        let sequence = map.sequence(movingClip: 2, to: 0, splitAt: splits)
        #expect(sequence == [6..<10, 0..<3, 3..<6])
        #expect(self.map(sequence: sequence).clips(splitAt: splits) == [6..<10, 0..<3, 3..<6])
    }

    @Test func movingABackToSourceOrderEmptiesTheSequence() {
        let splits = [3.0, 6.0]
        let moved = map(sequence: [6..<10, 0..<3, 3..<6])
        #expect(moved.sequence(movingClip: 0, to: 2, splitAt: splits).isEmpty)
    }

    @Test func aPlaceIsAsFarAsTheDragIn() {
        #expect(EditorViewModel.clipTarget(from: 1, distance: 0, slot: 100, count: 4) == 1)
        #expect(EditorViewModel.clipTarget(from: 1, distance: 49, slot: 100, count: 4) == 1)
        #expect(EditorViewModel.clipTarget(from: 1, distance: 51, slot: 100, count: 4) == 2)
        #expect(EditorViewModel.clipTarget(from: 1, distance: -500, slot: 100, count: 4) == 0)
        #expect(EditorViewModel.clipTarget(from: 1, distance: 500, slot: 100, count: 4) == 3)
    }

    // MARK: What follows the map

    @Test func audioFadesAtEveryJump() {
        let fades = CompositionBuilder.audioFades(for: map(sequence: [6..<10, 0..<6]))
        let fade = CompositionBuilder.fadeDuration
        #expect(fades.map(\.fadesIn) == [true, false, true, false])
        #expect(fades.map(\.range.lowerBound).enumerated().allSatisfy { index, value in
            close(value, [0, 4 - fade, 4, 10 - fade][index])
        })
    }

    @Test func audioFadesAreUnchangedInSourceOrder() {
        let fades = CompositionBuilder.audioFades(for: TimeMap(cuts: [4..<5], sourceDuration: 10, frameRate: 10))
        #expect(fades.map(\.fadesIn) == [false, true])
    }

    @Test func subtitlesFollowTheOutputAndSplitAtAJump() {
        let cues = [cue("first", from: 0), cue("a b c", from: 5)]
        let entries = SubtitleFile.entries(for: cues, timeMap: map(sequence: [6..<10, 0..<6]))
        #expect(entries.map(\.text) == ["a b c", "first", "a b c"])
        #expect(entries.map(\.range) == [0..<2000, 4000..<5000, 9000..<10_000])
    }

    @Test func aZoomPulledApartIsAZoomInEachPlaceInOrder() {
        let zoom = ZoomSegment(range: 5..<7, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))
        let later = ZoomSegment(range: 1..<2, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))
        let output = RenderPlan.outputZooms([later, zoom], timeMap: map(sequence: [6..<10, 0..<6]))
        #expect(output.map(\.range) == [0..<1, 5..<6, 9..<10])
    }

    @Test func theLoopsGlideStaysInAShortLastClip() {
        // The clip before it is later in the source, which must not reach the glide
        let loop = RenderPlan.cursorLoop(for: map(cuts: [0.5..<5], sequence: [5..<10, 0..<0.5]))
        #expect(loop.glide.lowerBound == 0)
        #expect(close(loop.glide.upperBound, 0.4))
    }

    @Test func theLoopsGlideIsASecondInALongLastClip() {
        let loop = RenderPlan.cursorLoop(for: map(sequence: [5..<10, 0..<5]))
        #expect(close(loop.glide.lowerBound, 3.9))
        #expect(close(loop.glide.upperBound, 4.9))
    }

    @Test func theCursorHoldsOnlyThroughWhatPlaysAfterTheStop() throws {
        let map = map(sequence: [6..<10, 0..<6])
        let stop = try #require(RenderPlan.cursorStop(before: 2, for: map))
        // 2 s before the last frame at 9.9 s of output: source 3.9
        #expect(close(stop.time, 3.9))
        #expect(close(stop.held(5), 3.9))
        // Source 8 plays first, before the stop
        #expect(stop.held(8) == 8)
        #expect(stop.held(1) == 1)
    }
}

// MARK: - Projects

struct ClipOrderProjectTests {

    @Test func aProjectKeepsItsOrderAndAnOldOneHasNone() throws {
        var project = EditorProject()
        project.sequence = [2..<4, 0..<2]
        let decoded = try JSONDecoder().decode(EditorProject.self, from: JSONEncoder().encode(project))
        #expect(decoded.sequence == project.sequence)

        var saved = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        saved["sequence"] = nil
        let old = try JSONDecoder().decode(EditorProject.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(old.sequence.isEmpty)
    }
}

// MARK: - Rendering

struct ClipOrderRenderingTests {

    /// 4 s at 30 fps, each second at its own brightness.
    private func source() async throws -> EditorSource {
        let url = try temporaryFolder().appending(path: "video.mov")
        try await TestRecording.write(to: url, size: CGSize(width: 1280, height: 720), frameCount: 120, frameRate: 30) { UInt8(40 + $0 / 30 * 60) }
        return try await EditorSourceLoader.load(videoURL: url)
    }

    private func level(at time: Double, of composition: EditorComposition, at point: CGPoint) async throws -> Int {
        Int(try CameraPixels(try await FrameGrabber.image(of: composition, at: time, timescale: 600)).green(at: point))
    }

    @Test func theFramesPlayInTheNewOrder() async throws {
        let source = try await source()
        let plain = try await cameraFrames(of: source, project: plainProject())
        let point = plain.1.canvas.videoFrame.center
        let levels = [0.5, 1.5, 2.5, 3.5]
        var bySource: [Int] = []
        for time in levels {
            bySource.append(try await level(at: time, of: plain.0, at: point))
        }
        #expect(Set(bySource).count == 4)

        // Seconds 2 and 3 first, then 0 and 1
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.sequence = [2..<4, 0..<2] })
        #expect(plan.timeMap.outputDuration == 4)
        for (time, expected) in zip(levels, [bySource[2], bySource[3], bySource[0], bySource[1]]) {
            #expect(abs(try await level(at: time, of: composition, at: point) - expected) <= 2)
        }
    }

    @Test func anExportPlaysInTheNewOrder() async throws {
        let source = try await source()
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.sequence = [2..<4, 0..<2] })
        let url = try temporaryFolder().appending(path: "export.mp4")
        try await ExportService.export(composition, to: url, as: ExportSettings(format: .mp4)) { _ in }

        let exported = AVURLAsset(url: url)
        #expect(abs(try await exported.load(.duration).seconds - 4) < 0.1)
        let generator = AVAssetImageGenerator(asset: exported)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let point = plan.canvas.videoFrame.center
        var levels: [Int] = []
        for time in [0.5, 1.5, 2.5, 3.5] {
            let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            levels.append(Int(try CameraPixels(image).green(at: point)))
        }
        // Brighter second by second in the source, so seconds 2, 3, 0, 1 are in this order of brightness
        #expect(levels[2] < levels[3] && levels[3] < levels[0] && levels[0] < levels[1])
    }

    @Test func anOverlayMovesWithItsClip() async throws {
        let source = try await source()
        var style = TextOverlayStyle()
        style.text = ""
        style.backgroundColor = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        style.backgroundOpacity = 1
        let frame = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let overlay = VideoOverlay(range: 0.5..<1.5, frame: frame, kind: .text(style))
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject {
            $0.sequence = [2..<4, 0..<2]
            $0.overlays = [overlay]
        })
        let point = plan.canvas.videoFrame.center
        func isRed(_ time: Double) async throws -> Bool {
            let pixels = try CameraPixels(try await FrameGrabber.image(of: composition, at: time, timescale: 600))
            return pixels.red(at: point) > 170 && pixels.green(at: point) < 80
        }
        // Source 0.5..<1.5 plays at output 2.5..<3.5
        #expect(try await !isRed(1))
        #expect(try await isRed(3))
        #expect(try await !isRed(3.8))
    }

    @Test func anOverlayAcrossAJumpBuildsAndFadesInEachPlace() async throws {
        let source = try await source()
        let overlay = VideoOverlay(range: 1..<3, frame: VideoOverlay.defaultTextFrame, kind: .text(TextOverlayStyle()))
        let project = plainProject {
            $0.sequence = [2..<4, 0..<2]
            $0.overlays = [overlay]
        }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let planned = try #require(plan.overlays.first?.first)
        #expect(planned.outputs == [0..<1, 3..<4])
        #expect(abs(planned.opacity(atOutput: 3, frameDuration: 0)) < 0.001)
        #expect(planned.opacity(atOutput: 3.5, frameDuration: 0) == 1)
        #expect(abs(planned.opacity(atOutput: 1, frameDuration: 0)) < 0.001)
    }

    @Test func theCameraStaysInStepWithTheClips() async throws {
        let video = try await cameraTestRecording()
        // Bright only in its first 2 s
        try await addCamera(to: video, seconds: 4) { $0 < 60 ? 230 : 60 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.sequence = [2..<4, 0..<2] })
        let center = try #require(plan.bubble).rect.center
        #expect(try await cameraLevel(at: 1, center: center, of: composition) < 120)
        #expect(try await cameraLevel(at: 3, center: center, of: composition) > 170)
    }
}

private extension CameraPixels {
    func red(at point: CGPoint) -> UInt8 {
        bytes[(height - 1 - Int(point.y)) * width * 4 + Int(point.x) * 4]
    }
}
