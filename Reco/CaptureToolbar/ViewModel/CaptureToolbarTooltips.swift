//
//  CaptureToolbarTooltips.swift
//  Reco
//

import CoreGraphics
import Observation

/// The tooltip that names the control under the pointer: what it is, or what it does now, kept up to
/// date while the pointer stays on it. `midX` is the control's mid-x in the bar's coordinate space, so the
/// tooltip can centre on it. The controller turns this into a window above the bar.
///
/// As the system's help tags: the first tooltip waits for the pointer to rest, then, while one is up or
/// has just gone, the next control's shows at once and takes its place without leaving and coming back.
@MainActor
@Observable
final class CaptureToolbarTooltips {

    /// The pointer must rest this long before the first tooltip appears, so sweeping the bar doesn't flicker it
    nonisolated static let restDelay = Duration.milliseconds(300)

    /// How long after a tooltip goes the next one still shows at once
    nonisolated static let warmPeriod = Duration.milliseconds(500)

    /// Leaving a control waits this long before the tooltip goes, so moving to its neighbour (whose
    /// hover lands just after) swaps the text in place instead of fading out and in
    nonisolated static let switchGrace = Duration.milliseconds(80)

    struct Target: Equatable {
        var text: String
        let midX: CGFloat
    }

    /// The control under the pointer; kept until another is hovered
    private(set) var target: Target?

    /// Whether the tooltip is on screen; false while it plays its exit
    private(set) var isShown = false

    /// Whether the tooltip sits under the bar (no room above), so its tail points up at the control
    var pointsUp = false

    /// Dragging the bar takes tooltips away until the pointer moves again
    @ObservationIgnored private var isDragging = false
    @ObservationIgnored private var hiddenAt: ContinuousClock.Instant?
    @ObservationIgnored private var pendingHide: Task<Void, Never>?

    /// How long a control just hovered waits before its tooltip shows: none while one is up or just went
    func appearDelay(now: ContinuousClock.Instant = .now) -> Duration {
        if isShown { return .zero }
        if let hiddenAt, now - hiddenAt < Self.warmPeriod { return .zero }
        return Self.restDelay
    }

    func hover(_ text: String, at midX: CGFloat) {
        guard !isDragging else { return }
        pendingHide?.cancel()
        pendingHide = nil
        target = Target(text: text, midX: midX)
        isShown = true
    }

    /// What the hovered control does has changed (Pause became Resume, On became Off), so the text follows it
    func retext(_ text: String) {
        guard isShown, var target = target else { return }
        target.text = text
        self.target = target
    }

    /// The pointer left a control: the tooltip goes after `switchGrace` unless another is hovered first,
    /// or at once (`immediately`) when the bar is dragged or hidden.
    func unhover(immediately: Bool = false) {
        pendingHide?.cancel()
        pendingHide = nil
        guard isShown else { return }
        if immediately {
            hide()
            return
        }
        pendingHide = Task { [weak self] in
            try? await Task.sleep(for: Self.switchGrace)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func setDragging(_ dragging: Bool) {
        isDragging = dragging
        if dragging { unhover(immediately: true) }
    }

    private func hide() {
        pendingHide = nil
        isShown = false
        hiddenAt = .now
    }
}
