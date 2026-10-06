//
//  WebTakeIssuesTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct WebTakeIssuesTests {

    @Test func aMissingElementIsReportedOnceWithItsTime() {
        var issues = WebTakeIssues(viewport: CGSize(width: 1440, height: 900))
        issues.check("#a", at: 12.5, frame: nil, cover: nil)
        issues.check("#a", at: 14, frame: nil, cover: nil)

        #expect(issues.messages == [
            ##"At 12.5 s no element matched "#a", so the cursor went to the middle of the view. Use a selector from inspect_page of the page shown then."##
        ])
    }

    @Test func anElementOutsideTheViewOrCoveredIsReported() {
        var issues = WebTakeIssues(viewport: CGSize(width: 1440, height: 900))
        issues.check("#low", at: 1, frame: CGRect(x: 100, y: 1200, width: 100, height: 40), cover: nil)
        issues.check("#menu", at: 2, frame: CGRect(x: 100, y: 100, width: 100, height: 40), cover: #"div.mega ("Products")"#)
        issues.check("#fine", at: 3, frame: CGRect(x: 100, y: 100, width: 100, height: 40), cover: nil)

        #expect(issues.messages.count == 2)
        #expect(issues.messages[0].hasPrefix(##"At 1.0 s "#low" was outside the view (its middle at x 150, y 1220 of 1440×900)"##))
        #expect(issues.messages[1].hasPrefix(##"At 2.0 s div.mega ("Products") covered "#menu""##))
    }

    @Test func clicksAndScrollsThatFoundNothingAreReported() {
        var issues = WebTakeIssues(viewport: CGSize(width: 1440, height: 900))
        issues.skippedClick("#buy", at: 3)
        issues.notFound("#pricing", at: 4)

        #expect(issues.messages[0].contains("so its click was left out"))
        #expect(issues.messages[1].contains("so the page didn't move"))
    }

    @Test func aShownElementIsFramedOnlyWhenMostlyInView() {
        var issues = WebTakeIssues(viewport: CGSize(width: 1440, height: 900))
        let inView = CGRect(x: 100, y: 100, width: 400, height: 300)

        #expect(issues.shown("#shot", at: 1, frame: inView) == inView)
        #expect(issues.messages.isEmpty)
        #expect(issues.shown("#low", at: 2, frame: CGRect(x: 100, y: 800, width: 400, height: 300)) == nil)
        #expect(issues.shown("#gone", at: 3, frame: nil) == nil)
        #expect(issues.messages.count == 2)
        #expect(issues.messages[0].hasPrefix(##"At 2.0 s the shown element "#low" wasn't on the page or mostly in view"##))
    }
}
