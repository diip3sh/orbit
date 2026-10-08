//
//  SensitiveMasksTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct SensitiveMasksTests {

    private let email = CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05)
    private let phone = CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.05)

    private func samples(_ boxes: [[CGRect]]) -> [SensitiveMasks.Sample] {
        boxes.enumerated().map { SensitiveMasks.Sample(time: Double($0.offset), boxes: $0.element) }
    }

    /// Unions are made from edges, so a joined rectangle is its box to within rounding.
    private func same(_ rects: [CGRect], _ expected: [CGRect]) -> Bool {
        rects.count == expected.count && zip(rects, expected).allSatisfy {
            abs($0.minX - $1.minX) < 1e-9 && abs($0.minY - $1.minY) < 1e-9 && abs($0.width - $1.width) < 1e-9 && abs($0.height - $1.height) < 1e-9
        }
    }

    @Test func hidesTextFromTheSampleBeforeItShowedToTheOneAfter() {
        let masks = SensitiveMasks.masks(from: samples([[], [], [email], [email], []]), interval: 1, duration: 10)

        #expect(masks.map(\.range) == [1..<4])
        #expect(same(masks.first?.rects ?? [], [email]))
        #expect(masks.first?.kind == .pixelate)
    }

    @Test func coversWhereMovingTextWent() {
        let scrolled = email.offsetBy(dx: 0, dy: 0.03)

        let masks = SensitiveMasks.masks(from: samples([[email], [scrolled]]), interval: 1, duration: 10)

        #expect(same(masks.first?.rects ?? [], [email.union(scrolled)]))
        // Clamped to the recording's start
        #expect(masks.map(\.range) == [0..<2])
    }

    @Test func textThatGoesAndComesBackIsHiddenTwice() {
        let masks = SensitiveMasks.masks(from: samples([[email], [], [], [], [email]]), interval: 1, duration: 4.5)

        #expect(masks.map(\.range) == [0..<1, 3..<4.5])
    }

    @Test func textShowingTogetherSharesAMask() {
        let masks = SensitiveMasks.masks(from: samples([[email], [email, phone], [phone], []]), interval: 1, duration: 10)

        #expect(masks.count == 1)
        #expect(masks.first?.range == 0..<3)
        #expect(same(masks.first?.rects ?? [], [email, phone]))
    }

    @Test func foundMasksJoinAMaskMadeByHandWhichKeepsItsEffect() {
        let mine = MaskSegment(range: 2..<5, kind: .blur)
        let found = [MaskSegment(range: 1..<3, rects: [email], kind: .pixelate), MaskSegment(range: 7..<8, rects: [phone], kind: .pixelate)]

        let merged = SensitiveMasks.merging(found, into: [mine])

        #expect(merged.map(\.range) == [1..<5, 7..<8])
        #expect(merged[0].id == mine.id)
        #expect(merged[0].kind == .blur)
        #expect(merged[0].rects == [email] + mine.rects)
    }

    @Test func readsEverySecondOfTheKeptParts() {
        #expect(SensitiveInfoScanner.times(in: [0..<2.5, 4..<5]) == [0, 1, 2, 4])
    }
}
