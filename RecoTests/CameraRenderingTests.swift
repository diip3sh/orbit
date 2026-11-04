//
//  CameraRenderingTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

// MARK: - Rendering

struct CameraRenderingTests {

    @Test func theBubbleShowsTheCameraAndTheRestTheRecording() async throws {
        let video = try await cameraTestRecording(frames: 60)
        try await addCamera(to: video, seconds: 2)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject())
        let bubble = try #require(plan.bubble)

        // Bottom right by default
        #expect(bubble.rect.midX > plan.canvas.videoFrame.midX)
        #expect(bubble.rect.midY < plan.canvas.videoFrame.midY)
        let pixels = try CameraPixels(try await FrameGrabber.image(of: composition, at: 1, timescale: source.timescale))
        #expect(isCamera(pixels.green(at: bubble.rect.center)))
        #expect(isScreen(pixels.green(at: CGPoint(x: 100, y: 600))))
        // A circle by default, so its bounding square's corner is the recording
        #expect(isScreen(pixels.green(at: CGPoint(x: bubble.rect.minX + 3, y: bubble.rect.minY + 3))))
    }

    @Test func aSquareBubbleFillsItsCorners() async throws {
        let video = try await cameraTestRecording(frames: 60)
        try await addCamera(to: video, seconds: 2)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.camera.roundness = 0 })
        let rect = try #require(plan.bubble).rect
        let pixels = try CameraPixels(try await FrameGrabber.image(of: composition, at: 1, timescale: source.timescale))
        #expect(isCamera(pixels.green(at: CGPoint(x: rect.minX + 3, y: rect.minY + 3))))
        #expect(isScreen(pixels.green(at: CGPoint(x: rect.minX - 3, y: rect.minY + 3))))
    }

    @Test func hiddenFootageIsLeftOutOfTheComposition() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let shown = try await cameraFrames(of: source, project: plainProject())
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.camera.isEnabled = false })

        #expect(plan.bubble == nil)
        #expect(try await composition.asset.loadTracks(withMediaType: .video).count == 1)
        #expect(try await shown.0.asset.loadTracks(withMediaType: .video).count == 2)
        #expect(!plan.playsInComposition(of: shown.1))
        let center = try #require(shown.1.bubble).rect.center
        #expect(isScreen(try await cameraLevel(at: 0.5, center: center, of: composition)))
    }

    @Test func lateFootageHidesBeforeItStartsAndAfterItEnds() async throws {
        let video = try await cameraTestRecording()
        try await addCamera(to: video, seconds: 1, offset: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject())
        let center = try #require(plan.bubble).rect.center

        // Black would read as a dark bubble, so the recording must be there: not 0
        let before = try await cameraLevel(at: 0.5, center: center, of: composition)
        #expect(isScreen(before))
        #expect(before > 10)
        #expect(isCamera(try await cameraLevel(at: 1.5, center: center, of: composition)))
        let after = try await cameraLevel(at: 2.5, center: center, of: composition)
        #expect(isScreen(after))
        #expect(after > 10)
    }

    @Test func footageRunningFirstLinesUpByItsOffset() async throws {
        let video = try await cameraTestRecording()
        // Bright from 1 s into the file, which started 0.5 s before the recording: bright from 0.5 s
        try await addCamera(to: video, seconds: 4, offset: -0.5) { $0 < 30 ? 90 : 240 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject())
        let center = try #require(plan.bubble).rect.center
        let early = try await cameraLevel(at: 0.4, center: center, of: composition)
        #expect(early > 60 && early < 150)
        #expect(try await cameraLevel(at: 0.6, center: center, of: composition) > 200)
        // The file ends 3.5 s in
        #expect(isScreen(try await cameraLevel(at: 3.7, center: center, of: composition)))
    }

    @Test func theUserOffsetMovesTheFootage() async throws {
        let video = try await cameraTestRecording()
        try await addCamera(to: video, seconds: 1, offset: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let moved = plainProject { $0.camera.timeOffset = 1 }
        let (composition, plan) = try await cameraFrames(of: source, project: moved)
        let unmoved = await RenderPlan.build(project: plainProject(), source: source, resources: .none)
        #expect(!plan.playsInComposition(of: unmoved))
        let center = try #require(plan.bubble).rect.center
        #expect(isScreen(try await cameraLevel(at: 1.5, center: center, of: composition)))
        #expect(isCamera(try await cameraLevel(at: 2.5, center: center, of: composition)))
    }

    @Test func styleOnlyEditsKeepTheComposition() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let first = await RenderPlan.build(project: plainProject(), source: source, resources: .none)
        let second = await RenderPlan.build(project: plainProject { $0.camera.size = 0.4 }, source: source, resources: .none)
        #expect(second.playsInComposition(of: first))
    }

    @Test func aCutStaysInStep() async throws {
        let video = try await cameraTestRecording()
        // On the recording's timeline, footage from 1 s to 2 s
        try await addCamera(to: video, seconds: 1, offset: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        // Source 0.5 to 1.5 cut: 1.5 to 2 shows at output 0.5 to 1
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject { $0.cuts = [0.5..<1.5] })
        let center = try #require(plan.bubble).rect.center
        #expect(isScreen(try await cameraLevel(at: 0.3, center: center, of: composition)))
        #expect(isCamera(try await cameraLevel(at: 0.75, center: center, of: composition)))
        #expect(isScreen(try await cameraLevel(at: 1.5, center: center, of: composition)))
    }

    @Test func aSpeedChangeStaysInStep() async throws {
        let video = try await cameraTestRecording()
        // From 1 s to 3 s on the recording's timeline, with its brightness changing at 2 s
        try await addCamera(to: video, seconds: 2, offset: 1) { $0 < 30 ? 240 : 110 }
        let source = try await EditorSourceLoader.load(videoURL: video)
        // Source 1 to 3 at 2×: output 1 to 1.5 is the bright half, 1.5 to 2 the other, then nothing
        let project = plainProject { $0.speeds = [SpeedRange(range: 1..<3, rate: 2)] }
        let (composition, plan) = try await cameraFrames(of: source, project: project)
        let center = try #require(plan.bubble).rect.center
        #expect(isScreen(try await cameraLevel(at: 0.9, center: center, of: composition)))
        #expect(try await cameraLevel(at: 1.4, center: center, of: composition) > 200)
        let slower = try await cameraLevel(at: 1.6, center: center, of: composition)
        #expect(slower > 80 && slower < 160)
        #expect(isScreen(try await cameraLevel(at: 2.2, center: center, of: composition)))
    }

    @Test func footageThatWentMissingLeavesTheRecording() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        try FileManager.default.removeItem(at: CameraFootage.movieURL(for: video))
        let (composition, _) = try await cameraFrames(of: source, project: plainProject())
        #expect(isScreen(try await cameraLevel(at: 0.5, center: CGPoint(x: 100, y: 600), of: composition)))
    }

    // MARK: Drawn directly, for what flat footage can't show

    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// A plan without footage files' timing, for a 640×360 canvas.
    private func plan(project: EditorProject) async throws -> RenderPlan {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        return await RenderPlan.build(project: project, source: try await EditorSourceLoader.load(videoURL: video), resources: .none)
    }

    /// A camera frame red on the left half and blue on the right.
    private var splitCamera: CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 320, y: 0, width: 320, height: 480))
            .composited(over: CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 480)))
    }

    /// Red, green and blue at `point`, drawn with `camera` over a black frame at `time`.
    private func color(at point: CGPoint, camera: CIImage, time: Double = 0.5, plan: RenderPlan) throws -> [UInt8] {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, Int(plan.canvas.size.width), Int(plan.canvas.size.height), kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer
        )
        let output = try #require(buffer)
        let black = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: plan.videoSize))
        try FrameRenderer.draw(black, camera: camera, at: time, plan: plan, into: output, context: Self.context)
        CVPixelBufferLockBaseAddress(output, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(output, .readOnly) }
        let row = CVPixelBufferGetHeight(output) - 1 - Int(point.y)
        let bytes = try #require(CVPixelBufferGetBaseAddress(output)).advanced(by: row * CVPixelBufferGetBytesPerRow(output) + Int(point.x) * 4)
            .assumingMemoryBound(to: UInt8.self)
        return [bytes[2], bytes[1], bytes[0]]
    }

    @Test(arguments: [false, true])
    func mirroringSwapsTheSides(isMirrored: Bool) async throws {
        let plan = try await plan(project: plainProject {
            $0.camera.isMirrored = isMirrored
            $0.camera.roundness = 0
        })
        let rect = try #require(plan.bubble).rect
        let left = try color(at: CGPoint(x: rect.minX + rect.width / 4, y: rect.midY), camera: splitCamera, plan: plan)
        let right = try color(at: CGPoint(x: rect.maxX - rect.width / 4, y: rect.midY), camera: splitCamera, plan: plan)
        #expect(left[isMirrored ? 2 : 0] > 200)
        #expect(right[isMirrored ? 0 : 2] > 200)
    }

    @Test func theCropChoosesWhatFills() async throws {
        let plan = try await plan(project: plainProject {
            $0.camera.isMirrored = false
            $0.camera.crop = CGRect(x: 0.6, y: 0, width: 0.4, height: 1)
        })
        let center = try #require(plan.bubble).rect.center
        #expect(try color(at: center, camera: splitCamera, plan: plan)[2] > 200)
    }

    @Test func aZoomShrinksTheBubble() async throws {
        let zoom = ZoomSegment(range: 0..<1, scale: 2, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))
        let plan = try await plan(project: plainProject {
            $0.zooms = [zoom]
            $0.camera.roundness = 0
            $0.camera.isMirrored = false
        })
        let rect = try #require(plan.bubble).rect
        let time = 0.6
        let scale = plan.camera.viewport(at: time).scale
        #expect(scale > 1.5)
        // The rest of the frame is black here, so the bubble's top-left corner at rest shows it has moved in
        let corner = CGPoint(x: rect.minX + 2, y: rect.maxY - 2)
        #expect(try color(at: corner, camera: splitCamera, time: time, plan: plan) == [0, 0, 0])
        #expect(try color(at: CGPoint(x: rect.maxX - 2, y: rect.minY + 2), camera: splitCamera, time: time, plan: plan)[2] > 200)
    }

    @Test func theShadowDarkensAroundTheBubble() async throws {
        let video = try temporaryFolder().appending(path: "bright.mov")
        try await TestRecording.write(to: video, size: CGSize(width: 1280, height: 720), frameCount: 30, frameRate: 30) { _ in 200 }
        try await addCamera(to: video, seconds: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let plain = try await cameraFrames(of: source, project: plainProject { $0.camera.center = CGPoint(x: 0.5, y: 0.5) })
        let shadowed = try await cameraFrames(of: source, project: plainProject {
            $0.camera.center = CGPoint(x: 0.5, y: 0.5)
            $0.camera.shadow = 1
        })
        // Just under the bubble, where the shadow falls
        let rect = try #require(plain.1.bubble).rect
        let below = CGPoint(x: rect.midX, y: rect.minY - 6)
        let without = try await cameraLevel(at: 0.5, center: below, of: plain.0)
        let with = try await cameraLevel(at: 0.5, center: below, of: shadowed.0)
        #expect(Int(with) < Int(without) - 20)
    }

    // MARK: HDR

    /// Footage as the recorder writes it: through ``CameraFileWriter``, from frames tagged as a camera's are.
    private func writeTaggedCamera(to movie: URL, level: UInt8, frames: Int) async throws {
        let writer = CameraFileWriter(url: movie) { Issue.record($0) }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32BGRA, nil, &buffer)
        let image = try #require(buffer)
        CVPixelBufferLockBaseAddress(image, [])
        memset(CVPixelBufferGetBaseAddress(image), Int32(level), CVPixelBufferGetDataSize(image))
        CVPixelBufferUnlockBaseAddress(image, [])
        CVBufferSetAttachment(image, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(image, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(image, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        for index in 0..<frames {
            writer.append(image, at: CMTime(value: CMTimeValue(100 * 30 + index), timescale: 30))
            try await Task.sleep(for: .milliseconds(3))
        }
        _ = try #require(await writer.finish())
    }

    @Test(arguments: [false, true])
    func anSDRBubbleKeepsItsBrightnessInAnHDRVideo(tagged: Bool) async throws {
        let url = try temporaryFolder().appending(path: "hdr.mov")
        try await TestRecording.write(to: url, size: CGSize(width: 1280, height: 720), frameCount: 30, frameRate: 30, hdr: true) { _ in 128 }
        if tagged {
            try await writeTaggedCamera(to: CameraFootage.movieURL(for: url), level: 255, frames: 30)
            try CameraFootageStore.writeOffset(0, for: url)
        } else {
            try await addCamera(to: url, seconds: 1) { _ in 255 }
        }
        let source = try await EditorSourceLoader.load(videoURL: url)
        #expect(source.dynamicRange == .pq)
        let (composition, plan) = try await cameraFrames(of: source, project: plainProject())
        #expect(plan.dynamicRange == .pq)
        let center = try #require(plan.bubble).rect.center

        // Through the HDR compositor, read unconverted in its half-float output
        let reader = try AVAssetReader(asset: composition.asset)
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: try await composition.asset.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
        )
        output.videoComposition = composition.videoComposition
        reader.add(output)
        #expect(reader.startReading())
        defer { reader.cancelReading() }
        var values: [Float] = []
        for _ in 0..<5 {
            let sample = try #require(output.copyNextSampleBuffer())
            let frame = try #require(CMSampleBufferGetImageBuffer(sample))
            values.append(CIImage(cvPixelBuffer: frame, options: [.colorSpace: NSNull()]).values(at: center)[0])
        }
        // SDR white in PQ is about 0.58 of full scale; unconverted it'd be 1, as bright as PQ goes. AVFoundation leaves
        // the first frame it delivers unconverted (see PlannedBubble.image(of:in:)), so that one isn't held to it
        for value in values.dropFirst() {
            #expect(value > 0.4 && value < 0.75, "\(value)")
        }
    }
}

// MARK: - Export

struct CameraExportTests {

    @MainActor private func export(_ project: EditorProject, settings: ExportSettings, of source: EditorSource) async throws -> (URL, RenderPlan) {
        let frameRate = settings.outputFrameRate(recordingRate: source.frameRate)
        let target = RenderTarget(shorterSide: settings.resolution.map { CGFloat($0) }, frameRate: frameRate, keepsHDR: settings.keepsHDR)
        let plan = await RenderPlan.build(project: project, source: source, resources: .none, target: target)
        var composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
        composition.videoComposition = CompositionBuilder.videoComposition(for: source, plan: plan, frameRate: frameRate)
        let url = try temporaryFolder().appending(path: settings.format == .gif ? "out.gif" : "out.mp4")
        try await ExportService.export(composition, to: url, as: settings) { _ in }
        return (url, plan)
    }

    private func level(of url: URL, at time: Double, point: CGPoint) async throws -> UInt8 {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try CameraPixels(try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image).green(at: point)
    }

    @Test func anExportHasTheDurationAndPixels() async throws {
        let video = try await cameraTestRecording()
        try await addCamera(to: video, seconds: 1, offset: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        // 3.5 s of output: footage from source 1 to 2, output 0.5 to 1.5
        let (url, plan) = try await export(plainProject { $0.cuts = [0.5..<1] }, settings: ExportSettings(), of: source)
        let asset = AVURLAsset(url: url)
        #expect(abs(try await asset.load(.duration).seconds - plan.timeMap.outputDuration) < 0.05)
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        let center = try #require(plan.bubble).rect.center
        #expect(isScreen(try await level(of: url, at: 0.2, point: center)))
        #expect(isCamera(try await level(of: url, at: 1, point: center)))
        #expect(isScreen(try await level(of: url, at: 2.5, point: center)))
        #expect(isScreen(try await level(of: url, at: 1, point: CGPoint(x: 100, y: 600))))
    }

    @Test func anExportAtAnotherSizeAndFrameRateKeepsTheBubble() async throws {
        let video = try await cameraTestRecording()
        try await addCamera(to: video, seconds: 4)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let project = plainProject()
        let native = await RenderPlan.build(project: project, source: source, resources: .none)
        let (url, plan) = try await export(project, settings: ExportSettings(resolution: 360, frameRate: 15), of: source)

        #expect(plan.canvas.size.height == 360)
        let (rect, nativeRect) = (try #require(plan.bubble).rect, try #require(native.bubble).rect)
        #expect(abs(rect.width / nativeRect.width - 0.5) < 0.01)
        #expect(abs(rect.midX / plan.canvas.size.width - nativeRect.midX / native.canvas.size.width) < 0.01)

        let asset = AVURLAsset(url: url)
        #expect(abs(try await asset.load(.duration).seconds - 4) < 0.1)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(abs(try await track.load(.nominalFrameRate) - 15) < 1)
        #expect(isCamera(try await level(of: url, at: 2, point: rect.center)))
        #expect(isScreen(try await level(of: url, at: 2, point: CGPoint(x: 50, y: 300))))
    }

    @Test func aGIFHasTheBubble() async throws {
        let video = try await cameraTestRecording(frames: 30)
        try await addCamera(to: video, seconds: 1)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let (url, plan) = try await export(plainProject(), settings: ExportSettings(format: .gif, resolution: 180, frameRate: 15), of: source)
        let gif = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(gif) >= 1)
        let frame = try #require(CGImageSourceCreateImageAtIndex(gif, 0, nil))
        let pixels = try CameraPixels(frame)
        #expect(isCamera(pixels.green(at: try #require(plan.bubble).rect.center)))
        #expect(isScreen(pixels.green(at: CGPoint(x: 20, y: 150))))
    }
}
