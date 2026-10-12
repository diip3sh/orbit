//
//  MatteFillTests.swift
//  RecoTests
//

import Testing
@testable import Reco

/// A live take's matte with what its outline encloses filled (spec 0012, L1b).
struct MatteFillTests {

    /// A 7×7 outline, soft outside, with a glyph's soft pixel inside it.
    private static let outlined: [UInt8] = [
        0, 0, 0, 0, 0, 0, 0,
        0, 40, 40, 40, 40, 40, 0,
        0, 40, 255, 255, 255, 255, 0,
        0, 40, 255, 0, 90, 255, 0,
        0, 40, 255, 0, 0, 255, 0,
        0, 40, 255, 255, 255, 255, 0,
        0, 0, 0, 0, 0, 0, 0
    ]

    @Test func fillsWhatAnOutlineEncloses() {
        let filled = MatteFill.filled(alpha: Self.outlined, width: 7, height: 7)

        for (column, row) in [(3, 3), (4, 3), (3, 4), (4, 4)] {
            #expect(filled[row * 7 + column] == 255, "(\(column), \(row)) is inside")
        }
    }

    @Test func keepsTheSoftEdgeOutside() {
        let filled = MatteFill.filled(alpha: Self.outlined, width: 7, height: 7)

        #expect(filled[1 * 7 + 1] == 40)
        #expect(filled[0] == 0)
    }

    /// Supabase's search: a translucent field round its placeholder's letters is all covered, its
    /// soft corner in proportion.
    @Test func coversATranslucentField() {
        let field: [UInt8] = [
            0, 17, 35, 35, 35, 17, 0,
            17, 35, 35, 35, 35, 35, 17,
            35, 35, 255, 35, 255, 35, 35,
            17, 35, 35, 35, 35, 35, 17,
            0, 17, 35, 35, 35, 17, 0
        ]

        let filled = MatteFill.filled(alpha: field, width: 7, height: 5)

        #expect(filled[2 * 7 + 3] == 255)
        #expect(filled[1 * 7 + 1] == 255)
        #expect(filled[0] == 0)
        #expect(filled[1] == 123)
    }

    /// Text with no outline round it stays as painted: its letters' insides reach the border.
    @Test func leavesAnOpenShapeAsPainted() {
        let open: [UInt8] = [
            0, 0, 0, 0, 0,
            0, 255, 0, 255, 0,
            0, 255, 0, 255, 0,
            0, 255, 255, 255, 0,
            0, 0, 0, 0, 0
        ]

        #expect(MatteFill.filled(alpha: open, width: 5, height: 5) == open)
    }
}
