//
//  ImageDownsamplerTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import Testing
@testable import BetterCapture

struct ImageDownsamplerTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func downsamplesTheLongerSideToTheMax() async throws {
        let url = try writePNG(width: 1000, height: 500)

        let image = await ImageDownsampler.thumbnail(of: url, maxPixelSize: 200)

        #expect(image?.width == 200)
        #expect(image?.height == 100)
    }

    @Test func downsamplesAPortraitImage() async throws {
        let url = try writePNG(width: 300, height: 900)

        let image = await ImageDownsampler.thumbnail(of: url, maxPixelSize: 300)

        #expect(image?.width == 100)
        #expect(image?.height == 300)
    }

    @Test func anUnreadableFileReturnsNil() async {
        let url = folder.appending(path: "missing.png")

        let image = await ImageDownsampler.thumbnail(of: url, maxPixelSize: 200)

        #expect(image == nil)
    }

    private func writePNG(width: Int, height: Int) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try #require(context.makeImage())
        let data = try #require(NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]))

        let url = folder.appending(path: "\(width)x\(height).png")
        try data.write(to: url)
        return url
    }
}
