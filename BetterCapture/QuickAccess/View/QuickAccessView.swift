//
//  QuickAccessView.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The Quick Access card: close, grab handle, preview (drag it out), toolbar. Drag the card by its background.
struct QuickAccessView: View {

    let model: QuickAccessViewModel

    var body: some View {
        VStack {
            ZStack {
                // Decorative: the background under it moves the card
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                HStack {
                    Button("Close", systemImage: "xmark", action: model.close)
                        .help("Close")
                    Spacer()
                }
            }
            QuickAccessPreview(model: model)
            QuickAccessToolbar(model: model)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(8)
        .frame(width: QuickAccessController.cardSize.width, height: QuickAccessController.cardSize.height)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .gesture(WindowDragGesture())
        }
        .clipShape(.rect(cornerRadius: 12))
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
            .clipShape(.rect(cornerRadius: 6))
            .onDrag(model.dragItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if let feedback = model.feedback {
                    Text(feedback.message)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thickMaterial, in: .capsule)
                        .padding(6)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: model.feedback)
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
            ToolbarButton(title: "Save", systemImage: "square.and.arrow.down") { Task { await model.save() } }
            ToolbarButton(title: "Recognize Text", systemImage: "text.viewfinder") { Task { await model.recognizeText() } }
                .disabled(model.isRecognizingText)
            ToolbarButton(title: "Pin", systemImage: "pin", action: model.pin)
        }
        .imageScale(.large)
    }
}

/// An icon button whose title is its tooltip and accessibility label
private struct ToolbarButton: View {

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .help(title)
            .frame(maxWidth: .infinity)
    }
}
