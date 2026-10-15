//
//  QuickAccessView.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The Quick Access card: the screenshot in its own shape on a thin surface edge, with Copy and Save along
/// its bottom, which confirm on the button. Under the pointer it dims and shows Close, Recognize Text and Pin in its corners. Drag the screenshot into
/// another app; drag the edge to move the card, or flick it away; Esc closes it. It grows from `anchor`, the corner
/// nearest where it opened.
struct QuickAccessView: View {

    let model: QuickAccessViewModel
    let dragger: PanelDragger
    let anchor: UnitPoint

    @State private var isHovering = false

    var body: some View {
        // The shot's shape, which a background changes, or the editor's; the controller sets the panel to the same size
        let size = model.cardSize

        Group {
            if model.isAnnotating, let editor = model.annotation {
                QuickAccessAnnotation(model: model, editor: editor)
            } else {
                QuickAccessPreview(model: model, showsControls: isHovering)
            }
        }
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
            .editorSurface(in: .rect(cornerRadius: 16))
            .onHover { isHovering = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovering)
            .panelPresentation(isPresented: model.isPresented, anchor: anchor)
            .allowsWindowActivationEvents(true)
            // Esc closes the card, like the Close button and a flick, or leaves the editor first. The panel is key
            // while it shows, so this is the only way Esc reaches it: without it the key went nowhere.
            .onExitCommand {
                if model.isAnnotating {
                    Task { await model.finishAnnotating() }
                } else {
                    model.close()
                }
            }
    }
}

/// The card grown into the editor (spec 0015): the tool strip with Copy and Save at its end, which flatten the marks
/// and close the card from here, then the shot with its marks. Esc goes back to the card instead.
private struct QuickAccessAnnotation: View {

    let model: QuickAccessViewModel
    let editor: AnnotationEditor

    var body: some View {
        VStack(spacing: QuickAccessController.inset) {
            HStack(spacing: 0) {
                AnnotationToolbar(editor: editor)
                Spacer(minLength: EditorTheme.smallSpacing)
                // Two equal ways out of the editor: secondary's accent text read as a disabled Copy
                QuickAccessActions(model: model)
                    .buttonStyle(.editorPrimary)
            }
            .frame(height: QuickAccessController.annotationBarHeight)
            AnnotationCanvas(editor: editor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.colorScheme, .dark)
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
                shape.fill(EditorTheme.stage.opacity(showsControls ? 0.45 : 0))
                    .allowsHitTesting(false)
            }
            .overlay {
                QuickAccessControls(model: model)
                    .opacity(showsControls ? 1 : 0)
            }
            // Always shown, so ⌘C and ⌘S work without the pointer on the card
            .overlay(alignment: .bottom) {
                QuickAccessActions(model: model)
                    .buttonStyle(QuickAccessGlassButtonStyle())
                    .padding(6)
            }
            .overlay {
                if let feedback = model.feedback, feedback.isToast {
                    Text(feedback.message)
                        .font(.theme(.caption))
                        .foregroundStyle(EditorTheme.ink)
                        .padding(.horizontal, EditorTheme.smallSpacing)
                        .padding(.vertical, EditorTheme.tightSpacing)
                        .editorSurface(in: .capsule, fill: EditorTheme.raised)
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
            Button(action: model.annotate) { Label("Annotate", systemImage: "pencil.tip") }
                .help("Draw arrows, shapes, text and more on the screenshot")
            Button { Task { await model.toggleBackground() } } label: {
                Label { Text(model.hasBackground ? "Remove Background" : "Add Background") } icon: {
                    LineIcon(.hugeiconsBackground)
                        // The one control on the card that stays on: the accent says so
                        .foregroundStyle(model.hasBackground ? EditorTheme.accent : EditorTheme.ink)
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
            Button { Task { await model.pin() } } label: { Label { Text("Pin") } icon: { LineIcon(.hugeiconsPin) } }
                .help("Pin")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(CornerButtonStyle())
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Copy and Save along the bottom edge, in the style their place gives them
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
    }
}

/// Copy and Save over the shot, and the Library's open picture: on macOS 26 untinted glass, as Safari's toolbar over a
/// page, so the shot shows through and the system picks the label's colour for what is behind it. The accent's
/// prominent glass read as a solid pill over the shot. Before macOS 26, the solid accent capsule. A destructive button
/// is ``QuickAccessDestructiveButtonStyle`` on any system.
struct QuickAccessGlassButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if configuration.role == .destructive {
            Button(configuration).buttonStyle(QuickAccessDestructiveButtonStyle())
        } else if #available(macOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
                    .font(.theme(weight: .medium))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        } else {
            Button(configuration).buttonStyle(.editorPrimary)
        }
    }
}

/// macOS 27's Bordered - Destructive (the Figma community kit): the theme's danger as the label and as a fill of 20%,
/// 28% pressed, 10% disabled with the label at 40%, on what is behind it. Not on glass: the active glass is a light grey
/// (119 of 255 under the Library's dark stage), and the danger label over it and the fill measured 1.5:1; on the stage,
/// 4.6:1 in dark and 4.0:1 in light. A tinted glass (`.glass(.regular.tint(.red))`) came out the plain grey. Sized as
/// the glass large capsule beside it: 14 pt each side of the label and 29 pt high (measured on macOS 27).
struct QuickAccessDestructiveButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.theme(weight: .medium))
            .foregroundStyle(EditorTheme.danger)
            .opacity(isEnabled ? 1 : 0.4)
            .padding(.horizontal, 14)
            .frame(minHeight: 29)
            .background {
                Capsule().fill(EditorTheme.danger.opacity(isEnabled ? (configuration.isPressed ? 0.28 : 0.2) : 0.1))
            }
            .contentShape(.capsule)
    }
}

/// A button's title with its shortcut beside it, dimmer, or a tick and `confirmation` once done. Both are
/// always laid out, so the button is as wide as the wider one and never wraps or jumps when it confirms.
/// VoiceOver reads the shortcut from the button.
struct ShortcutLabel: View {

    let title: String
    let keys: String

    /// `nil` for a button that has nothing to confirm.
    var confirmation: String?
    var isConfirmed = false

    var body: some View {
        ZStack {
            // The keys apart from the title and from each other: at 4 pt and no tracking, ⌘⌫ ran together. It costs
            // the card nothing it had: the confirmations set its buttons' widths, and Copy and Save went from 184 to
            // 185 pt (measured 2026-10-15)
            HStack(spacing: EditorTheme.smallSpacing) {
                Text(title)
                Text(keys)
                    .font(.theme(weight: .medium, .mono))
                    .tracking(1.5)
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
            .opacity(isConfirmed ? 0 : 1)
            .accessibilityHidden(isConfirmed)
            if let confirmation {
                HStack(spacing: EditorTheme.tightSpacing) {
                    LineIcon(.hugeiconsCheckmarkCircle)
                        .accessibilityHidden(true)
                    Text(confirmation)
                }
                .opacity(isConfirmed ? 1 : 0)
                .accessibilityHidden(!isConfirmed)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .editorMotion(EditorTheme.quickMotion, value: isConfirmed)
    }
}
