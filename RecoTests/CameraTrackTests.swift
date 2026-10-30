//
//  CameraTrackTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

// MARK: - Sidecars

struct CameraSidecarTests {

    @Test func loadsTheMovieAndItsOffset() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: 0.25)
        let footage = try #require(try await EditorSourceLoader.load(videoURL: video).camera)
        #expect(footage.offset == 0.25)
        #expect(footage.hasRecordedOffset)
        #expect(footage.displaySize == CGSize(width: 640, height: 480))
        #expect(abs(footage.timeRange.duration.seconds - 1) < 0.05)
    }

    @Test func aMissingSidecarStartsWithTheRecording() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: nil)
        let footage = try #require(try await EditorSourceLoader.load(videoURL: video).camera)
        #expect(footage.offset == 0)
        #expect(!footage.hasRecordedOffset)
    }

    @Test func aBadSidecarStartsWithTheRecording() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: nil)
        try Data("{not json".utf8).write(to: CameraFootage.sidecarURL(for: video))
        let footage = try #require(try await EditorSourceLoader.load(videoURL: video).camera)
        #expect(footage.offset == 0)
        #expect(!footage.hasRecordedOffset)
    }

    @Test func noMovieMeansNoFootage() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try CameraFootageStore.writeOffset(1, for: video)
        #expect(try await EditorSourceLoader.load(videoURL: video).camera == nil)
    }

    @Test func aBrokenMovieLeavesTheRecordingOpen() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try Data("not a movie".utf8).write(to: CameraFootage.movieURL(for: video))
        let source = try await EditorSourceLoader.load(videoURL: video)
        #expect(source.camera == nil)
        #expect(source.duration > 0)
    }

    @Test func installCopiesAFileWithOffsetZero() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: 3)
        let chosen = try temporaryFolder().appending(path: "chosen.mov")
        try await TestRecording.write(to: chosen, size: CGSize(width: 320, height: 240), frameCount: 60, frameRate: 30) { _ in cameraLevel }

        try await CameraFootageStore.install(chosen, for: video)

        let footage = try #require(try await EditorSourceLoader.load(videoURL: video).camera)
        #expect(footage.offset == 0)
        #expect(footage.hasRecordedOffset)
        #expect(footage.displaySize == CGSize(width: 320, height: 240))
        #expect(FileManager.default.fileExists(atPath: chosen.path(percentEncoded: false)))
        let names = try FileManager.default.contentsOfDirectory(atPath: video.deletingLastPathComponent().path(percentEncoded: false))
        #expect(names.sorted() == ["video.camera.json", "video.camera.mov", "video.mov"])
    }

    @Test func installRefusesAFileWithoutVideoAndKeepsTheFootage() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: 3)
        let chosen = try temporaryFolder().appending(path: "chosen.mov")
        try Data("not a movie".utf8).write(to: chosen)
        await #expect(throws: (any Error).self) {
            try await CameraFootageStore.install(chosen, for: video)
        }
        #expect(try await EditorSourceLoader.load(videoURL: video).camera?.offset == 3)
    }
}

// MARK: - Project

struct CameraProjectTests {

    @Test func anOldProjectGetsTheDefaults() throws {
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(EditorProject())) as? [String: Any])
        json["camera"] = nil
        let project = try JSONDecoder().decode(EditorProject.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(project.camera == CameraOverlayStyle())
    }

    @Test func theStyleRoundTrips() throws {
        var project = EditorProject()
        project.camera.center = CGPoint(x: 0.2, y: 0.3)
        project.camera.crop = CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        project.camera.timeOffset = -1.5
        #expect(try JSONDecoder().decode(EditorProject.self, from: JSONEncoder().encode(project)) == project)
    }

    @Test func aNewTakeKeepsTheStyleNotTheTiming() {
        var other = EditorProject()
        other.camera.size = 0.4
        other.camera.timeOffset = 2
        var mine = EditorProject()
        mine.camera.timeOffset = -1
        let styled = mine.styled(like: other)
        #expect(styled.camera.size == 0.4)
        #expect(styled.camera.timeOffset == -1)
    }

    @Test func theTabIsAlwaysAvailable() {
        #expect(InspectorTab.camera.isAvailable)
    }

    @MainActor @Test func aStoredCameraChoiceKeepsItsModeOnce() throws {
        let name = "CameraTrackTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        // Someone who had Presenter Overlay on
        defaults.set(true, forKey: "presenterOverlayEnabled")
        let existing = SettingsStore(defaults: defaults)
        #expect(existing.cameraEnabled)
        #expect(existing.cameraMode == .presenterOverlay)

        // Someone new, who turns the camera on later
        defaults.removeObject(forKey: "presenterOverlayEnabled")
        defaults.removeObject(forKey: "cameraMode")
        let new = SettingsStore(defaults: defaults)
        #expect(!new.cameraEnabled)
        #expect(new.cameraMode == .track)
        new.cameraEnabled = true
        #expect(defaults.bool(forKey: "presenterOverlayEnabled"))
        #expect(SettingsStore(defaults: defaults).cameraMode == .track)
    }
}

