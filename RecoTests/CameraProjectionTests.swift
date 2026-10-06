//
//  CameraProjectionTests.swift
//  RecoTests
//

import CoreGraphics
import simd
import Testing
@testable import Reco

struct CameraProjectionTests {

    private let canvas = CGSize(width: 1920, height: 1080)

    private var rest: CameraProjection {
        CameraProjection(lookAt: CGPoint(x: 960, y: 540), dolly: 0, canvas: canvas)
    }

    private func project(_ transform: Transform3D, size: CGSize, _ point: CGPoint, camera: CameraProjection? = nil) throws -> CGPoint {
        let world = transform.matrix(size: size) * SIMD4(point.x, point.y, 0, 1)
        return try #require((camera ?? rest).project(SIMD3(world.x, world.y, world.z))).point
    }

    @Test func aLayerAtZeroShowsOneToOneFromRest() throws {
        let transform = Transform3D(position: [500, 300, 0])
        let size = CGSize(width: 200, height: 100)

        // Anchored at its centre
        #expect(try project(transform, size: size, .zero) == CGPoint(x: 400, y: 250))
        #expect(try project(transform, size: size, CGPoint(x: 200, y: 100)) == CGPoint(x: 600, y: 350))
    }

    @Test func rotationXLeansTheTopAwayAsInCSS() throws {
        let transform = Transform3D(position: [960, 540, 0], rotation: [30, 0, 0])
        let size = CGSize(width: 400, height: 400)
        let topLeft = try project(transform, size: size, .zero)
        let topRight = try project(transform, size: size, CGPoint(x: 400, y: 0))
        let bottomLeft = try project(transform, size: size, CGPoint(x: 0, y: 400))
        let bottomRight = try project(transform, size: size, CGPoint(x: 400, y: 400))

        // The far edge is the shorter one
        #expect(topRight.x - topLeft.x < 400)
        #expect(bottomRight.x - bottomLeft.x > 400)
    }

    @Test func rotationYTurnsTheRightEdgeAway() throws {
        let transform = Transform3D(position: [960, 540, 0], rotation: [0, 30, 0])
        let size = CGSize(width: 400, height: 400)
        let left = try project(transform, size: size, CGPoint(x: 0, y: 400)).y - project(transform, size: size, .zero).y
        let right = try project(transform, size: size, CGPoint(x: 400, y: 400)).y - project(transform, size: size, CGPoint(x: 400, y: 0)).y

        #expect(right < left)
    }

    @Test func rotationZTurnsClockwise() throws {
        let transform = Transform3D(position: [960, 540, 0], rotation: [0, 0, 90])
        let size = CGSize(width: 200, height: 200)

        // The top-left corner swings to the top-right
        let corner = try project(transform, size: size, .zero)
        #expect(abs(corner.x - 1060) < 1e-9)
        #expect(abs(corner.y - 440) < 1e-9)
    }

    @Test func movingInMagnifiesAndBehindIsNotDrawn() throws {
        let pushed = CameraProjection(lookAt: CGPoint(x: 960, y: 540), dolly: rest.focalLength / 2, canvas: canvas)
        let point = try #require(pushed.project([1060, 540, 0])).point

        #expect(abs(point.x - 1160) < 1e-9)
        #expect(rest.project([960, 540, -rest.focalLength]) == nil)
    }
}
