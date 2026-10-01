//
//  KeystrokeChipTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Testing
@testable import Reco

struct KeystrokeChipTests {

    private let chips = [
        KeystrokeChip(time: 1, image: 0),
        KeystrokeChip(time: 1.5, image: 1),
        KeystrokeChip(time: 5, image: 0)
    ]

    @Test func aChipShowsFromItsPress() throws {
        #expect(KeystrokeChip.visible(in: chips, at: 0.5) == nil)
        let visible = try #require(KeystrokeChip.visible(in: chips, at: 1))
        #expect(visible.chip == chips[0])
        #expect(visible.opacity == 1)
    }

    @Test func theNextPressReplacesIt() {
        #expect(KeystrokeChip.visible(in: chips, at: 1.6)?.chip == chips[1])
    }

    @Test func itFadesOutAtTheEndOfItsHold() throws {
        let fading = try #require(KeystrokeChip.visible(in: chips, at: 1.5 + KeystrokeChip.holdDuration - KeystrokeChip.fadeDuration / 2))
        #expect(abs(fading.opacity - 0.5) < 1e-9)
        #expect(KeystrokeChip.visible(in: chips, at: 1.5 + KeystrokeChip.holdDuration) == nil)
        #expect(KeystrokeChip.visible(in: chips, at: 5)?.chip == chips[2])
    }
}
