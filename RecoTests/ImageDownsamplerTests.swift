//
//  ImageDownsamplerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

struct ImageDownsamplerTests {

    @Test func downsamplesTheLongerSideToTheMax() async throws {
        let image = try await ImageDownsampler.thumbnail(of: .filled(width: 1000, height: 500), maxPixelSize: 200)

        #expect(image?.width == 200)
        #expect(image?.height == 100)
    }

    @Test func downsamplesAPortraitImage() async throws {
        let image = try await ImageDownsampler.thumbnail(of: .filled(width: 300, height: 900), maxPixelSize: 300)

        #expect(image?.width == 100)
        #expect(image?.height == 300)
    }

    @Test func neverEnlargesASmallImage() async throws {
        let image = try await ImageDownsampler.thumbnail(of: .filled(width: 100, height: 50), maxPixelSize: 200)

        #expect(image?.width == 100)
        #expect(image?.height == 50)
    }
}
