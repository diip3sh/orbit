//
//  CaptureToolbarView.swift
//  Reco
//

import SwiftUI

/// The capture toolbar: every control for a screenshot or a take, on screen rather than in the menu bar
/// popover, in groups of solid surfaces. Dragged from anywhere between its controls; reports its own size so the panel fits it, and the bar's
/// own so the panel knows where the bar sits inside it.
///
/// The picker for a window or a display is drawn in this same view, above the bar, rather than in a
/// window of its own: a second window that took key would have macOS draw the bar's controls as
/// inactive for as long as it was open.
struct CaptureToolbarView: View {
    let viewModel: CaptureToolbarViewModel
    let presence: PanelPresence
    let pickerPresence: PanelPresence
    let tooltips: CaptureToolbarTooltips
    let onSizeChange: (CGSize) -> Void
    let onBarSizeChange: (CGSize) -> Void
    let onDrag: () -> Void
    let onDragEnd: () -> Void

    /// The bar's ground, also what the mode badges are cut out of
    static let ground = EditorTheme.surface

    /// What is live, chosen or switched on, as a fill: the action, the mode, options in use. Whatever sits
    /// on it is `EditorTheme.onAccent`.
    static let live = EditorTheme.accentFill

    /// A take in progress: its time and pill, red as the system's own recording indicators, so it
    /// never reads as just another option that's on
    static let recording = Color.red

    /// Room around the bar for its entrance blur
    static let margin: CGFloat = 12

    /// How out of focus the bar pops in from. Under `margin`, so the blur's spread stays in the window.
    static let entranceBlur: CGFloat = 8

    /// Between the picker and the bar, so the tiles read as their own layer rather than the bar's top
    static let pickerGap: CGFloat = 10

    /// The bar's own coordinate space: controls report their mid-x in it, so tooltips centre on them
    nonisolated static let barSpaceName = "capture-toolbar-bar"

    private var recorder: RecorderViewModel { viewModel.recorder }

    private enum Phase: Equatable {
        case idle, countingDown, recording, saving
    }

    private var phase: Phase {
        if recorder.state == .stopping { return .saving }
        if recorder.isRecording { return .recording }
        return recorder.countdown.isRunning ? .countingDown : .idle
    }

    var body: some View {
        VStack(spacing: Self.pickerGap) {
            // Kept mounted while its exit plays, then taken away so the window shrinks back
            if pickerPresence.isShown {
                CaptureSourcePickerView(picker: viewModel.sources)
            }
            bar
        }
        .fixedSize()
        // Pops in where it is, from a blur, with no direction; inside the margin so the blur isn't clipped
        .panelPresentation(isPresented: presence.isShown, anchor: .bottom, blur: Self.entranceBlur)
        .padding(Self.margin)
        // The panel's size: the bar, and the picker while it is up
        .onGeometryChange(for: CGSize.self, of: \.size) { onSizeChange($0) }
        // Held to the window's bottom, where placement puts the bar. The window narrows only after the
        // change has played, so for that moment it is taller than its content (the picker just went),
        // and centred the bar rose by half the picker's height, then dropped back as the window shrank.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// The bar itself: the groups of pills, and what a drag moves
    private var bar: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            switch phase {
            case .idle:
                CaptureToolbarIdleControls(viewModel: viewModel)
            case .countingDown:
                countdown
            case .recording:
                CaptureToolbarLiveControls(recorder: recorder)
            case .saving:
                HStack(spacing: EditorTheme.smallSpacing) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Saving…")
                        .foregroundStyle(EditorTheme.dim)
                }
                .padding(.horizontal, EditorTheme.mediumSpacing)
                .frame(minHeight: 36)
                .captureToolbarPill()
            }
        }
        .coordinateSpace(.named(Self.barSpaceName))
        // One group of controls replaces the last: the branches cross-fade (the default transition) and
        // the bar's width follows. Nothing scales and nothing moves sideways — this happens on every
        // start and stop, many times a day, so it stays a state change rather than a performance.
        .editorMotion(value: phase)
        .foregroundStyle(EditorTheme.ink)
        .environment(tooltips)
        // Between and around the controls is where the bar is grabbed
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { _ in onDrag() }
                .onEnded { _ in onDragEnd() }
        )
        .onGeometryChange(for: CGSize.self, of: \.size) { onBarSizeChange($0) }
    }

    private var countdown: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Text("Recording in \(recorder.countdown.remaining ?? 0)")
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .editorMotion(EditorTheme.quickMotion, value: recorder.countdown.remaining)
                .padding(.horizontal, EditorTheme.mediumSpacing)
            Button("Cancel") {
                recorder.cancelCountdown()
            }
            .buttonStyle(.captureToolbar)
            .captureToolbarTooltip("Cancel", shortcut: .close)
        }
        .captureToolbarPill()
    }
}
