//
//  BindingUnwrappingTests.swift
//  RecoTests
//

import SwiftUI
import Testing
@testable import Reco

@MainActor
struct BindingUnwrappingTests {

    @Test func nilGivesNoBinding() {
        var value: Int?
        let source = Binding { value } set: { value = $0 }

        #expect(Binding(unwrapping: source) == nil)
    }

    @Test func readsAndWritesThroughWhileThereIsAValue() throws {
        var value: Int? = 1
        let source = Binding { value } set: { value = $0 }
        let binding = try #require(Binding(unwrapping: source))

        binding.wrappedValue = 2
        #expect(value == 2)
        value = 3
        #expect(binding.wrappedValue == 3)
    }

    @Test func keepsTheLastValueInsteadOfTrappingOnceItsGone() throws {
        var value: Int? = 5
        let source = Binding { value } set: { value = $0 }
        let binding = try #require(Binding(unwrapping: source))
        _ = binding.wrappedValue

        value = nil

        #expect(binding.wrappedValue == 5)
    }
}
