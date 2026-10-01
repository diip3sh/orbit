//
//  EditCoalescingTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct EditCoalescingTests {

    private let start = ContinuousClock.now

    @Test func joinsTheSameEditWithinASecondOfTheLast() {
        var edits = EditCoalescing()

        let joins = [0, 500, 1400, 2500].map { edits.joinsPrevious("Zoom", coalescing: true, at: start + .milliseconds($0)) }

        #expect(joins == [false, true, true, false])
    }

    @Test func anotherNameOrAnEditThatDoesntCoalesceStartsAStep() {
        var edits = EditCoalescing()

        let joins = [("Zoom", true), ("Cursor", true), ("Cursor", false), ("Cursor", true)].map { name, coalescing in
            edits.joinsPrevious(name, coalescing: coalescing, at: start)
        }

        #expect(joins == [false, false, false, false])
    }

    @Test func undoEndsTheChain() {
        var edits = EditCoalescing()
        _ = edits.joinsPrevious("Zoom", coalescing: true, at: start)

        edits.reset()
        let joins = edits.joinsPrevious("Zoom", coalescing: true, at: start)

        #expect(!joins)
    }
}
