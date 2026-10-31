//
//  VideoOverlayTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Reco

// MARK: - Lanes

struct VideoOverlayLaneTests {

    private func overlay(_ range: Range<Double>, lane: Int = 0) -> VideoOverlay {
        VideoOverlay(range: range, lane: lane, frame: VideoOverlay.defaultTextFrame, kind: .text(TextOverlayStyle()))
    }

    @Test func aNewOverlayTakesTheLowestLaneWithRoom() throws {
        let overlays = [overlay(0..<3), overlay(0..<3, lane: 1)]
        let placement = try #require(overlays.placement(at: 1, length: 2, duration: 10))
        #expect(placement.lane == 2)
        #expect(placement.range == 1..<3)
    }

    @Test func aFreeStretchOnALowLaneIsUsedAgain() throws {
        let placement = try #require([overlay(0..<3), overlay(0..<9, lane: 1)].placement(at: 4, length: 2, duration: 10))
        #expect(placement.lane == 0)
    }

    @Test func threeTakenLanesLeaveNoRoom() {
        let overlays = (0..<VideoOverlay.laneCount).map { overlay(0..<3, lane: $0) }
        #expect(overlays.placement(at: 1, length: 2, duration: 10) == nil)
    }

    @Test func aMoveStopsAtItsNeighbourOnItsLaneOnly() {
        let moved = overlay(0..<2)
        let overlays = [moved, overlay(3..<5), overlay(2..<4, lane: 1)]
        let result = overlays.movingOnLane(moved.id, by: 5, duration: 10)
        #expect(result.first { $0.id == moved.id }?.range == 1..<3)
    }

    @Test func resizingStopsAtTheNeighbours() {
        let resized = overlay(3..<5)
        let overlays = [overlay(0..<2), resized, overlay(6..<8)]
        #expect(overlays.movingStartOnLane(of: resized.id, to: 1).first { $0.id == resized.id }?.range == 2..<5)
        #expect(overlays.movingEndOnLane(of: resized.id, to: 7, duration: 10).first { $0.id == resized.id }?.range == 3..<6)
    }

    @Test func aMoveThatChangesNothingLeavesTheOverlaysEqual() {
        let stuck = overlay(0..<2)
        let overlays = [overlay(2..<4), stuck]
        #expect(overlays.movingOnLane(stuck.id, by: 3, duration: 10) == overlays)
    }

    @Test func usedLanesSkipEmptyOnes() {
        #expect([overlay(0..<1, lane: 2), overlay(0..<1)].usedLanes == [0, 2])
    }

    @Test func anOldProjectHasNoOverlaysAndANewOneKeepsThem() throws {
        var project = EditorProject()
        project.overlays = [
            overlay(1..<2, lane: 1),
            VideoOverlay(range: 2..<3, frame: VideoOverlay.defaultArrowFrame, kind: .arrow(ArrowOverlayStyle())),
            VideoOverlay(range: 3..<4, frame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5), kind: .image(bookmark: Data([1, 2, 3])))
        ]
        let decoded = try JSONDecoder().decode(EditorProject.self, from: JSONEncoder().encode(project))
        #expect(decoded.overlays == project.overlays)

        var saved = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        saved["overlays"] = nil
        let old = try JSONDecoder().decode(EditorProject.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(old.overlays.isEmpty)
    }
}

// MARK: - Geometry

struct VideoOverlayGeometryTests {

    private let arrow = VideoOverlay(range: 0..<1, frame: VideoOverlay.defaultArrowFrame, kind: .arrow(ArrowOverlayStyle()))

    @Test func aPictureKeepsItsShapeInTheMiddle() {
        let frame = VideoOverlay.imageFrame(pictureSize: CGSize(width: 400, height: 400), videoSize: CGSize(width: 1600, height: 900))
        // As wide as it is high, in pixels
        #expect(abs(frame.width * 1600 - frame.height * 900) < 0.001)
        #expect(abs(frame.midX - 0.5) < 0.001 && abs(frame.midY - 0.5) < 0.001)
        #expect(abs(frame.height - VideoOverlay.defaultImageShare) < 0.001)
    }

