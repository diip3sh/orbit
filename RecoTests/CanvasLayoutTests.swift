//
//  CanvasLayoutTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import CoreImage
import Testing
@testable import Reco

struct CanvasLayoutTests {

    @Test func sizesTheFrameByItsShapeAndShorterSide() {
        let fourK = CGSize(width: 3840, height: 2160)

        // The video's own shape keeps its size, odd sides included
        #expect(CanvasLayout.size(for: CGSize(width: 1917, height: 1079), aspect: .source, shorterSide: nil) == CGSize(width: 1917, height: 1079))
        #expect(CanvasLayout.size(for: fourK, aspect: .source, shorterSide: 1080) == CGSize(width: 1920, height: 1080))
        // Other shapes keep the video's shorter side, with even sides
        #expect(CanvasLayout.size(for: CGSize(width: 1600, height: 1200), aspect: .landscape, shorterSide: nil) == CGSize(width: 2134, height: 1200))
        #expect(CanvasLayout.size(for: fourK, aspect: .portrait, shorterSide: nil) == CGSize(width: 2160, height: 3840))
        #expect(CanvasLayout.size(for: fourK, aspect: .portrait, shorterSide: 1080) == CGSize(width: 1080, height: 1920))
        #expect(CanvasLayout.size(for: CGSize(width: 3456, height: 2234), aspect: .square, shorterSide: nil) == CGSize(width: 2234, height: 2234))
    }

    @Test func theVideosOwnShapeGrowsByThePaddingSoItsEqualOnEverySide() {
        for video in [CGSize(width: 3420, height: 2224), CGSize(width: 1080, height: 1920)] {
            let size = CanvasLayout.size(for: video, aspect: .source, padding: 0.08, shorterSide: nil)
            let frame = CanvasLayout.videoFrame(for: video, in: size, padding: 0.08)
            let sides = [frame.minX, frame.minY, size.width - frame.maxX, size.height - frame.maxY]
            #expect(sides.max()! - sides.min()! <= 2, "\(video): \(sides)")
        }
    }

    @Test func anExportAtTheNativeSizeKeepsTheVideosOwnPixels() {
        for video in [CGSize(width: 3420, height: 2224), CGSize(width: 1080, height: 1920)] {
            for aspect in CanvasStyle.Aspect.allCases {
                let style = CanvasStyle(aspect: aspect, padding: 0.08)
                let side = CanvasLayout.nativeShorterSide(for: video, style: style)
                let size = CanvasLayout.size(for: video, aspect: aspect, padding: 0.08, shorterSide: side)
                #expect(CanvasLayout.videoFrame(for: video, in: size, padding: 0.08).size == video, "\(video) \(aspect)")
            }
        }
    }

    @Test func anExportAtTheNativeSizeKeepsTheFilledPartsOwnPixels() {
        for video in [CGSize(width: 3420, height: 2224), CGSize(width: 1080, height: 1920), CGSize(width: 1917, height: 1079)] {
            for aspect in CanvasStyle.Aspect.allCases where aspect != .source {
                let style = CanvasStyle(aspect: aspect, fillsFrame: true, padding: 0.08)
                let side = CanvasLayout.nativeShorterSide(for: video, style: style)
                let size = CanvasLayout.size(for: video, aspect: aspect, padding: 0.08, shorterSide: side)
                let frame = CanvasLayout.filledFrame(for: video, in: size, padding: 0.08)
                let shown = CanvasLayout.baseView(for: video, shape: frame.size)
                // The part shown is scaled onto the frame by exactly 1, and the padding stays within a few pixels of 8%
                let scaleX: CGFloat = frame.width / (video.width * shown.width)
                let scaleY: CGFloat = frame.height / (video.height * shown.height)
                #expect(abs(scaleX - 1) < 1e-9, "\(video) \(aspect): \(frame.size)")
                #expect(abs(scaleY - 1) < 1e-9, "\(video) \(aspect): \(frame.size)")
                let inset = 0.08 * side
                #expect(abs(frame.minX - inset) <= 6 && abs(frame.minY - inset) <= 6, "\(video) \(aspect): \(frame) in \(size)")
            }
        }
    }

