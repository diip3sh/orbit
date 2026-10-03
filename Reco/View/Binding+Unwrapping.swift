//
//  Binding+Unwrapping.swift
//  Reco
//

import SwiftUI

extension Binding {

    /// `source`'s value while it has one, like `Binding(_:)` on an optional, but it never traps.
    /// `Binding(_:)` force-unwraps on every read, and views under an `if let` read once more after the
    /// value goes `nil` (a deleted or deselected clip), which crashed the app; this one keeps returning
    /// the last value until those views are gone.
    init?(unwrapping source: Binding<Value?>) {
        guard let value = source.wrappedValue else { return nil }
        var last = value
        self.init {
            if let current = source.wrappedValue {
                last = current
            }
            return last
        } set: {
            source.wrappedValue = $0
        }
    }
}
