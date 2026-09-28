//
//  RecordingCountdown.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Counts down the seconds before a recording starts.
///
/// `remaining` drives the on-screen number and the menu bar. The one-second wait is injectable
/// so tests don't wait whole seconds.
@MainActor
@Observable
final class RecordingCountdown {

    /// Seconds left, or `nil` when no countdown is running
    private(set) var remaining: Int?

    var isRunning: Bool {
        remaining != nil
    }

    @ObservationIgnored private var task: Task<Void, Never>?
    private let sleepOneSecond: @MainActor () async throws -> Void

    init(sleepOneSecond: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }) {
        self.sleepOneSecond = sleepOneSecond
    }

    /// Counts down from `seconds`, one per second, then calls `onFinish`. Replaces a countdown already running.
    /// - Returns: The countdown's task; it ends once `onFinish` has returned or the countdown was cancelled.
    @discardableResult
    func start(seconds: Int, onFinish: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        cancel()
        if seconds > 0 {
            remaining = seconds
        }

        let task = Task {
            for second in stride(from: seconds, to: 0, by: -1) {
                guard !Task.isCancelled else { return }
                remaining = second
                // A cancelled sleep throws; the cancellation checks end the countdown
                try? await sleepOneSecond()
            }
            guard !Task.isCancelled else { return }
            remaining = nil
            self.task = nil
            await onFinish()
        }
        self.task = task
        return task
    }

    /// Stops the countdown without calling `onFinish`.
    func cancel() {
        task?.cancel()
        task = nil
        remaining = nil
    }
}