    @Test func fillingCoversThePaddedSpaceWithThePartOfTheVideoInItsShape() {
        let style = CanvasStyle(aspect: .square, fillsFrame: true, padding: 0.1, cornerRadius: 0, shadow: 0)
        let layout = CanvasLayout(style: style, videoSize: CGSize(width: 400, height: 300), shorterSide: nil, background: nil)

        #expect(layout.size == CGSize(width: 300, height: 300))
        #expect(layout.videoFrame == CGRect(x: 30, y: 30, width: 240, height: 240))
        // The video's full height, and as much of its width as is square
        #expect(layout.baseView == CGSize(width: 0.75, height: 1))
        #expect(CanvasLayout.baseView(for: CGSize(width: 400, height: 300), style: style) == CGSize(width: 0.75, height: 1))
        // A space within the rounding of the part's own size takes that size: 3420×2224 in 16:9 at 2118 is 3766×2118,
        // whose space is 3428×1780 for a part of 3420×1776
        let native = CanvasLayout.filledFrame(for: CGSize(width: 3420, height: 2224), in: CGSize(width: 3766, height: 2118), padding: 0.08)
        #expect(native == CGRect(x: 173, y: 171, width: 3420, height: 1776))
        // Fitting, or in the video's own shape, the whole video
        #expect(CanvasLayout.baseView(for: CGSize(width: 400, height: 300), style: CanvasStyle(aspect: .square, padding: 0.1)) == CameraPath.wholeVideo)
        var own = style
        own.aspect = .source
        #expect(CanvasLayout.baseView(for: CGSize(width: 400, height: 300), style: own) == CameraPath.wholeVideo)
        // A video narrower than the shape gives its full width
        #expect(CanvasLayout.baseView(for: CGSize(width: 300, height: 600), shape: CGSize(width: 1, height: 1)) == CGSize(width: 1, height: 0.5))
    }

    @Test func fitsTheVideoInsideThePaddingOnWholePixels() {
        // 10% of 1,200 px on every side leaves 1,894×960 px, which the height limits to 1,280×960
        let frame = CanvasLayout.videoFrame(for: CGSize(width: 1600, height: 1200), in: CGSize(width: 2134, height: 1200), padding: 0.1)

        #expect(frame == CGRect(x: 427, y: 120, width: 1280, height: 960))
    }

    @Test func aPlainCanvasIsTheVideoAsItIs() {
        let layout = CanvasLayout(style: .plain, videoSize: CGSize(width: 1917, height: 1079), shorterSide: nil, background: nil)

        #expect(layout.size == CGSize(width: 1917, height: 1079))
        #expect(layout.videoFrame == CGRect(origin: .zero, size: layout.size))
        #expect(layout.videoTransform.isIdentity)
        #expect(layout.backdrop == nil && layout.videoMask == nil)
    }

    @Test func dividesTheFrameIntoRegionsThatCoverItOnce() {
        for style in [CanvasStyle(), .plain, CanvasStyle(aspect: .portrait, padding: 0.25, cornerRadius: 0.05)] {
            let layout = CanvasLayout(style: style, videoSize: CGSize(width: 1917, height: 1079), shorterSide: nil, background: nil)
            let rects = layout.regions.map(\.rect)

            #expect(rects.map { $0.width * $0.height }.reduce(0, +) == layout.size.width * layout.size.height)
            #expect(rects.indices.allSatisfy { index in rects[(index + 1)...].allSatisfy { !$0.intersects(rects[index]) } })
            #expect(rects.allSatisfy { $0 == $0.integral })
        }
    }