// MARK: - Geometry

struct CameraBubbleGeometryTests {

    private let frame = CGRect(x: 100, y: 50, width: 1000, height: 500)

    @Test func theBubbleIsAShareOfTheShorterSide() {
        var style = CameraOverlayStyle()
        style.size = 0.2
        style.center = CGPoint(x: 0.5, y: 0.5)
        #expect(CameraBubbleLayout.rect(of: style, in: frame) == CGRect(x: 550, y: 250, width: 100, height: 100))
    }

    @Test func centreIsFromTheTopLeft() {
        var style = CameraOverlayStyle()
        style.size = 0.2
        style.center = CGPoint(x: 0.25, y: 0.25)
        // A quarter down from the top is high in Core Image's space
        #expect(CameraBubbleLayout.rect(of: style, in: frame).midY == 50 + 500 * 0.75)
    }

    @Test func itStaysWholeInsideTheVideo() {
        var style = CameraOverlayStyle()
        style.size = 0.5
        style.center = CGPoint(x: 2, y: -1)
        let rect = CameraBubbleLayout.rect(of: style, in: frame)
        #expect(frame.contains(rect))
        #expect(rect.maxX == frame.maxX)
        #expect(rect.maxY == frame.maxY)
    }

    @Test(arguments: CameraOverlayStyle.Corner.allCases)
    func aCornerSitsTheMarginFromItsEdges(corner: CameraOverlayStyle.Corner) {
        var style = CameraOverlayStyle()
        style.size = 0.2
        style.center = CameraBubbleLayout.center(of: corner, size: style.size, in: frame.size)
        let rect = CameraBubbleLayout.rect(of: style, in: frame)
        let margin = CameraBubbleLayout.margin * 500
        let horizontal = min(rect.minX - frame.minX, frame.maxX - rect.maxX)
        let vertical = min(rect.minY - frame.minY, frame.maxY - rect.maxY)
        #expect(abs(horizontal - margin) <= 1)
        #expect(abs(vertical - margin) <= 1)
    }

    @Test func aZoomShrinksDownToALimit() {
        #expect(CameraBubbleLayout.shrink(atZoom: 1) == 1)
        #expect(abs(CameraBubbleLayout.shrink(atZoom: 1.5) - 0.8) < 1e-9)
        #expect(CameraBubbleLayout.shrink(atZoom: 2) == CameraBubbleLayout.smallestShrink)
        #expect(CameraBubbleLayout.shrink(atZoom: 8) == CameraBubbleLayout.smallestShrink)
    }

    @Test func shrinkingKeepsToTheNearestCorner() {
        let rect = CGRect(x: 1000, y: 60, width: 90, height: 90)
        #expect(CameraBubbleLayout.placement(of: rect, scale: 1, in: frame) == CGAffineTransform(translationX: 1000, y: 60))
        let shrunk = CGRect(x: 0, y: 0, width: 90, height: 90).applying(CameraBubbleLayout.placement(of: rect, scale: 0.5, in: frame))
        #expect(shrunk.width == 45)
        // The bottom-right corner: half as far from it as before
        #expect(frame.maxX - shrunk.maxX == (frame.maxX - rect.maxX) / 2)
        #expect(shrunk.minY - frame.minY == (rect.minY - frame.minY) / 2)
    }

    @Test func theViewRectFlipsAndScales() {
        let rect = CGRect(x: 100, y: 0, width: 200, height: 200)
        let view = CameraBubbleLayout.viewRect(of: rect, canvas: CGSize(width: 1000, height: 1000), viewSize: CGSize(width: 500, height: 500))
        #expect(view == CGRect(x: 50, y: 400, width: 100, height: 100))
    }

