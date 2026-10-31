//
//  RecordingImporterTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

struct RecordingImporterTests {

    private func movie(named name: String = "video.mov") async throws -> URL {
        let url = try temporaryFolder().appending(path: name)
        try await TestRecording.write(to: url, size: CGSize(width: 64, height: 64), frameCount: 3, frameRate: 30) { _ in 128 }
        return url
    }

    private func name(of file: String, among names: [String]) -> String {
        RecordingImporter.freeName(for: URL(filePath: "/elsewhere/\(file)"), among: names)
    }

    @Test func aFreeNameIsKept() {
        #expect(name(of: "demo.mp4", among: ["other.mov"]) == "demo.mp4")
    }

    @Test func aTakenNameIsNumbered() {
        #expect(name(of: "demo.mov", among: ["demo.mov"]) == "demo 2.mov")
        #expect(name(of: "demo.mov", among: ["demo.mov", "demo 2.mov"]) == "demo 3.mov")
    }

    @Test func anotherExtensionWouldShareTheCompanions() {
        #expect(name(of: "demo.mp4", among: ["demo.mov"]) == "demo 2.mp4")
        #expect(name(of: "demo.mp4", among: ["demo.edit.json"]) == "demo 2.mp4")
        #expect(name(of: "Demo.mp4", among: ["demo.mov"]) == "Demo 2.mp4")
    }

    @Test func aSimilarNameIsntTaken() {
        #expect(name(of: "demo.mov", among: ["demo2.mov", "my demo.mov"]) == "demo.mov")
    }

    @Test func namesTheLibraryWouldMisfileLoseTheirSuffix() {
        #expect(name(of: "demo.camera.mov", among: []) == "demo.mov")
        #expect(name(of: "demo-edited.mp4", among: []) == "demo.mp4")
    }

    @Test func itCopiesLeavingTheOriginalAndListsItAsNew() async throws {
        let original = try await movie()
        let old = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.creationDate: old], ofItemAtPath: original.path(percentEncoded: false))
        // Doesn't exist yet: importing makes it
        let folder = try temporaryFolder().appending(path: "Recordings")

        let copy = try await RecordingImporter.importMovie(at: original, into: folder)

        #expect(copy.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: original.path(percentEncoded: false)))
        #expect(FileManager.default.contentsEqual(atPath: original.path(percentEncoded: false), andPath: copy.path(percentEncoded: false)))
        let created = try #require(try copy.resourceValues(forKeys: [.creationDateKey]).creationDate)
        #expect(created > old.addingTimeInterval(1_000))
    }

    @Test func importingTwiceMakesTwoCopies() async throws {
        let original = try await movie()
        let folder = try temporaryFolder()
        let first = try await RecordingImporter.importMovie(at: original, into: folder)
        let second = try await RecordingImporter.importMovie(at: original, into: folder)
        #expect(first != second)
        #expect(second.lastPathComponent == "video 2.mov")
    }

    @Test func aFileAlreadyInTheFolderIsntCopied() async throws {
        let original = try await movie()
        let folder = original.deletingLastPathComponent()
        let opened = try await RecordingImporter.importMovie(at: original, into: folder)
        #expect(opened == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) == ["video.mov"])
    }

    @Test func aFileWithoutVideoIsRefusedAndNothingIsCopied() async throws {
        let file = try temporaryFolder().appending(path: "notes.mov")
        try Data("not a movie".utf8).write(to: file)
        let folder = try temporaryFolder()
        await #expect(throws: RecordingImporter.ImportError.self) {
            try await RecordingImporter.importMovie(at: file, into: folder)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).isEmpty)
    }

    @MainActor
    @Test func theLibraryOpensWhatItCanAndSaysWhatItCant() async throws {
        let good = try await movie()
        let bad = try temporaryFolder().appending(path: "bad.mov")
        try Data("nope".utf8).write(to: bad)
        let folder = try temporaryFolder()
        var opened: [URL] = []
        let viewModel = LibraryViewModel(
            folders: { LibraryFolders(recordings: folder, screenshots: folder, history: folder) },
            openMovie: { opened.append($0) }
        )

        await viewModel.importMovies([bad, good])

        #expect(opened.map(\.lastPathComponent) == ["video.mov"])
        #expect(viewModel.error?.contains("bad.mov") == true)
        #expect(viewModel.items?.map(\.name) == ["video"])
        #expect(viewModel.importsRunning == 0)
    }
}

// MARK: - A phone's video

struct RotatedVideoTests {

    /// 640×360 stored, its top half bright, with the turn a phone held upright writes.
    private func sidewaysVideo() async throws -> URL {
        let url = try temporaryFolder().appending(path: "phone.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 640, AVVideoHeightKey: 360])
        input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 360, ty: 0)
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 640, 360, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let frame = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(frame, [])
        let (bytes, rowBytes) = (CVPixelBufferGetBaseAddress(frame), CVPixelBufferGetBytesPerRow(frame))
        memset(bytes, 30, rowBytes * 360)
        memset(bytes, 230, rowBytes * 180)
        CVPixelBufferUnlockBaseAddress(frame, [])
        for index in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(frame, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 30))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 30, timescale: 30))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    @Test func itShowsUprightAsTheSystemShowsIt() async throws {
        let url = try await sidewaysVideo()
        let source = try await EditorSourceLoader.load(videoURL: url)
        #expect(source.naturalSize == CGSize(width: 360, height: 640))
        #expect(source.orientation == .right)

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        let system = try CameraPixels(try await generator.image(at: CMTime(value: 15, timescale: 30)).image)
        #expect(system.width == 360 && system.height == 640)

        let (composition, plan) = try await cameraFrames(of: source, project: plainProject())
        #expect(plan.canvas.size == CGSize(width: 360, height: 640))
        let ours = try CameraPixels(try await FrameGrabber.image(of: composition, at: 0.5, timescale: source.timescale))
        for point in [CGPoint(x: 90, y: 320), CGPoint(x: 270, y: 320), CGPoint(x: 90, y: 40), CGPoint(x: 270, y: 600)] {
            #expect(isCamera(system.green(at: point)) == isCamera(ours.green(at: point)))
        }
        // It's the turn that was tested, not a uniform frame: the two sides differ
        #expect(isCamera(ours.green(at: CGPoint(x: 270, y: 320))) != isCamera(ours.green(at: CGPoint(x: 90, y: 320))))
    }

    @Test func aCropIsOfTheFrameAsItShows() async throws {
        let url = try await sidewaysVideo()
        let source = try await EditorSourceLoader.load(videoURL: url)
        // The right half as it shows, which is bright
        let project = plainProject { $0.crop = CGRect(x: 0.5, y: 0, width: 0.5, height: 1) }
        let (composition, plan) = try await cameraFrames(of: source, project: project)
        #expect(plan.canvas.size.width == 180)
        let pixels = try CameraPixels(try await FrameGrabber.image(of: composition, at: 0.5, timescale: source.timescale))
        #expect(isCamera(pixels.green(at: CGPoint(x: 20, y: 320))) && isCamera(pixels.green(at: CGPoint(x: 160, y: 320))))
    }
}
