//
//  MaskTests.swift
//  RecoTests
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Testing
@testable import Reco

@MainActor
struct MaskTests {

    /// The top half of the video's middle half across: 400…1200 px and, in Core Image's space, 600…1200.
    private static let rect = CGRect(x: 0.25, y: 0, width: 0.5, height: 0.5)

    private static let frameSize = CGSize(width: 1600, height: 1200)

    private func plan(_ kind: MaskSegment.Kind, crop: CGRect = VideoCrop.full, rects: [CGRect] = [rect]) async -> RenderPlan {
        var project = EditorProject()
        project.canvas = .plain
        project.crop = crop
        project.masks = [MaskSegment(range: 1..<2, rects: rects, kind: kind)]
        let source = EditorSource(
            asset: AVURLAsset(url: URL(filePath: "/dev/null")),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            videoTrackID: 1,
            audioTrackIDs: [],
            naturalSize: Self.frameSize,
            frameRate: 60,
            timescale: 600,
            dynamicRange: .sdr,
            telemetry: nil,
            telemetryError: nil
        )
        return await RenderPlan.build(project: project, source: source, resources: .none)
    }

    /// White on the left half, black on the right, so the mask's rectangle straddles an edge.
    private var halves: CIImage {
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 800, height: 1200))
        return white.composited(over: CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: Self.frameSize)))
    }

    private func brightness(_ image: CIImage, at point: CGPoint) -> Int {
        Int(image.pixel(at: point)[0])
    }

    @Test func placesMasksInCoreImagePixelsOfTheCrop() async {
        let whole = await plan(.blur)
        let cropped = await plan(.blur, crop: CGRect(x: 0, y: 0, width: 0.5, height: 1))

        #expect(whole.masks.map(\.rects) == [[CGRect(x: 400, y: 600, width: 800, height: 600)]])
        // Fractions of the 800 px wide crop
        #expect(cropped.masks.map(\.rects) == [[CGRect(x: 200, y: 600, width: 400, height: 600)]])
    }

    @Test func findsTheMaskShowingAtATime() {
        let masks = [
            PlannedMask(range: 1..<2, rects: [], kind: .blur),
            PlannedMask(range: 4..<6, rects: [], kind: .spotlight)
        ]

        #expect(masks.active(at: 0.5) == nil)
        #expect(masks.active(at: 1.5)?.kind == .blur)
        #expect(masks.active(at: 3) == nil)
        #expect(masks.active(at: 4)?.kind == .spotlight)
        #expect(masks.active(at: 6) == nil)
    }

    @Test func showsNothingOutsideTheMasksTime() async {
        let image = FrameRenderer.masked(halves, at: 3, plan: await plan(.blur))

        #expect(brightness(image, at: CGPoint(x: 799, y: 900)) == 255)
        #expect(brightness(image, at: CGPoint(x: 800, y: 900)) == 0)
    }

    @Test func blursOnlyInsideTheRectangle() async {
        let image = FrameRenderer.masked(halves, at: 1.5, plan: await plan(.blur))

        // The edge inside is blurred into greys; the same edge below the mask stays sharp
        #expect((60...200).contains(brightness(image, at: CGPoint(x: 799, y: 900))))
        #expect((60...200).contains(brightness(image, at: CGPoint(x: 800, y: 900))))
        #expect(brightness(image, at: CGPoint(x: 799, y: 300)) == 255)
        #expect(brightness(image, at: CGPoint(x: 800, y: 300)) == 0)
    }

    @Test func pixelatesInWholeCellsFromTheRectanglesCorner() async throws {
        let gradient = CIFilter.linearGradient()
        gradient.point0 = .zero
        gradient.point1 = CGPoint(x: Self.frameSize.width, y: 0)
        gradient.color0 = .black
        gradient.color1 = .white
        let frame = try #require(gradient.outputImage).cropped(to: CGRect(origin: .zero, size: Self.frameSize))

        let image = FrameRenderer.masked(frame, at: 1.5, plan: await plan(.pixelate))

        // Cells are 24 px (2% of 1200) from (400, 600): the first spans 400…423
        #expect(image.pixel(at: CGPoint(x: 401, y: 601)) == image.pixel(at: CGPoint(x: 422, y: 622)))
        #expect(image.pixel(at: CGPoint(x: 401, y: 601)) != frame.pixel(at: CGPoint(x: 401, y: 601)))
        #expect(image.pixel(at: CGPoint(x: 401, y: 300)) == frame.pixel(at: CGPoint(x: 401, y: 300)))
    }

    @Test func aSpotlightDimsEverythingElse() async {
        let white = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: Self.frameSize))

        let image = FrameRenderer.masked(white, at: 1.5, plan: await plan(.spotlight))

        #expect(brightness(image, at: CGPoint(x: 800, y: 900)) == 255)
        // 40% of white is 102 in the compositor's unmanaged encoding, 170 through this linear-light context
        #expect((150...190).contains(brightness(image, at: CGPoint(x: 800, y: 300))))
        #expect((150...190).contains(brightness(image, at: CGPoint(x: 100, y: 900))))
    }

    @Test func masksEveryRectangleAtOnce() async {
        let corner = CGRect(x: 0, y: 0.75, width: 0.25, height: 0.25)
        let white = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: Self.frameSize))

        let image = FrameRenderer.masked(white, at: 1.5, plan: await plan(.spotlight, rects: [Self.rect, corner]))

        #expect(brightness(image, at: CGPoint(x: 800, y: 900)) == 255)
        // The bottom-left corner, 0…400 and 0…300 in Core Image's space
        #expect(brightness(image, at: CGPoint(x: 100, y: 100)) == 255)
        #expect(brightness(image, at: CGPoint(x: 100, y: 900)) < 200)
    }
}