    @Test func aDragMovesItAsFarAsThePointer() {
        let share = CameraBubbleLayout.videoShare(
            of: CGSize(width: 60, height: -30), viewSize: CGSize(width: 600, height: 300), canvas: CGSize(width: 1200, height: 600), videoSize: frame.size
        )
        // 60 view points are 120 canvas pixels, 12% of a 1000 pixel wide video
        #expect(abs(share.width - 0.12) < 1e-9)
        #expect(abs(share.height + 0.12) < 1e-9)
    }

    @Test func orientationsFollowTheTrack() {
        #expect(CameraFootage.orientation(of: .identity) == .up)
        #expect(CameraFootage.orientation(of: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)) == .right)
        #expect(CameraFootage.orientation(of: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 1920)) == .left)
        #expect(CameraFootage.orientation(of: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 1920, ty: 1080)) == .down)
    }

    private func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 600) }
    private func range(_ start: Double, _ end: Double) -> CMTimeRange { CMTimeRange(start: time(start), end: time(end)) }

    @Test func aSpanIsWhatTheFootageCovers() throws {
        let inside = try #require(CompositionBuilder.cameraSpan(of: range(0, 4), duration: time(4), footage: range(1, 2)))
        #expect(inside == .init(lead: time(1), shown: range(1, 2), length: time(1)))
        let late = try #require(CompositionBuilder.cameraSpan(of: range(2, 4), duration: time(2), footage: range(0, 3)))
        #expect(late == .init(lead: .zero, shown: range(2, 3), length: time(1)))
        #expect(CompositionBuilder.cameraSpan(of: range(0, 1), duration: time(1), footage: range(2, 3)) == nil)
        #expect(CompositionBuilder.cameraSpan(of: range(0, 1), duration: time(1), footage: range(1, 3)) == nil)
    }

    @Test func aSpanRunsAtThePiecesSpeed() throws {
        let span = try #require(CompositionBuilder.cameraSpan(of: range(0, 4), duration: time(2), footage: range(1, 3)))
        #expect(abs(span.lead.seconds - 0.5) < 1e-6)
        #expect(abs(span.length.seconds - 1) < 1e-6)
        #expect(span.shown == range(1, 3))
    }
}

// MARK: - The camera's file

struct CameraFileWriterTests {

