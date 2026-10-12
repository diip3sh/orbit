//
//  CaptureToolbarIdleControls.swift
//  Reco
//

import SwiftUI

/// Before a screenshot or a take, in groups: close and settings; the three screenshot modes or the three
/// recording modes; for a take, its options; and the action. One highlight in the accent colour marks the
/// mode and slides to the one chosen. Every control answers a key while the bar has key, named in its tooltip.
struct CaptureToolbarIdleControls: View {
    let viewModel: CaptureToolbarViewModel

    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            Button {
                Task { await viewModel.close() }
            } label: {
                Label { Text("Close") } icon: { ToolbarIcon(.toolbarClose) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.captureToolbar)
            // Esc steps back one thing at a time (the picker, a half-drawn area, then the bar), where
            // clicking takes everything away at once
            .captureToolbarTooltip("Close", shortcut: CaptureToolbarShortcut.close.symbol)
            .background {
                Button("Cancel") { Task { await viewModel.cancel() } }
                    .keyboardShortcut(CaptureToolbarShortcut.close.key, modifiers: [])
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            CaptureToolbarMoreMenu(settings: viewModel.settings)
        }
        .captureToolbarPill()

        modeGroup(CaptureToolbarMode.allCases.filter { $0.records == viewModel.mode.records })

        // Countdown, audio and camera apply only to a take; a screenshot has its own timer
        if viewModel.mode.records {
            HStack(spacing: 2) {
                CaptureToolbarOptions(viewModel: viewModel)
            }
            .captureToolbarPill()
        } else {
            CaptureToolbarCountdownMenu(title: "Self-Timer", duration: Bindable(viewModel.settings).screenshotTimer)
                .captureToolbarPill()
        }

        Button {
            Task { await viewModel.performAction() }
        } label: {
            // Its key in the label, so it needs no tooltip; none while the key does nothing
            HStack(spacing: EditorTheme.tightSpacing) {
                Text(viewModel.actionTitle)
                if viewModel.canPerformAction {
                    Text(CaptureToolbarShortcut.action.symbol)
                        .font(.theme(.body, weight: .semibold, .mono))
                        .foregroundStyle(EditorTheme.onAccent.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.captureToolbarAction)
        .keyboardShortcut(CaptureToolbarShortcut.action.key, modifiers: [])
        .disabled(!viewModel.canPerformAction)
    }

    private func modeGroup(_ modes: [CaptureToolbarMode]) -> some View {
        HStack(spacing: 2) {
            ForEach(modes) { mode in
                let isSelected = viewModel.mode == mode
                Button {
                    // Choosing a mode also opens what records it, so Record isn't a step on the way
                    Task { await viewModel.pick(mode) }
                } label: {
                    CaptureModeIcon(mode: mode)
                        .accessibilityLabel(mode.title)
                }
                .buttonStyle(.captureToolbar(isSelected: isSelected))
                .background {
                    if isSelected {
                        Color.clear
                            .captureToolbarLive(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .matchedGeometryEffect(id: "mode", in: selection)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .captureToolbarTooltip(mode.shortTitle, shortcut: .mode(mode))
            }
        }
        .editorMotion(value: viewModel.mode)
        .captureToolbarPill()
    }
}
