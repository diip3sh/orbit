//
//  LibraryGridTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct LibraryGridTests {

    @Test func aShapeWithinFivePercentOfSquareIsSquare() {
        #expect(LibraryOrientation(aspectRatio: 16 / 9) == .landscape)
        #expect(LibraryOrientation(aspectRatio: 9 / 16) == .portrait)
        #expect(LibraryOrientation(aspectRatio: 1) == .square)
        #expect(LibraryOrientation(aspectRatio: 1.04) == .square)
        #expect(LibraryOrientation(aspectRatio: 0.96) == .square)
        #expect(LibraryOrientation(aspectRatio: 1.06) == .landscape)
        #expect(LibraryOrientation(aspectRatio: 0.94) == .portrait)
    }

    @Test func sortsByDateEitherWayOrByNameAndOnlyDatesGetHeaders() {
        let items = [("Reco_10", 20.0), ("Reco_2", 0), ("Reco_1", 10)].map { name, age in
            LibraryItem(url: URL(filePath: "/r/\(name).mov"), kind: .recording, date: .now.addingTimeInterval(-age))
        }
        #expect(LibrarySort.newestFirst.sorted(items).map(\.name) == ["Reco_2", "Reco_1", "Reco_10"])
        #expect(LibrarySort.oldestFirst.sorted(items).map(\.name) == ["Reco_10", "Reco_1", "Reco_2"])
        #expect(LibrarySort.name.sorted(items).map(\.name) == ["Reco_1", "Reco_2", "Reco_10"])
        #expect(LibrarySort.newestFirst.groupsByDate && LibrarySort.oldestFirst.groupsByDate)
        #expect(!LibrarySort.name.groupsByDate)
    }

    @Test func fitsAsManyColumnsAsTheWidthAllowsAndAtLeastOne() {
        #expect(MasonryPlacement.columnCount(width: 1000, minimumColumnWidth: 200, spacing: 10) == 4)
        #expect(MasonryPlacement.columnCount(width: 830, minimumColumnWidth: 200, spacing: 10) == 4)
        #expect(MasonryPlacement.columnCount(width: 829, minimumColumnWidth: 200, spacing: 10) == 3)
        #expect(MasonryPlacement.columnCount(width: 50, minimumColumnWidth: 200, spacing: 10) == 1)
        #expect(MasonryPlacement.columnWidth(width: 830, columns: 4, spacing: 10) == 200)
    }

    @Test func eachTileGoesInTheShortestColumnTheLeftmostOnATie() {
        let placed = MasonryPlacement.slots(heights: [100, 50, 80, 40, 30], columns: 3, spacing: 10)

        #expect(placed.slots == [
            .init(column: 0, top: 0),
            .init(column: 1, top: 0),
            .init(column: 2, top: 0),
            .init(column: 1, top: 60),
            .init(column: 2, top: 90)
        ])
        #expect(placed.height == 120)
    }

    @Test func anEmptyGridHasNoHeight() {
        #expect(MasonryPlacement.slots(heights: [], columns: 3, spacing: 10).height == 0)
        let oneColumn = MasonryPlacement.slots(heights: [40], columns: 0, spacing: 10)
        #expect(oneColumn.slots == [.init(column: 0, top: 0)])
        #expect(oneColumn.height == 40)
    }

    @MainActor
    @Test func aThumbnailIsAsTallAsItsShapeUpToTwiceItsWidth() {
        #expect(LibraryViewModel.thumbnailSize(aspectRatio: 2) == CGSize(width: 640, height: 320))
        #expect(LibraryViewModel.thumbnailSize(aspectRatio: 0.25) == CGSize(width: 640, height: 1280))
        #expect(LibraryViewModel.thumbnailSize(aspectRatio: nil) == CGSize(width: 640, height: 400))
    }
}
