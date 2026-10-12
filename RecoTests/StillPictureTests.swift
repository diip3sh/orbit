//
//  StillPictureTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

/// The picture standing still (spec 0021): a scene whose picture doesn't change for over a second is named, the end card
/// aside, and so is a film whose picture stands still too much of the time.
struct StillPictureTests {

    @Test func aStillSceneIsNamedButTheEndCardIsnt() {
        // 10 frames a second: a still 2 s, a scene changing every frame for 2 s, a still end card
        let levels = (0..<60).map { index in
            [Double](repeating: (20..<40).contains(index) ? Double(index) * 10 : (index < 20 ? 50 : 200), count: 4)
        }
        let scenes = [(id: "still", start: 0.0), (id: "moving", start: 2.0), (id: "end", start: 4.0)]
        let findings = DesignCheck.stillPictures(levels: levels, scenes: scenes)

        #expect(findings.count == 2)
        #expect(findings.first?.hasPrefix("The picture hardly changes in 55%") == true)
        #expect(findings.last?.hasPrefix("still: the picture stands still from 0.0 s for 1.9 s") == true)
    }

    @Test func aChangingFilmIsFine() {
        let levels = (0..<40).map { [Double](repeating: Double($0) * 5, count: 4) }
        #expect(DesignCheck.stillPictures(levels: levels, scenes: [(id: "a", start: 0), (id: "b", start: 2)]).isEmpty)
    }

    @Test func levelsAreTheFramesLuma() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 64, height: 36, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 36))
        let image = try #require(context.makeImage())
        let levels = try #require(DesignCheck.levels(of: image))

        #expect(levels.count == DesignCheck.changeSize.width * DesignCheck.changeSize.height)
        #expect(levels.allSatisfy { abs($0 - 128) < 1.5 })
    }
}