    @Test func fillsTheBackgroundWithItsPictureOrElseItsColor() throws {
        var style = CanvasStyle(aspect: .standard, padding: 0.1, shadow: 0, background: .image)
        style.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        let picture = try #require(CIContext().createCGImage(
            CIImage(color: CIColor(red: 1, green: 0, blue: 0)), from: CGRect(x: 0, y: 0, width: 30, height: 10)
        ))
        let videoSize = CGSize(width: 400, height: 300)

        let withPicture = try #require(CanvasLayout(style: style, videoSize: videoSize, shorterSide: nil, background: picture).backdrop)
        let withoutPicture = try #require(CanvasLayout(style: style, videoSize: videoSize, shorterSide: nil, background: nil).backdrop)

        #expect(withPicture.extent == CGRect(x: 0, y: 0, width: 400, height: 300))
        #expect(withPicture.pixel(at: CGPoint(x: 5, y: 295)) == [255, 0, 0, 255])
        #expect(withoutPicture.pixel(at: CGPoint(x: 5, y: 295)) == [0, 0, 255, 255])
    }

    /// A picture of `width` × `height` pixels, red on the left half and blue on the right.
    private func twoHalves(width: Int, height: Int) throws -> CGImage {
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return try #require(context.makeImage())
    }

    @Test func blursAPictureBackgroundAcrossItsSeamAndKeepsItsEdgesOpaque() throws {
        var style = CanvasStyle(aspect: .standard, padding: 0.1, shadow: 0, background: .image)
        let picture = try twoHalves(width: 400, height: 300)
        let videoSize = CGSize(width: 400, height: 300)

        let sharp = try #require(CanvasLayout(style: style, videoSize: videoSize, shorterSide: nil, background: picture).backdrop)
        style.backgroundBlur = 1
        let blurred = try #require(CanvasLayout(style: style, videoSize: videoSize, shorterSide: nil, background: picture).backdrop)

        #expect(sharp.pixel(at: CGPoint(x: 199, y: 10)) == [255, 0, 0, 255])
        #expect(sharp.pixel(at: CGPoint(x: 200, y: 10)) == [0, 0, 255, 255])
        // A sigma of 9 px mixes the halves at the seam
        let seam = blurred.pixel(at: CGPoint(x: 199, y: 10))
        #expect(seam[0] > 100 && seam[2] > 100 && seam[3] == 255)
        #expect(blurred.pixel(at: CGPoint(x: 5, y: 10)) == [255, 0, 0, 255])
        #expect(blurred.pixel(at: .zero)[3] == 255 && blurred.pixel(at: CGPoint(x: 399, y: 299))[3] == 255)
    }

    @Test func aBorderIsWholePixelsNeverPastTheCanvasEdge() {
        #expect(CanvasLayout.borderWidth(50, around: CGRect(x: 40, y: 30, width: 320, height: 240)) == 30)
        #expect(CanvasLayout.borderWidth(5.6, around: CGRect(x: 40, y: 30, width: 320, height: 240)) == 6)
        #expect(CanvasLayout.borderWidth(50, around: CGRect(x: 0, y: 0, width: 400, height: 300)) == 0)
    }

    @Test func aBorderFollowsTheVideosRoundedCornersOutward() throws {
        var style = CanvasStyle(aspect: .standard, padding: 0.1, cornerRadius: 0.05, shadow: 0, background: .color)
        style.color = RGBAColor(red: 0, green: 0, blue: 1, alpha: 1)
        style.borderWidth = 0.02
        style.borderColor = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

        let layout = CanvasLayout(style: style, videoSize: CGSize(width: 400, height: 300), shorterSide: nil, background: nil)
        let backdrop = try #require(layout.backdrop)

        // The video is (40, 30, 320 × 240) and the border 6 px wide, so its frame (34, 24, 332 × 252) has a radius of 21
        #expect(layout.videoFrame == CGRect(x: 40, y: 30, width: 320, height: 240))
        #expect(backdrop.pixel(at: CGPoint(x: 37, y: 150)) == [255, 0, 0, 255])
        #expect(backdrop.pixel(at: CGPoint(x: 31, y: 150)) == [0, 0, 255, 255])
        // Inside the border's corner arc, and outside it
        #expect(backdrop.pixel(at: CGPoint(x: 41, y: 31)) == [255, 0, 0, 255])
        #expect(backdrop.pixel(at: CGPoint(x: 35, y: 25)) == [0, 0, 255, 255])

        style.borderWidth = 0
        let without = try #require(CanvasLayout(style: style, videoSize: CGSize(width: 400, height: 300), shorterSide: nil, background: nil).backdrop)
        #expect(without.pixel(at: CGPoint(x: 37, y: 150)) == [0, 0, 255, 255])
    }
}
