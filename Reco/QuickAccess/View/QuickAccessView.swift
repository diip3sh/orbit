//
//  QuickAccessView.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The Quick Access card: close, grab handle, preview (drag it out), toolbar. Drag the card by its
/// background; a flick throws it off screen. It grows from `anchor`, the corner nearest where it opened.
struct QuickAccessView: View {

    let model: QuickAccessViewModel
    let dragger: PanelDragger
    let anchor: UnitPoint

    var body: some View {
        VStack {
            ZStack {
                // Decorative: the background under it moves the card
                Image(systemName: "ellipsis")
                    .foregroundStyle(EditorTheme.faint)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                HStack {
                    Button("Close", systemImage: "xmark", action: model.close)
                        .buttonStyle(.editorIcon)
                        .help("Close")
                    Spacer()
                }
            }
            QuickAccessPreview(model: model)
            QuickAccessToolbar(model: model)
        }
        .labelStyle(.iconOnly)
        .padding(8)
        .frame(width: QuickAccessController.cardSize.width, height: QuickAccessController.cardSize.height)
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
        .foregroundStyle(EditorTheme.ink)
        .panelPresentation(isPresented: model.isPresented, anchor: anchor)
        .allowsWindowActivationEvents(true)
    }
}

/// The screenshot, aspect-fit; drag it into another app. Feedback shows over its bottom edge.
private struct QuickAccessPreview: View {

    let model: QuickAccessViewModel

    var body: some View {
        Image(model.preview, scale: 1, label: Text("Screenshot"))
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 8))
            .onDrag(model.dragItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if let feedback = model.feedback {
                    Text(feedback.message)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        // Solid: it sits on the card's glass, which can't carry another
                        .background(EditorTheme.stage.opacity(0.9), in: .capsule)
                        .padding(6)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .editorMotion(value: model.feedback)
    }
}

/// Copy, Save, Recognize Text and Pin, sharing the width equally
private struct QuickAccessToolbar: View {

    let model: QuickAccessViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Annotate goes first once annotation exists:
            // ToolbarButton(title: "Annotate", systemImage: "pencil", action: model.annotate)
            ToolbarButton(title: "Copy", systemImage: "doc.on.doc") { Task { await model.copy() } }
                .keyboardShortcut("c", modifiers: .command)
            ToolbarButton(title: "Save", systemImage: "square.and.arrow.down") { Task { await model.save() } }
                .keyboardShortcut("s", modifiers: .command)
            ToolbarButton(title: "Recognize Text", systemImage: "text.viewfinder") { Task { await model.recognizeText() } }
                .disabled(model.isRecognizingText)
            ToolbarButton(title: "Pin", systemImage: "pin", action: model.pin)
        }
    }
}

/// An icon button whose title is its tooltip and accessibility label
private struct ToolbarButton: View {

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .buttonStyle(.editorIcon)
            .help(title)
            .frame(maxWidth: .infinity)
    }
}
