//
//  WebStage.swift
//  Reco
//

import AppKit
import SwiftUI

/// The address bar over the live page, raised off the dark stage like the editor's preview, with the
/// script's cursor at the playhead, and banners for a failed render and pick mode.
struct WebStage: View {
    @Bindable var viewModel: WebRecordingViewModel

    /// The page's size on screen, which scales the cursor from viewport pixels.
    @State private var pageSize = CGSize.zero

    private static let cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
        let viewport = viewModel.script.viewport

        VStack(spacing: EditorTheme.spacing) {
            WebAddressBar(viewModel: viewModel)

            WebPreviewView(controller: viewModel.preview)
                .background(.white)
                .overlay(alignment: .topLeading) {
                    if let location = viewModel.cursorPreview, pageSize.width > 0 {
                        WebCursorMarker(scale: pageSize.width / viewport.width)
                            .offset(x: location.x * pageSize.width / viewport.width, y: location.y * pageSize.width / viewport.width)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(shape)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { pageSize = $0 }
                .shadow(color: .black.opacity(0.7), radius: 24, y: 24)
                .overlay {
                    shape.strokeBorder(viewModel.isPicking ? EditorTheme.accent : .white.opacity(0.1), lineWidth: viewModel.isPicking ? 2 : 1)
                }
                .aspectRatio(viewport, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding([.horizontal, .top], EditorTheme.largeSpacing)
        .padding(.bottom, EditorTheme.spacing)
        .background {
            StageDotGrid()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: EditorTheme.smallSpacing) {
                if let error = viewModel.renderError {
                    HStack(spacing: EditorTheme.smallSpacing) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                        Button("Dismiss", systemImage: "xmark") {
                            viewModel.renderError = nil
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(EditorTheme.dim)
                    }
                    .padding(.horizontal, EditorTheme.mediumSpacing)
                    .padding(.vertical, EditorTheme.smallSpacing)
                    .editorGlass(in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if viewModel.isPicking {
                    HStack(spacing: EditorTheme.mediumSpacing) {
                        Label("Click the element to aim the clip at", systemImage: "scope")
                        Button("Stop") {
                            viewModel.togglePicking()
                        }
                        .buttonStyle(.editorGhost)
                        .keyboardShortcut(.cancelAction)
                    }
                    .padding(.leading, EditorTheme.mediumSpacing)
                    .padding(EditorTheme.tightSpacing)
                    .editorGlass(in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, EditorTheme.largeSpacing)
        }
        .overlay {
            if let progress = viewModel.renderProgress {
                VStack(alignment: .trailing, spacing: EditorTheme.mediumSpacing) {
                    ExportProgressBar(progress: progress, title: "Rendering…")
                    Button("Cancel") {
                        viewModel.cancelRender()
                    }
                    .buttonStyle(.editorGhost)
                    .keyboardShortcut(.cancelAction)
                }
                .frame(width: 280)
                .padding(EditorTheme.spacing)
                .editorGlass(in: .rect(cornerRadius: 16))
                .transition(.opacity)
            }
        }
        .editorMotion(value: viewModel.isPicking)
        .editorMotion(value: viewModel.renderProgress == nil)
        .editorMotion(value: viewModel.renderError)
    }
}

/// The system arrow where the script's cursor is, its tip on the point, at the page's scale.
private struct WebCursorMarker: View {
    let scale: CGFloat

    var body: some View {
        let arrow = NSCursor.arrow
        Image(nsImage: arrow.image)
            .resizable()
            .frame(width: arrow.image.size.width * scale, height: arrow.image.size.height * scale)
            .offset(x: -arrow.hotSpot.x * scale, y: -arrow.hotSpot.y * scale)
    }
}
