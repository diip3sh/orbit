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

    /// The tile Return records: the first once loaded, then where ← → or the pointer put it
    private(set) var highlighted: CaptureSource.ID?

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

    func highlight(_ id: CaptureSource.ID) {
        guard sources?.contains(where: { $0.id == id }) == true else { return }
        highlighted = id
    }

    /// ← and →: the tile before or after the highlighted one, stopping at the ends
    func moveHighlight(by offset: Int) {
        guard let sources else { return }
        highlighted = CaptureSourceGrid.neighbour(of: highlighted, by: offset, in: sources.map(\.id))
    }

    /// Return: records the highlighted tile
    func pickHighlighted() {
        guard let source = sources?.first(where: { $0.id == highlighted }) else { return }
        pick(source)
    }

    /// Picks a display without showing anything: `id`'s, or the first when it is nil or gone
    func pickDisplay(_ id: CGDirectDisplayID?) {
        reset()
        loading.append(Task {
            do {
                let entries = try await CaptureSourceLoader.entries(of: .display)
                guard !Task.isCancelled else { return }
                guard let entry = entries.first(where: { $0.source.id == id }) ?? entries.first else {
                    onCancel?()
                    return
                }
                onPick?(entry.filter)
            } catch {
                guard !Task.isCancelled else { return }
                CGRequestScreenCaptureAccess()
                onCancel?()
            }
        })
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
        highlighted = nil
    }

    /// Lays out the loaded tiles with the first highlighted, so Return records it straight away
    func show(_ sources: [CaptureSource]) {
        self.sources = sources
        highlighted = sources.first?.id
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
        show(entries.map(\.source))
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