    @Test func anArrowsEndsAreWhereTheyWereDragged() throws {
        let (tail, tip) = (CGPoint(x: 0.7, y: 0.2), CGPoint(x: 0.1, y: 0.6))
        let moved = arrow.arrow(from: tail, to: tip)
        let style = try #require(moved.arrowStyle)
        #expect(close(moved.videoPoint(of: style.start), tail))
        #expect(close(moved.videoPoint(of: style.end), tip))
    }

    @Test func aLevelArrowHasAFrameToGrab() throws {
        let (tail, tip) = (CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.8, y: 0.5))
        let moved = arrow.arrow(from: tail, to: tip)
        let style = try #require(moved.arrowStyle)
        #expect(moved.frame.height >= VideoOverlay.minimumSize)
        #expect(close(moved.videoPoint(of: style.start), tail))
        #expect(close(moved.videoPoint(of: style.end), tip))
    }

    @Test func anArrowStaysInsideTheVideoAtItsEdge() throws {
        let moved = arrow.arrow(from: CGPoint(x: -0.5, y: 0), to: CGPoint(x: 0.5, y: 0))
        let style = try #require(moved.arrowStyle)
        #expect(moved.frame.minX >= 0 && moved.frame.minY >= 0)
        #expect(close(moved.videoPoint(of: style.start), CGPoint(x: 0, y: 0)))
        #expect(close(moved.videoPoint(of: style.end), CGPoint(x: 0.5, y: 0)))
    }

    @Test func aFrameIsMeasuredFromTheVideosTopLeft() {
        let video = CGRect(x: 100, y: 50, width: 1000, height: 500)
        let rect = PlannedOverlay.rect(of: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), in: video)
        // Core Image's origin is the bottom left
        #expect(rect == CGRect(x: 200, y: 250, width: 300, height: 200))
    }

    private func close(_ first: CGPoint, _ second: CGPoint) -> Bool {
        hypot(first.x - second.x, first.y - second.y) < 0.000_001
    }
}

// MARK: - Timing

struct VideoOverlayTimingTests {

    private let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))

    private func planned(_ range: Range<Double>, output: Range<Double>? = nil) -> PlannedOverlay {
        PlannedOverlay(range: range, outputs: [output ?? range], image: image)
    }

    @Test func itFadesOnTheOutputAtBothEnds() {
        let overlay = planned(1..<3)
        let frame = 1.0 / 30
        // The first frame already shows, a frame's worth in
        #expect(abs(overlay.opacity(atOutput: 1, frameDuration: frame) - frame / PlannedOverlay.fadeDuration) < 0.000_001)
        #expect(overlay.opacity(atOutput: 2, frameDuration: frame) == 1)
        #expect(abs(overlay.opacity(atOutput: 2.9, frameDuration: frame) - 0.5) < 0.000_001)
    }

    @Test func aShortOverlayFadesInHalfOfWhatItShows() {
        let overlay = planned(1..<1.1)
        #expect(abs(overlay.opacity(atOutput: 1.05, frameDuration: 0) - 1) < 0.000_001)
    }

    @Test func onlyTheOverlayCoveringTheTimeIsVisible() {
        let lane = [planned(1..<2), planned(3..<4)]
        #expect(PlannedOverlay.visible(in: lane, at: 0.5) == nil)
        #expect(PlannedOverlay.visible(in: lane, at: 1.5)?.range == 1..<2)
        #expect(PlannedOverlay.visible(in: lane, at: 2.5) == nil)
        #expect(PlannedOverlay.visible(in: lane, at: 3)?.range == 3..<4)
        #expect(PlannedOverlay.visible(in: lane, at: 4) == nil)
    }
}

// MARK: - Rendering

struct VideoOverlayRenderingTests {

    private static let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

    private static let textFrame = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    private func source(frames: Int = 120) async throws -> EditorSource {
        try await EditorSourceLoader.load(videoURL: try await cameraTestRecording(frames: frames))
    }

