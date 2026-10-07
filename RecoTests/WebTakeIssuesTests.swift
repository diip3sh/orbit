//
//  WebTakeIssuesTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct WebTakeIssuesTests {

    private let viewport = CGSize(width: 1440, height: 900)

    @Test func aTargetOnThePageInViewAndUncoveredIsFine() {
        var issues = WebTakeIssues(viewport: viewport)

        issues.check("#buy", at: 1, frame: CGRect(x: 100, y: 100, width: 80, height: 40), cover: nil)

        #expect(issues.messages.isEmpty)
    }

    @Test func eachProblemIsSaidOncePerSelectorWithItsTime() {
        var issues = WebTakeIssues(viewport: viewport)

        issues.check("#gone", at: 2.26, frame: nil, cover: nil)
        issues.check("#gone", at: 5, frame: nil, cover: nil)
        issues.check("#low", at: 3, frame: CGRect(x: 100, y: 1200, width: 80, height: 40), cover: nil)
        issues.check("#buy", at: 4, frame: CGRect(x: 100, y: 100, width: 80, height: 40), cover: #"div.menu ("iPhone")"#)
        issues.skippedClick("#gone", at: 2.26)
        issues.notFound("#faq", at: 6)

        #expect(issues.messages.count == 5)
        #expect(issues.messages[0].hasPrefix(##"At 2.3 s no element matched "#gone", so the cursor went to the middle of the view."##))
        #expect(issues.messages[1].hasPrefix(##"At 3.0 s "#low" was outside the view (its middle at x 140, y 1220 of 1440×900)"##))
        #expect(issues.messages[2].hasPrefix(##"At 4.0 s div.menu ("iPhone") covered "#buy" where the cursor pointed."##))
        #expect(issues.messages[3].contains("its click was left out"))
        #expect(issues.messages[4].hasPrefix(##"At 6.0 s the scroll found no element matching "#faq", so the page didn't move."##))
    }
}
