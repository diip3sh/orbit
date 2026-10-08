//
//  QuickAccessView.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The Quick Access card: the screenshot in its own shape on a thin glass edge, with Copy and Save along
/// its bottom, which confirm on the button. Under the pointer it dims and shows Close, Recognize Text and Pin in its corners. Drag the screenshot into
/// another app; drag the edge to move the card, or flick it away; Esc closes it. It grows from `anchor`, the corner
/// nearest where it opened.
struct QuickAccessView: View {

    let model: QuickAccessViewModel
    let dragger: PanelDragger
    let anchor: UnitPoint

    @State private var isHovering = false

    var body: some View {
        // The shot's shape, which a background changes; the controller refits the panel to the same size
        let size = QuickAccessController.cardSize(for: model.screenshot.pointSize)

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
            // Esc closes the card, like the Close button and a flick. The panel is key while it shows, so
            // this is the only way Esc reaches it: without it the key went nowhere.
            .onExitCommand { model.close() }
    }
}

/// The screenshot, filling the card unless it's smaller; drag it into another app. Feedback shows over
/// its middle, clear of Copy and Save.
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
            .overlay {
                QuickAccessControls(model: model)
                    // Light buttons on the dimmed shot in either appearance
                    .environment(\.colorScheme, .dark)
                    .opacity(showsControls ? 1 : 0)
            }
            // Always shown, so ⌘C and ⌘S work without the pointer on the card
            .overlay(alignment: .bottom) {
                QuickAccessActions(model: model)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                if let feedback = model.feedback, feedback.isToast {
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

/// Close top-left; Background, Hide Sensitive Info, Recognize Text and Pin top-right. Space between them isn't
/// hit-tested, so a drag there starts on the screenshot.
private struct QuickAccessControls: View {

    let model: QuickAccessViewModel

    var body: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Button(action: model.close) { Label { Text("Close") } icon: { LineIcon(.hugeiconsCancel) } }
                .help("Close")
            Spacer()
            // Annotate goes first once annotation exists:
            // Button("Annotate", systemImage: "pencil", action: model.annotate)
            Button { Task { await model.toggleBackground() } } label: {
                Label { Text(model.hasBackground ? "Remove Background" : "Add Background") } icon: {
                    LineIcon(.hugeiconsBackground)
                        // The one control on the card that stays on: the accent says so
                        .foregroundStyle(model.hasBackground ? AnyShapeStyle(EditorTheme.accent) : AnyShapeStyle(.white))
                }
            }
            .help(model.hasBackground ? "Remove the background" : "Put the screenshot on the background from Settings")
            .disabled(model.isChangingBackground)
            Button { Task { await model.hideSensitiveInfo() } } label: {
                Label { Text("Hide Sensitive Info") } icon: { LineIcon(.hugeiconsViewOffSlash) }
            }
            .help("Pixelate emails, phone numbers, card numbers and API keys")
            .disabled(model.isHidingSensitiveInfo)
            Button { Task { await model.recognizeText() } } label: {
                Label { Text("Recognize Text") } icon: { LineIcon(.hugeiconsScanText) }
            }
            .help("Recognize Text")
            .disabled(model.isRecognizingText)
            Button(action: model.pin) { Label { Text("Pin") } icon: { LineIcon(.hugeiconsPin) } }
                .help("Pin")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(CornerButtonStyle())
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Copy and Save along the bottom edge
private struct QuickAccessActions: View {

    let model: QuickAccessViewModel

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Button { Task { await model.copy() } } label: {
                ShortcutLabel(title: "Copy", keys: "⌘C", confirmation: "Copied", isConfirmed: model.feedback == .copied)
            }
            .keyboardShortcut("c", modifiers: .command)
            Button { Task { await model.save() } } label: {
                ShortcutLabel(title: "Save", keys: "⌘S", confirmation: "Saved", isConfirmed: model.feedback == .saved)
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        // Two equal ways out of the card: secondary's accent text over the shot read as a disabled Copy
        .buttonStyle(.editorPrimary)
        .padding(6)
    }
}

/// A button's title with its shortcut beside it, dimmer, or a tick and `confirmation` once done. Both are
/// always laid out, so the button is as wide as the wider one and never wraps or jumps when it confirms.
/// VoiceOver reads the shortcut from the button.
private struct ShortcutLabel: View {

    let title: String
    let keys: String
    let confirmation: String
    let isConfirmed: Bool

    var body: some View {
        ZStack {
            HStack(spacing: EditorTheme.tightSpacing) {
                Text(title)
                Text(keys)
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
            .opacity(isConfirmed ? 0 : 1)
            .accessibilityHidden(isConfirmed)
            HStack(spacing: EditorTheme.tightSpacing) {
                LineIcon(.hugeiconsCheckmarkCircle)
                    .accessibilityHidden(true)
                Text(confirmation)
            }
            .opacity(isConfirmed ? 1 : 0)
            .accessibilityHidden(!isConfirmed)
        }
        .lineLimit(1)
        .fixedSize()
        .editorMotion(EditorTheme.quickMotion, value: isConfirmed)
    }
}
