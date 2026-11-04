//
//  CameraTestSupport.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import Testing
@testable import Reco

/// Grey levels in the generated videos: a dark recording, so the bubble's bright frames stand out.
let screenLevel: UInt8 = 30
let cameraLevel: UInt8 = 230

func isScreen(_ level: UInt8) -> Bool { level < 80 }
func isCamera(_ level: UInt8) -> Bool { level > 170 }

/// A 4 s, 30 fps, 1280×720 dark recording in a new folder.
func cameraTestRecording(frames: Int = 120) async throws -> URL {
    let url = try temporaryFolder().appending(path: "video.mov")
    try await TestRecording.write(to: url, size: CGSize(width: 1280, height: 720), frameCount: frames, frameRate: 30) { _ in screenLevel }
    return url
}

/// Writes camera footage beside the recording at `video`, with its sidecar when `offset` isn't `nil`.
func addCamera(
    to video: URL, seconds: Double = 4, offset: Double? = 0, level: @escaping (Int) -> UInt8 = { _ in cameraLevel }
) async throws {
    try await TestRecording.write(
        to: CameraFootage.movieURL(for: video), size: CGSize(width: 640, height: 480), frameCount: Int(seconds * 30), frameRate: 30, level: level
    )
    if let offset {
        try CameraFootageStore.writeOffset(offset, for: video)
    }
}

/// A project on a plain canvas with a square bubble, so a corner of the bubble is footage.
func plainProject(_ change: (inout EditorProject) -> Void = { _ in }) -> EditorProject {
    var project = EditorProject()
    project.canvas = .plain
    project.camera.shadow = 0
    change(&project)
    return project
}

/// A frame's pixels, read in Core Image's bottom-left coordinates.
struct CameraPixels {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    init(_ image: CGImage) throws {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    func green(at point: CGPoint) -> UInt8 {
        bytes[(height - 1 - Int(point.y)) * width * 4 + Int(point.x) * 4 + 1]
    }
}

/// The real path: the composition drawn by its compositor, as the player and export draw it.
func cameraFrames(of source: EditorSource, project: EditorProject) async throws -> (EditorComposition, RenderPlan) {
    let plan = await RenderPlan.build(project: project, source: source, resources: .none)
    let composition = try await CompositionBuilder.composition(for: source, plan: plan, audio: project.audio)
    return (composition, plan)
}

func cameraLevel(at time: Double, center: CGPoint, of composition: EditorComposition) async throws -> UInt8 {
    try CameraPixels(try await FrameGrabber.image(of: composition, at: time, timescale: 600)).green(at: center)
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