    private func box(_ range: Range<Double>, lane: Int = 0, color: RGBAColor = red, frame: CGRect = textFrame) -> VideoOverlay {
        var style = TextOverlayStyle()
        style.text = ""
        style.backgroundColor = color
        style.backgroundOpacity = 1
        return VideoOverlay(range: range, lane: lane, frame: frame, kind: .text(style))
    }

    private func pixels(of source: EditorSource, project: EditorProject, at time: Double) async throws -> OverlayPixels {
        let (composition, _) = try await cameraFrames(of: source, project: project)
        return try OverlayPixels(try await FrameGrabber.image(of: composition, at: time, timescale: source.timescale))
    }

    private func center(of frame: CGRect, plan: RenderPlan) -> CGPoint {
        PlannedOverlay.rect(of: frame, in: plan.canvas.videoFrame).center
    }

    @Test func aTextBoxShowsOnlyDuringItsRange() async throws {
        let source = try await source()
        let project = plainProject { $0.overlays = [box(1..<2)] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let middle = center(of: Self.textFrame, plan: plan)

        #expect(try await pixels(of: source, project: project, at: 0.5).isScreen(at: middle))
        #expect(try await pixels(of: source, project: project, at: 1.5).isRed(at: middle))
        #expect(try await pixels(of: source, project: project, at: 2.5).isScreen(at: middle))
    }

    @Test func itsTimesFollowCutsAndSpeeds() async throws {
        let source = try await source()
        // A second cut before it brings it forward by a second, and double speed halves what's after that
        let project = plainProject {
            $0.cuts = [0..<1]
            $0.speeds = [SpeedRange(range: 1..<4, rate: 2)]
            $0.overlays = [box(2..<3)]
        }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let middle = center(of: Self.textFrame, plan: plan)
        let overlay = try #require(plan.overlays.first?.first)
        let output = try #require(overlay.outputs.first)
        #expect(abs(output.lowerBound - 0.5) < 0.05)
        #expect(abs(output.upperBound - 1) < 0.05)

        #expect(try await pixels(of: source, project: project, at: 0.2).isScreen(at: middle))
        #expect(try await pixels(of: source, project: project, at: 0.75).isRed(at: middle))
        #expect(try await pixels(of: source, project: project, at: 1.2).isScreen(at: middle))
    }

    @Test func anOverlayEntirelyCutIsLeftOut() async throws {
        let source = try await source()
        let project = plainProject {
            $0.cuts = [1..<2.5]
            $0.overlays = [box(1.2..<2)]
        }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        #expect(plan.overlays.isEmpty)
    }

    @Test func aHigherLaneDrawsOverALowerOne() async throws {
        let source = try await source()
        let blue = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        // Listed highest first, so it's the lane that decides
        let project = plainProject { $0.overlays = [box(0..<4, lane: 2, color: blue), box(0..<4)] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let middle = center(of: Self.textFrame, plan: plan)
        #expect(try await pixels(of: source, project: project, at: 1).isBlue(at: middle))
    }

    @Test func itStaysPutDuringAZoom() async throws {
        let source = try await source()
        let frame = CGRect(x: 0.02, y: 0.02, width: 0.1, height: 0.1)
        let project = plainProject {
            $0.zooms = [ZoomSegment(range: 0..<4, scale: 3, focus: .fixed(center: CGPoint(x: 0.8, y: 0.8)))]
            $0.overlays = [box(0..<4, frame: frame)]
        }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        #expect(try await pixels(of: source, project: project, at: 2).isRed(at: center(of: frame, plan: plan)))
    }

    @Test func itDrawsOverTheCameraBubble() async throws {
        let video = try await cameraTestRecording(frames: 60)
        try await addCamera(to: video, seconds: 2)
        let source = try await EditorSourceLoader.load(videoURL: video)
        let bubble = try #require(await RenderPlan.build(project: plainProject(), source: source, resources: .none).bubble).rect
        let videoFrame = await RenderPlan.build(project: plainProject(), source: source, resources: .none).canvas.videoFrame
        // Fractions of the video from its top-left corner around the bubble's centre
        let frame = CGRect(
            x: (bubble.midX - videoFrame.minX) / videoFrame.width - 0.02, y: (videoFrame.maxY - bubble.midY) / videoFrame.height - 0.02, width: 0.04, height: 0.04
        )
        let project = plainProject { $0.overlays = [box(0..<2, frame: frame)] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        #expect(try await pixels(of: source, project: project, at: 1).isRed(at: center(of: frame, plan: plan)))
    }

    @Test func textDrawsItsWords() async throws {
        let source = try await source()
        var style = TextOverlayStyle()
        style.text = "HHHHHH"
        style.color = Self.red
        style.backgroundOpacity = 0
        style.size = 0.2
        let project = plainProject { $0.overlays = [VideoOverlay(range: 0..<4, frame: Self.textFrame, kind: .text(style))] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let rect = PlannedOverlay.rect(of: Self.textFrame, in: plan.canvas.videoFrame)
        let frame = try await pixels(of: source, project: project, at: 2)

        #expect(frame.redCount(in: rect) > 500)
        // No box, so what's around the letters is the recording, and nothing is outside its frame
        #expect(frame.isScreen(at: CGPoint(x: rect.minX + 2, y: rect.maxY - 2)))
        #expect(frame.redCount(in: CGRect(x: 0, y: 0, width: rect.minX - 1, height: plan.canvas.size.height)) == 0)
    }

    @Test func anArrowPointsWhereItIsToldTo() async throws {
        let source = try await source()
        var style = ArrowOverlayStyle()
        style.color = Self.red
        style.strokeWidth = 0.02
        let frame = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let project = plainProject { $0.overlays = [VideoOverlay(range: 0..<4, frame: frame, kind: .arrow(style))] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)
        let rect = PlannedOverlay.rect(of: frame, in: plan.canvas.videoFrame)
        let pixels = try await pixels(of: source, project: project, at: 2)

        // From the bottom left to the top right, in Core Image's coordinates: up and to the right
        #expect(pixels.isRed(at: rect.center))
        #expect(pixels.isScreen(at: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.25)))
        #expect(pixels.isScreen(at: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY + rect.height * 0.25)))
    }

    @Test func aPictureDrawsAndAnUnreadableOneIsLeftOut() async throws {
        let source = try await source()
        let folder = try temporaryFolder()
        let url = folder.appending(path: "picture.png")
        try writeRedPicture(to: url)
        let bookmark = try BackgroundImageLoader.bookmark(for: url)
        let frame = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        let project = plainProject { $0.overlays = [VideoOverlay(range: 0..<4, frame: frame, kind: .image(bookmark: bookmark))] }
        let plan = await RenderPlan.build(project: project, source: source, resources: .none)

        #expect(try await pixels(of: source, project: project, at: 2).isRed(at: center(of: frame, plan: plan)))

        try FileManager.default.removeItem(at: url)
        let missing = await RenderPlan.build(project: project, source: source, resources: .none)
        #expect(missing.overlays.isEmpty)
    }

    private func writeRedPicture(to url: URL) throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(Self.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}

/// A frame's colors, read in Core Image's bottom-left coordinates.
private struct OverlayPixels {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    init(_ image: CGImage) throws {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    private struct Color {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private func color(at point: CGPoint) -> Color {
        let index = (height - 1 - Int(point.y)) * width * 4 + Int(point.x) * 4
        return Color(red: bytes[index], green: bytes[index + 1], blue: bytes[index + 2])
    }

    func isRed(at point: CGPoint) -> Bool {
        let color = color(at: point)
        return color.red > 170 && color.green < 80 && color.blue < 80
    }

    func isBlue(at point: CGPoint) -> Bool {
        let color = color(at: point)
        return color.blue > 170 && color.red < 80 && color.green < 80
    }

    func isScreen(at point: CGPoint) -> Bool {
        let color = color(at: point)
        return color.red < 80 && color.green < 80 && color.blue < 80
    }

    func redCount(in rect: CGRect) -> Int {
        var count = 0
        for row in Int(rect.minY)..<Int(rect.maxY) {
            for column in Int(rect.minX)..<Int(rect.maxX) where isRed(at: CGPoint(x: column, y: row)) {
                count += 1
            }
        }
        return count
    }
}
