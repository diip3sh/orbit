//
//  ThemeFontTests.swift
//  RecoTests
//

import AppKit
import SwiftUI
import Testing
@testable import Reco

/// The bundled fonts load at the token scale's weights, so nothing falls back to the system font unnoticed.
@MainActor
struct ThemeFontTests {

    @Test func sansIsInter() {
        #expect(NSFont.theme().familyName == "Inter Variable")
        #expect(NSFont.theme().pointSize == 13)
    }

    @Test func monoIsJetBrainsMono() {
        #expect(NSFont.theme(.callout, .mono).familyName == "JetBrains Mono")
        #expect(NSFont.theme(.callout, .mono).isFixedPitch)
    }

    @Test(arguments: [(Font.Weight.regular, 400.0), (.medium, 510), (.semibold, 590)])
    func weightsAreLinearsAxisValues(_ weight: Font.Weight, _ axisValue: Double) {
        #expect(weightAxis(of: NSFont.theme(weight: weight)) == axisValue)
    }

    @Test func headlineDefaultsToSemibold() {
        #expect(weightAxis(of: NSFont.theme(.headline)) == 590)
    }

    private func weightAxis(of font: NSFont) -> Double? {
        let variation = font.fontDescriptor.object(forKey: .variation) as? [NSNumber: NSNumber]
        return variation?[NSNumber(value: 0x7767_6874)]?.doubleValue
    }
}
