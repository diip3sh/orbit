//
//  WebStage.swift
//  Reco
//

import AppKit
import SwiftUI

/// The address bar over the live page, with the script's cursor at the playhead, what an agent found,
/// and banners for a failed render and pick mode.
struct WebStage: View {
    @Bindable var viewModel: WebRecordingViewModel

    /// The page's size on screen, which scales the cursor from viewport pixels.
    @State private var pageSize = CGSize.zero

    private static let cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
        let viewport = viewModel.script.viewport
        let camera = Self.camera(for: viewModel)

        VStack(spacing: EditorTheme.spacing) {
            WebAddressBar(viewModel: viewModel)

            WebPreviewView(controller: viewModel.preview)
                .background(.white)
                .overlay {
                    if viewModel.script.url == nil {
                        ContentUnavailableView {
                            Label("Enter a Web Address", systemImage: "globe")
                        } description: {
                            Text("Type an address above and press Return. Then add hovers, clicks, typing and scrolls on the timeline, or ask the AI Agent to.")
                        }
                        // Over the whole blank page, not a box on it
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(EditorTheme.stage)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if pageSize.width > 0 {
                        WebAgentHighlights(rects: viewModel.agentHighlights, scale: pageSize.width / viewport.width)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let location = viewModel.cursorPreview, pageSize.width > 0 {
                        WebCursorMarker(scale: pageSize.width / viewport.width)
                            .offset(x: location.x * pageSize.width / viewport.width, y: location.y * pageSize.width / viewport.width)
                            .allowsHitTesting(false)
                    }
                }
                // The camera, as the editor will draw it: magnified with its focus moved to the middle
                .scaleEffect(camera.scale)
                .offset(x: (0.5 - camera.focus.x) * pageSize.width * camera.scale, y: (0.5 - camera.focus.y) * pageSize.height * camera.scale)
                .editorMotion(value: [camera.scale, camera.focus.x, camera.focus.y])
                .clipShape(shape)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { pageSize = $0 }
                // The page sits in the window like the browser it stands for: an edge and a soft
                // shadow, not lifted off a backdrop
                .overlay {
                    shape.strokeBorder(viewModel.isPicking ? EditorTheme.accent : EditorTheme.hairline, lineWidth: viewModel.isPicking ? 2 : 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                .aspectRatio(viewport, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding([.horizontal, .top], EditorTheme.largeSpacing)
        .padding(.bottom, EditorTheme.spacing)
        .overlay(alignment: .bottom) {
            VStack(spacing: EditorTheme.smallSpacing) {
                if let error = viewModel.pageError {
                    StatusBanner(message: error) { viewModel.pageError = nil }
                }
                if let error = viewModel.renderError {
                    StatusBanner(message: error) { viewModel.renderError = nil }
                }
                if viewModel.isPicking {
                    HStack(spacing: EditorTheme.mediumSpacing) {
                        Label("Click the element to aim the clip at", systemImage: "scope")
                        Button {
                            viewModel.togglePicking()
                        } label: {
                            Label("Stop", image: "button-close")
                        }
                        .buttonStyle(.editorSecondary)
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
        .editorMotion(value: viewModel.agentHighlights)
        .editorMotion(value: viewModel.isPicking)
        .editorMotion(value: viewModel.renderError)
        .editorMotion(value: viewModel.pageError)
    }
}

extension WebStage {

    /// The camera at the playhead: the zoom in effect and its focus, as fractions of the page, kept
    /// where the magnified view stays inside it. Unzoomed, the whole page, and always while picking: the
    /// web view's clicks don't follow a SwiftUI transform, so a pick would land beside its element.
    /// A script that shows elements frames the one shown at the playhead, as the take will.
    static func camera(for viewModel: WebRecordingViewModel) -> (scale: Double, focus: CGPoint) {
        let script = viewModel.script
        let whole = (1.0, CGPoint(x: 0.5, y: 0.5))
        guard !viewModel.isPicking else { return whole }
        if WebCamera.showsElements(script) {
            guard let shown = viewModel.shownPreview, let visible = WebCamera.visiblePart(of: shown, in: script.viewport),
                  let fit = WebCamera.fit(visible, in: script.viewport) else { return whole }
            return (fit.scale, fit.center)
        }
        guard let zoom = WebCamera.zoom(at: viewModel.playhead, in: script) else { return whole }
        let point = viewModel.cursorPreview ?? zoom.clip.target.point
        let focus = CGPoint(x: point.x / script.viewport.width, y: point.y / script.viewport.height)
        return (zoom.scale, ZoomSegment.clamped(focus, scale: zoom.scale))
    }
}

/// The elements an agent found, outlined in the accent at the page's scale (spec 0008).
private struct WebAgentHighlights: View {
    let rects: [CGRect]
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(rects.indices, id: \.self) { index in
                let rect = rects[index]
                let shape = RoundedRectangle(cornerRadius: 4)
                shape
                    .fill(EditorTheme.accent.opacity(0.12))
                    .overlay { shape.strokeBorder(EditorTheme.accent, lineWidth: 1.5) }
                    .frame(width: rect.width * scale, height: rect.height * scale)
                    .offset(x: rect.minX * scale, y: rect.minY * scale)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
