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

    @State private var hasAppeared = false
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

            if case .failed(let reason) = model.phase {
                AgentRecordingFailure(reason: reason, retry: model.retry)
                Hairline()
            }

            AgentRecordingFooter(model: model, submit: submit)
        }
        .frame(width: AgentRecordingPanelController.width)
        .editorGlass(in: .rect(cornerRadius: 16))
        .foregroundStyle(EditorTheme.ink)
        .modifier(PanelPresentation(isShown: hasAppeared && model.isPresented))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: onClose)
        .onAppear {
            hasAppeared = true
            focus = model.address.isEmpty ? .address : .instructions
        }
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

/// The panel arrives and leaves the same way: it fades and settles from slightly smaller, anchored
/// at its top. A spring without bounce, so a close during the entrance turns round from where it is;
/// with Reduce Motion, a short cross-fade only.
private struct PanelPresentation: ViewModifier {
    let isShown: Bool

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reducesMotion ? 1 : 0.97, anchor: .top)
            .animation(reducesMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0), value: isShown)
    }
}
