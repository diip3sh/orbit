//
//  LoupeGeometryTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct LoupeGeometryTests {

    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

    /// A 2× screen's picture.
    private let imageSize = CGSize(width: 2000, height: 1600)

    @Test func sitsBelowAndRightOfThePointerAndFlipsAtTheEdges() {
        #expect(LoupeGeometry.frame(beside: CGPoint(x: 100, y: 500), in: bounds) == CGRect(x: 120, y: 360, width: 120, height: 120))
        // Near the right edge it goes left; near the bottom, up
        #expect(LoupeGeometry.frame(beside: CGPoint(x: 900, y: 500), in: bounds) == CGRect(x: 760, y: 360, width: 120, height: 120))
        #expect(LoupeGeometry.frame(beside: CGPoint(x: 100, y: 100), in: bounds) == CGRect(x: 120, y: 120, width: 120, height: 120))
        #expect(LoupeGeometry.frame(beside: CGPoint(x: 950, y: 50), in: bounds) == CGRect(x: 810, y: 70, width: 120, height: 120))
    }

    @Test func findsThePixelUnderThePointerFromTheTopLeftCorner() {
        #expect(LoupeGeometry.pixel(under: CGPoint(x: 100.4, y: 700), in: bounds, imageSize: imageSize) == CGPoint(x: 200, y: 200))
        #expect(LoupeGeometry.pixel(under: CGPoint(x: 0, y: 800), in: bounds, imageSize: imageSize) == .zero)
        // On the far edges, the last column and row
        #expect(LoupeGeometry.pixel(under: CGPoint(x: 1000, y: 0), in: bounds, imageSize: imageSize) == CGPoint(x: 1999, y: 1599))
    }

    @Test func showsThePixelsAroundThePointerAndOnlyThoseTheScreenHas() {
        let pixel = CGPoint(x: 200, y: 200)
        let region = LoupeGeometry.region(around: pixel, imageSize: imageSize)

        // 15 pixels either side of the pointer's: 31 across, 124 points, a little more than the loupe
        #expect(region == CGRect(x: 185, y: 185, width: 31, height: 31))
        #expect(LoupeGeometry.drawingRect(of: region, around: pixel) == CGRect(x: -2, y: -2, width: 124, height: 124))

        let corner = LoupeGeometry.region(around: .zero, imageSize: imageSize)
        #expect(corner == CGRect(x: 0, y: 0, width: 16, height: 16))
        // The top-left pixel stays at the centre: its column starts 2 points left of it and the rows run down from 2 above
        #expect(LoupeGeometry.drawingRect(of: corner, around: .zero) == CGRect(x: 58, y: -2, width: 64, height: 64))
    }
}
