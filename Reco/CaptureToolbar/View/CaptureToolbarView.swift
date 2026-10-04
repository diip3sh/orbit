//
//  CaptureToolbarView.swift
//  Reco
//

import SwiftUI

/// The capture toolbar: every control for a screenshot or a take, on screen rather than in the menu bar
/// popover, in groups of dark glass. Dark in both appearances, as it floats over whatever is on screen.
/// Dragged from anywhere between its controls; reports its size so the panel fits it.
struct CaptureToolbarView: View {
    let viewModel: CaptureToolbarViewModel
    let presence: PanelPresence
    let tooltips: CaptureToolbarTooltips
    let onSizeChange: (CGSize) -> Void
    let onDrag: () -> Void
    let onDragEnd: () -> Void

    /// The bar's ground, also what the mode badges are cut out of
    static let ground = Color(white: 0.1)

    /// What is live, chosen or switched on: the take's time, the action, the mode, options in use. The
    /// system accent colour, so the bar follows the user's theme.
    static let live = Color.accentColor

    /// Room around the bar for its glass's edge and shadow
    static let margin: CGFloat = 12

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
        EditorGlassGroup {
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
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, EditorTheme.mediumSpacing)
                    .frame(minHeight: 36)
                    .captureToolbarPill()
                }
            }
            .coordinateSpace(.named(Self.barSpaceName))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .editorMotion(value: phase)
        .environment(\.colorScheme, .dark)
        .environment(tooltips)
        .fixedSize()
        .padding(Self.margin)
        // Between and around the controls is where the bar is grabbed
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { _ in onDrag() }
                .onEnded { _ in onDragEnd() }
        )
        .onGeometryChange(for: CGSize.self, of: \.size) { onSizeChange($0) }
        .panelPresentation(isPresented: presence.isShown, anchor: .bottom)
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
            .keyboardShortcut(.cancelAction)
            .captureToolbarTooltip("Cancel Countdown")
        }
        .captureToolbarPill()
    }
}
