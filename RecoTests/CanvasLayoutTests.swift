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
        var style = CanvasStyle(padding: 0.1, shadow: 0, background: .image)
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
}
