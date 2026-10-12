//
//  GIFFrameTests.swift
//  RecoTests
//
//  Created by Diip3sh on 02.10.26.
//

import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Reco

struct GIFFrameTests {

    /// A single-image GIF of one color, as ImageIO writes it.
    private func file(red: CGFloat, green: CGFloat, width: Int = 8, height: Int = 6) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func framesJoinIntoALoopingAnimationWithTheirDelays() throws {
        let red = try #require(GIFFrame(file: try file(red: 1, green: 0)))
        let green = try #require(GIFFrame(file: try file(red: 0, green: 1)))

        let animation = GIFFrame.header(width: 8, height: 6) + red.block(delay: 4) + green.block(delay: 150) + GIFFrame.trailer

        let source = try #require(CGImageSourceCreateWithData(animation as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 2)
        let properties = try #require(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] as? Int == 0)
        for (index, (delay, color)) in [(0.04, [255, 0, 0] as [UInt8]), (1.5, [0, 255, 0])].enumerated() {
            let frame = try #require(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
            let gif = try #require(frame[kCGImagePropertyGIFDictionary] as? [CFString: Any])
            #expect(gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double == delay)
            let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
            #expect(image.width == 8 && image.height == 6)
            #expect(CIImage(cgImage: image).pixel(at: CGPoint(x: 4, y: 3)).prefix(3).elementsEqual(color))
        }
    }

    @Test func equalImagesMakeEqualFrames() throws {
        let red = GIFFrame(file: try file(red: 1, green: 0))
        #expect(red == GIFFrame(file: try file(red: 1, green: 0)))
        #expect(red != GIFFrame(file: try file(red: 0, green: 1)))
    }

    @Test func rejectsWhatIsNotAGIFOrIsCutShort() throws {
        #expect(GIFFrame(file: Data("not a gif at all".utf8)) == nil)
        #expect(GIFFrame(file: Data()) == nil)
        let whole = try file(red: 1, green: 0)
        #expect(GIFFrame(file: whole.prefix(whole.count - 4)) == nil)
        #expect(GIFFrame(file: whole.prefix(20)) == nil)
    }

    @Test func clampsTheDelayToWhatAFrameHolds() throws {
        let frame = try #require(GIFFrame(file: try file(red: 1, green: 0)))
        #expect(frame.block(delay: 70_000) == frame.block(delay: GIFFrame.maximumDelay))
    }
}
