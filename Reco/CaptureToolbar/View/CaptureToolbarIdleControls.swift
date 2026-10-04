//
//  CaptureToolbarIdleControls.swift
//  Reco
//

import SwiftUI

/// Before a screenshot or a take, in groups: close; the three screenshot modes or the three recording
/// modes; for a take, its options; more; and the action. One highlight in the accent colour marks the
/// mode and slides to the one chosen.
struct CaptureToolbarIdleControls: View {
    let viewModel: CaptureToolbarViewModel

    @Namespace private var selection

    var body: some View {
        Button {
            Task { await viewModel.close() }
        } label: {
            Label { Text("Close") } icon: { ToolbarIcon(.toolbarClose) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.captureToolbar)
        .keyboardShortcut(.cancelAction)
        .captureToolbarTooltip("Close")
        .captureToolbarPill()

        modeGroup(CaptureToolbarMode.allCases.filter { $0.records == viewModel.mode.records })

        // Countdown, audio and camera apply only to a take
        if viewModel.mode.records {
            HStack(spacing: 2) {
                CaptureToolbarOptions(viewModel: viewModel)
            }
            .captureToolbarPill()
        }

        CaptureToolbarMoreMenu(settings: viewModel.settings)
            .captureToolbarPill()

        Button(viewModel.mode.actionTitle) {
            Task { await viewModel.performAction() }
        }
        .buttonStyle(.captureToolbarAction)
        .keyboardShortcut(.defaultAction)
        .disabled(!viewModel.canPerformAction)
        .captureToolbarTooltip(viewModel.mode.title)
        .captureToolbarPill(tint: CaptureToolbarView.live)
    }

    private func modeGroup(_ modes: [CaptureToolbarMode]) -> some View {
        HStack(spacing: 2) {
            ForEach(modes) { mode in
                let isSelected = viewModel.mode == mode
                Button {
                    viewModel.select(mode)
                } label: {
                    CaptureModeIcon(mode: mode, ground: isSelected ? CaptureToolbarView.live : CaptureToolbarView.ground)
                        .accessibilityLabel(mode.title)
                }
                .buttonStyle(.captureToolbar(isSelected: isSelected))
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CaptureToolbarView.live)
                            .matchedGeometryEffect(id: "mode", in: selection)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .captureToolbarTooltip(mode.title)
            }
        }
        .editorMotion(value: viewModel.mode)
        .captureToolbarPill()
    }
}
