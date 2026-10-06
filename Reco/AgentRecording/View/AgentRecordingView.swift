//
//  AgentRecordingView.swift
//  Reco
//

import SwiftUI

/// The Record with AI Agent panel's content (spec 0007): where to record, what the video should
/// show, and below them the agent, its model and Record. A Spotlight-style bar over Liquid Glass.
struct AgentRecordingView: View {
    @Bindable var model: AgentRecordingViewModel
    let onClose: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @FocusState private var focus: AgentRecordingViewModel.Field?

    var body: some View {
        VStack(spacing: 0) {
            // Cancel, in the footer, stays live while a run goes
            VStack(spacing: 0) {
                HStack(spacing: EditorTheme.mediumSpacing) {
                    Image(systemName: "globe")
                        .foregroundStyle(EditorTheme.dim)
                        .accessibilityHidden(true)
                    TextField("Website address", text: $model.address)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focus, equals: .address)
                        .onSubmit(submit)
                    Button("Sign In…") {
                        if let field = model.signIn() {
                            focus = field
                        }
                    }
                    .buttonStyle(.editorGhost)
                    .help("Open the page to sign in. The agent records what you see signed in.")
                }
                .padding(EditorTheme.spacing)

                Hairline()

                TextField(
                    "Describe the video: hover Pricing, click Start free trial, scroll to the FAQ…",
                    text: $model.instructions,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3, reservesSpace: true)
                .focused($focus, equals: .instructions)
                .onSubmit(submit)
                .padding(EditorTheme.spacing)
            }
            .disabled(model.isRunning)

            Hairline()

            if let reason = model.panelFailure {
                AgentRecordingFailure(reason: reason, retry: model.retry)
                Hairline()
            }

            AgentRecordingFooter(model: model, submit: submit)
        }
        .frame(width: AgentRecordingPanelController.width)
        .editorGlass(in: .rect(cornerRadius: 16))
        .foregroundStyle(EditorTheme.ink)
        .panelPresentation(isPresented: model.isPresented, anchor: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: onClose)
        .onAppear { focus = model.address.isEmpty ? .address : .instructions }
        .editorMotion(value: model.phase)
    }

    /// Runs the request, or puts the cursor in the field that stops it.
    private func submit() {
        if let field = model.submit() {
            focus = field
        }
    }
}

/// A line between the panel's rows; brighter with Increase Contrast.
private struct Hairline: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(contrast == .increased ? EditorTheme.dim : EditorTheme.hairline)
            .frame(height: 1)
    }
}