    private func grey(_ level: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32BGRA, nil, &buffer)
        let image = try #require(buffer)
        CVPixelBufferLockBaseAddress(image, [])
        memset(CVPixelBufferGetBaseAddress(image), Int32(level), CVPixelBufferGetDataSize(image))
        CVPixelBufferUnlockBaseAddress(image, [])
        return image
    }

    private func host(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 1_000_000_000) }

    /// Appends 30 fps frames over `range` host seconds, giving a real-time input time to take them.
    private func feed(_ writer: CameraFileWriter, _ range: Range<Double>, level: UInt8) async throws {
        var time = range.lowerBound
        while time < range.upperBound {
            writer.append(try grey(level), at: host(time))
            try await Task.sleep(for: .milliseconds(3))
            time += 1.0 / 30
        }
    }

    private func newWriter() throws -> (CameraFileWriter, URL) {
        let url = try temporaryFolder().appending(path: "take.camera.mov")
        return (CameraFileWriter(url: url) { Issue.record($0) }, url)
    }

    @Test func aPauseIsCutFromTheFile() async throws {
        let (writer, url) = try newWriter()
        try await feed(writer, 100..<101, level: 40)
        writer.pause(at: host(101))
        try await feed(writer, 101..<103, level: 128)
        writer.resume(at: host(103))
        try await feed(writer, 103..<104, level: 230)
        let take = try #require(await writer.finish())

        #expect(take.movie == url)
        #expect(take.firstFrame == host(100))
        #expect(take.pauses.count == 1)
        let asset = AVURLAsset(url: url)
        #expect(abs(try await asset.load(.duration).seconds - 2) < 0.1)

        // What comes after the pause sits right after what came before it, and nothing from the pause is kept
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let center = CGPoint(x: 160, y: 120)
        let before = try CameraPixels(try await generator.image(at: CMTime(seconds: 0.9, preferredTimescale: 600)).image).green(at: center)
        let after = try CameraPixels(try await generator.image(at: CMTime(seconds: 1.2, preferredTimescale: 600)).image).green(at: center)
        #expect(before < 80)
        #expect(after > 170)
    }

    @Test func framesInAPauseBeforeTheFirstOneDontShiftTheFile() async throws {
        let (writer, url) = try newWriter()
        writer.pause(at: host(99))
        try await feed(writer, 100..<101, level: 128)
        writer.resume(at: host(101))
        try await feed(writer, 101..<102, level: 230)
        let take = try #require(await writer.finish())
        #expect(take.firstFrame == host(101))
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        #expect(abs(try await track.load(.timeRange).start.seconds) < 0.05)
        #expect(abs(try await track.load(.timeRange).duration.seconds - 1) < 0.1)
    }

    @Test func noFramesLeavesNothing() async throws {
        let (writer, url) = try newWriter()
        #expect(await writer.finish() == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func cancelRemovesTheFile() async throws {
        let (writer, url) = try newWriter()
        try await feed(writer, 100..<100.3, level: 128)
        writer.cancel()
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        // Late frames from the capture queue go nowhere
        writer.append(try grey(128), at: host(101))
        #expect(await writer.finish() == nil)
    }

    @Test func aWriterThatCantWriteReportsOnceAndKeepsGoing() async throws {
        let url = URL(filePath: "/nonexistent-\(UUID().uuidString)/take.camera.mov")
        let failures = Failures()
        let writer = CameraFileWriter(url: url) { _ in failures.add() }
        try await feed(writer, 100..<100.2, level: 128)
        #expect(failures.count == 1)
        #expect(await writer.finish() == nil)
    }

    private final class Failures: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        var count: Int { lock.withLock { value } }

        func add() { lock.withLock { value += 1 } }
    }

    private func take(first: Double, pauses: [Range<Double>] = []) -> CameraTake {
        CameraTake(movie: URL(filePath: "/take"), firstFrame: host(first), pauses: pauses.map { host($0.lowerBound)..<host($0.upperBound) })
    }

    @Test func theOffsetIsFirstFrameMinusScreenStart() {
        #expect(take(first: 101.5).offset(screenStart: host(100)) == 1.5)
        // The usual case: the camera is started first
        #expect(take(first: 99).offset(screenStart: host(100)) == -1)
    }

    @Test func theOffsetLeavesOutPausesBetweenThem() {
        // The screen started, was paused for 2 s, and the camera's first frame came after
        #expect(take(first: 104, pauses: [101..<103]).offset(screenStart: host(100)) == 2)
        // A pause after both starts changes nothing
        #expect(take(first: 100.5, pauses: [101..<103]).offset(screenStart: host(100)) == 0.5)
        // A pause before the screen's first sample, which its writer forgot, changes nothing either
        #expect(take(first: 95, pauses: [90..<92]).offset(screenStart: host(100)) == -5)
        // A pause only the camera saw, before the screen's first sample: it's cut from the camera's file alone
        #expect(take(first: 95, pauses: [96..<98]).offset(screenStart: host(100)) == -3)
    }
}

// MARK: - Files

struct CameraFilesTests {

    @Test func aRenameCarriesTheCameraFiles() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1, offset: 0.5)
        let renamed = try await RecordingRenamer.rename(video, to: "Demo")
        #expect(FileManager.default.fileExists(atPath: CameraFootage.movieURL(for: renamed).path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: CameraFootage.sidecarURL(for: renamed).path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: CameraFootage.movieURL(for: video).path(percentEncoded: false)))
        #expect(try await EditorSourceLoader.load(videoURL: renamed).camera?.offset == 0.5)
    }

    @Test func aRecordingCantTakeACameraFilesName() {
        #expect(RecordingRename.problem(with: "Demo.camera") != nil)
        #expect(RecordingRename.problem(with: "Demo camera") == nil)
    }

    @Test func theCameraFileNamesFollowTheRecording() {
        let video = URL(filePath: "/folder/Take.mp4")
        #expect(CameraFootage.movieURL(for: video).lastPathComponent == "Take.camera.mov")
        #expect(CameraFootage.sidecarURL(for: video).lastPathComponent == "Take.camera.json")
    }

    @Test func theLibraryListsARecordingOnce() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let folder = video.deletingLastPathComponent()
        let items = try await LibraryStore.items(recordings: folder, screenshots: folder, history: try temporaryFolder())
        #expect(items.map(\.url.lastPathComponent) == ["video.mov"])
    }

    @Test func trashingARecordingTakesTheCameraFiles() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let item = LibraryItem(url: video, kind: .recording, date: .now)
        let removed = Removed()
        try await LibraryStore.trash(item) { removed.add($0) }
        #expect(removed.names.sorted() == ["video.camera.json", "video.camera.mov", "video.mov"])
    }

    private final class Removed: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []

        var names: [String] { lock.withLock { urls.map(\.lastPathComponent) } }

        func add(_ url: URL) { lock.withLock { urls.append(url) } }
    }
}
