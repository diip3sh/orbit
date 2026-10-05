//
//  CaptureSourcePicker.swift
//  Reco
//

import CoreGraphics
@preconcurrency import ScreenCaptureKit

/// The capture toolbar's own picker: the windows or displays to record, as thumbnails above the bar,
/// instead of the system's full-screen picker. Reports a choice up through `onPick`, a close without
/// one through `onCancel`.
@MainActor
@Observable
final class CaptureSourcePicker {

    /// What is being chosen; nil when closed
    private(set) var kind: CaptureSource.Kind?

    /// Nil while loading
    private(set) var sources: [CaptureSource]?
    private(set) var thumbnails: [CaptureSource.ID: CGImage] = [:]
    private(set) var failed = false

    /// Set when loading has run long enough to need a spinner: a warm open shows the tiles instead, so
    /// the picker arrives in one move rather than as a spinner that is replaced a moment later
    private(set) var isWaiting = false

    /// How long a load runs before the picker says it is waiting
    nonisolated static let waitingDelay = Duration.milliseconds(250)

    @ObservationIgnored var onPick: ((SCContentFilter) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?

    @ObservationIgnored private var filters: [CaptureSource.ID: SCContentFilter] = [:]
    @ObservationIgnored private var loading: [Task<Void, Never>] = []

    var isOpen: Bool { kind != nil }

    /// Whether the panel has anything to put on screen: the tiles, a failure, or a wait worth showing
    var hasSomethingToShow: Bool { sources != nil || failed || isWaiting }

    func open(_ kind: CaptureSource.Kind) {
        reset()
        self.kind = kind
        loading.append(Task {
            try? await Task.sleep(for: Self.waitingDelay)
            guard !Task.isCancelled else { return }
            isWaiting = true
        })
        loading.append(Task { await load(kind) })
    }

    func pick(_ source: CaptureSource) {
        guard let filter = filters[source.id] else { return }
        reset()
        onPick?(filter)
    }

    /// Closes without a choice
    func cancel() {
        guard isOpen else { return }
        reset()
        onCancel?()
    }

    private func reset() {
        loading.forEach { $0.cancel() }
        loading = []
        kind = nil
        sources = nil
        thumbnails = [:]
        filters = [:]
        failed = false
        isWaiting = false
    }

    private func load(_ kind: CaptureSource.Kind) async {
        let entries: [CaptureSourceLoader.Entry]
        do {
            entries = try await CaptureSourceLoader.entries(of: kind)
        } catch {
            // Without Screen Recording there is nothing to list; asking for it is what a take does too
            guard !Task.isCancelled else { return }
            CGRequestScreenCaptureAccess()
            failed = true
            return
        }
        guard !Task.isCancelled else { return }

        filters = Dictionary(entries.map { ($0.source.id, $0.filter) }) { first, _ in first }
        sources = entries.map(\.source)
        // Each thumbnail shows as soon as it is drawn; ScreenCaptureKit draws them side by side
        for entry in entries {
            let id = entry.source.id
            let filter = entry.thumbnailFilter
            loading.append(Task {
                guard let image = await CaptureSourceLoader.thumbnail(of: filter), !Task.isCancelled else { return }
                thumbnails[id] = image
            })
        }
    }
}
