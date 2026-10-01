//
//  QuickAccessView.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The Quick Access card: the screenshot in its own shape on a thin glass edge. Under the pointer it dims
/// and shows Copy and Save, with Close, Recognize Text and Pin in its corners. Drag the screenshot into
/// another app; drag the edge to move the card, or flick it away. It grows from `anchor`, the corner
/// nearest where it opened.
struct QuickAccessView: View {

    let model: QuickAccessViewModel
    let dragger: PanelDragger
    let anchor: UnitPoint
    let size: CGSize

    @State private var isHovering = false

    var body: some View {
        QuickAccessPreview(model: model, showsControls: isHovering)
            .padding(QuickAccessController.inset)
            .frame(width: size.width, height: size.height)
            .background {
                Color.clear
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in dragger.drag() }
                            .onEnded { _ in dragger.end() }
                    )
            }
            .editorGlass(in: .rect(cornerRadius: 16))
            .onHover { isHovering = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovering)
            .panelPresentation(isPresented: model.isPresented, anchor: anchor)
            .allowsWindowActivationEvents(true)
    }
}

/// The screenshot, filling the card unless it's smaller; drag it into another app. Feedback shows over
/// its bottom edge.
private struct QuickAccessPreview: View {

    let model: QuickAccessViewModel
    let showsControls: Bool

    var body: some View {
        // Concentric with the card's 16 pt corners at its 8 pt inset
        let shape = RoundedRectangle(cornerRadius: 8)

        Image(model.preview, scale: 1, label: Text("Screenshot"))
            .resizable()
            .scaledToFit()
            .clipShape(shape)
            .onDrag(model.dragItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                shape.fill(.black.opacity(showsControls ? 0.45 : 0))
                    .allowsHitTesting(false)
            }
            // Kept in the hierarchy while hidden, so ⌘C and ⌘S work without the pointer on the card
            .overlay {
                QuickAccessControls(model: model)
                    // Light buttons on the dimmed shot in either appearance
                    .environment(\.colorScheme, .dark)
                    .opacity(showsControls ? 1 : 0)
            }
            .overlay(alignment: .bottom) {
                if let feedback = model.feedback {
                    Text(feedback.message)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, EditorTheme.smallSpacing)
                        .padding(.vertical, EditorTheme.tightSpacing)
                        // Solid: it sits on the screenshot, which a material would only muddy
                        .background(.black.opacity(0.75), in: .capsule)
                        .padding(6)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .editorMotion(value: model.feedback)
    }
}

/// Close top-left, Recognize Text and Pin top-right, Copy and Save in the middle. Space between them
/// isn't hit-tested, so a drag there starts on the screenshot.
private struct QuickAccessControls: View {

    let model: QuickAccessViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: EditorTheme.tightSpacing) {
                Button("Close", systemImage: "xmark", action: model.close)
                    .help("Close")
                Spacer()
                // Annotate goes first once annotation exists:
                // Button("Annotate", systemImage: "pencil", action: model.annotate)
                Button("Recognize Text", systemImage: "text.viewfinder") { Task { await model.recognizeText() } }
                    .help("Recognize Text")
                    .disabled(model.isRecognizingText)
                Button("Pin", systemImage: "pin", action: model.pin)
                    .help("Pin")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(CornerButtonStyle())
            Spacer(minLength: 0)
            HStack(spacing: EditorTheme.smallSpacing) {
                Button { Task { await model.copy() } } label: { ShortcutLabel(title: "Copy", keys: "⌘C") }
                    .keyboardShortcut("c", modifiers: .command)
                Button { Task { await model.save() } } label: { ShortcutLabel(title: "Save", keys: "⌘S") }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .buttonStyle(.editorPrimary)
            Spacer(minLength: 0)
        }
        .padding(6)
    }
}

/// A button's title with its shortcut beside it, dimmer. VoiceOver reads the shortcut from the button.
private struct ShortcutLabel: View {

    let title: String
    let keys: String

    var body: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Text(title)
            Text(keys)
                .opacity(0.5)
                .accessibilityHidden(true)
        }
    }
}

/// A small dark circle with a white symbol, legible over any screenshot
private struct CornerButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        CornerButton(configuration: configuration)
    }
}

private struct CornerButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let isLit = isEnabled && (isHovered || configuration.isPressed)

        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(.black.opacity(isLit ? 0.8 : 0.55), in: .circle)
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            // The press shows on the frame it lands; only the release eases
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
    }
}
