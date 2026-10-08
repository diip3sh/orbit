//
//  InspectorTabTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import Testing
@testable import Reco

struct InspectorTabTests {

    @Test func tabsKeepTheirOrderAndGroupsAreContiguous() {
        #expect(InspectorTab.allCases == [.background, .camera, .audio, .cursor, .keyboard, .caption, .motion])
        let groups = InspectorTab.allCases.map(\.group)
        #expect(groups == groups.sorted())
    }

    @Test func onlyCameraAndCaptionsAreUnavailable() {
        #expect(InspectorTab.allCases.filter { !$0.isAvailable } == [.camera, .caption])
    }
}
