//
//  ScreenshotFollowUpTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct ScreenshotFollowUpTests {

    @Test(arguments: [
        ("reco://capture-area?then=copy", ScreenshotFollowUp.copy),
        ("reco://capture-window?then=save", .save),
        ("reco://capture-screen?other=1&then=pin", .pin)
    ])
    func readsThen(link: String, expected: ScreenshotFollowUp) throws {
        #expect(ScreenshotFollowUp(url: try #require(URL(string: link))) == expected)
    }

    @Test(arguments: ["reco://capture-area", "reco://capture-area?then=upload", "reco://capture-area?then="])
    func opensTheCardWithoutAKnownThen(link: String) throws {
        #expect(ScreenshotFollowUp(url: try #require(URL(string: link))) == nil)
    }
}
