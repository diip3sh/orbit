//
//  WindowPicker.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
@preconcurrency import ScreenCaptureKit

/// Lets the user pick one window with the system content sharing picker.
///
/// The picker is a singleton shared with recording selection. This observer is attached only
/// while picking, and `CaptureEngine` ignores results it did not ask for, so a screenshot never
/// replaces the recording selection.
@MainActor
final class WindowPicker: NSObject {

    private let picker = SCContentSharingPicker.shared
    private var continuation: CheckedContinuation<SCContentFilter?, Never>?

    /// The picked window's filter, or nil when cancelled
    func pick() async -> SCContentFilter? {
        picker.add(self)
        defer {
            picker.remove(self)
            // Removes the system sharing indicator, as CaptureEngine does after a pick
            picker.isActive = false
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            picker.isActive = true
            picker.present(using: .window)
        }
    }

    private func finish(with filter: sending SCContentFilter?) {
        continuation?.resume(returning: filter)
        continuation = nil
    }
}

extension WindowPicker: SCContentSharingPickerObserver {

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in self.finish(with: filter) }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.finish(with: nil) }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in self.finish(with: nil) }
    }
}
