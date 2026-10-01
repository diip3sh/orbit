//
//  EditCoalescing.swift
//  Reco
//

import Foundation

/// Which edits share an undo step: a coalescing edit joins the previous one when that was a
/// coalescing edit with the same name less than a second before, so dragging a slider is undone at
/// once. Shared by the editor and the Web Recording window.
nonisolated struct EditCoalescing {

    /// How soon a coalescing edit must follow the previous one to join its undo step.
    static let interval = Duration.seconds(1)

    /// The latest edit, if it was coalescing.
    private var last: (actionName: String, time: ContinuousClock.Instant)?

    /// Whether an edit named `actionName` at `now` joins the previous edit's undo step. Records it
    /// for the next one.
    mutating func joinsPrevious(_ actionName: String, coalescing: Bool, at now: ContinuousClock.Instant = .now) -> Bool {
        defer { last = coalescing ? (actionName, now) : nil }
        guard coalescing, let last else { return false }
        return last.actionName == actionName && now - last.time < Self.interval
    }

    /// Ends the chain, on undo and redo: the next edit gets an undo step of its own.
    mutating func reset() {
        last = nil
    }
}
