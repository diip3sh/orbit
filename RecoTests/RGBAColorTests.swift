//
//  RGBAColorTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

struct RGBAColorTests {

    @Test func convertsColorsToSRGB() throws {
        let color = try #require(RGBAColor(CGColor(gray: 1, alpha: 0.5)))

        #expect(color == RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    }

    @Test func settingTheCGColorStoresItsComponents() {
        var color = RGBAColor(red: 1, green: 0.8, blue: 0, alpha: 1)

        color.cgColor = CGColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        #expect(color == RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    }
}
