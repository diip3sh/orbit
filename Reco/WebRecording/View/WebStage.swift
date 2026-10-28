//
//  WebStage.swift
//  Reco
//

import AppKit
import SwiftUI

/// The live page on a dot grid, with the script's cursor at the playhead, the selected clip's tag beside it and
/// what an agent found; the tool rail on the left, the cursor's position and the page's scale along the bottom,
/// and banners for a failed render and pick mode.
struct WebStage: View {
    @Bindable var viewModel: WebRecordingViewModel

    /// The page's size on screen, which scales the cursor from viewport pixels.
    @State private var pageSize = CGSize.zero

    private static let cornerRadius: CGFloat = 12

    /// Around the page: room for the rail on either side, and for the bottom row under it.
    private static let pageInsets = EdgeInsets(top: 44, leading: 88, bottom: 76, trailing: 88)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        let viewport = viewModel.script.viewport
        let camera = Self.camera(for: viewModel)
        let scale = pageSize.width > 0 ? pageSize.width / viewport.width : 0

        WebPreviewView(controller: viewModel.preview)
            .background(.white)
            .overlay {
                if viewModel.script.url == nil {
                    ContentUnavailableView {
                        Label("Enter a Web Address", systemImage: "globe")
                    } description: {
                        Text("Type an address above and press Return. Then add hovers, clicks, typing and scrolls on the timeline, or ask the agent to.")
                    }
                    // Over the whole blank page, not a box on it
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EditorTheme.stage)
                }
            }
            .overlay(alignment: .topLeading) {
                if scale > 0 {
                    WebAgentHighlights(rects: viewModel.agentHighlights, scale: scale)
                }
            }
            .overlay(alignment: .topLeading) {
                if let location = viewModel.cursorPreview, scale > 0 {
                    WebCursorMarker(scale: scale)
                        .offset(x: location.x * scale, y: location.y * scale)
                        .allowsHitTesting(false)
                }
            }
            // The camera, as the editor will draw it: magnified with its focus moved to the middle
            .scaleEffect(camera.scale)
            .offset(x: (0.5 - camera.focus.x) * pageSize.width * camera.scale, y: (0.5 - camera.focus.y) * pageSize.height * camera.scale)
            // Unmagnified, where the camera puts the cursor
            .overlay(alignment: .topLeading) {
                if let tag = targetTag, let location = viewModel.cursorPreview, scale > 0 {
                    let point = Self.onScreen(CGPoint(x: location.x * scale, y: location.y * scale), camera: camera, in: pageSize)
                    WebTargetTag(action: tag.action, target: tag.target.name)
                        .offset(x: point.x - 6, y: point.y + 22)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .editorMotion(value: [camera.scale, camera.focus.x, camera.focus.y])
            .clipShape(shape)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pageSize = $0 }
            .overlay {
                shape.strokeBorder(viewModel.isPicking ? EditorTheme.accent : EditorTheme.hairline, lineWidth: viewModel.isPicking ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .aspectRatio(viewport, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Self.pageInsets)
            .background {
                StageDotGrid()
            }
            .overlay(alignment: .leading) {
                WebToolRail(viewModel: viewModel)
                    .padding(.leading, EditorTheme.spacing)
                    .padding(.top, Self.pageInsets.top)
                    .padding(.bottom, Self.pageInsets.bottom)
            }
            .overlay(alignment: .bottom) {
                bottomRow(scale: scale)
            }
            .overlay(alignment: .bottom) {
                banners
            }
            .editorMotion(value: targetTag?.id)
            .editorMotion(value: viewModel.agentHighlights)
            .editorMotion(value: viewModel.isPicking)
            .editorMotion(value: viewModel.renderError)
            .editorMotion(value: viewModel.pageError)
    }

    /// The selected cursor clip while the playhead is in it, whose tag follows the cursor.
    private var targetTag: PointerClip? {
        guard let clip = viewModel.selectedPointerClip, clip.range.contains(viewModel.playhead) else { return nil }
        return clip
    }

    /// The cursor's place in the page, in CSS pixels, and the page's scale on screen.
    private func bottomRow(scale: CGFloat) -> some View {
        HStack {
            if let location = viewModel.cursorPreview {
                Text(verbatim: "x \(Int(location.x.rounded()))   y \(Int(location.y.rounded()))")
                    .font(.theme(.subheadline, .mono))
                    .foregroundStyle(EditorTheme.dim)
                    .accessibilityLabel("Cursor at \(Int(location.x.rounded())), \(Int(location.y.rounded()))")
            }
            Spacer()
            if scale > 0 {
                Label {
                    Text("Fit · \(scale, format: .percent.precision(.fractionLength(0)))")
                } icon: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .labelStyle(WebScaleLabelStyle())
                .font(.theme(.callout, .mono))
                .foregroundStyle(EditorTheme.dim)
                .padding(.leading, 10)
                .padding(.trailing, EditorTheme.mediumSpacing)
                .frame(height: 28)
                .webField()
                .help("The page fits the stage at this scale")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, EditorTheme.mediumSpacing)
    }

    private var banners: some View {
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
                .editorSurface(in: .capsule)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 52)
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

    /// Where a point of the unmagnified page shows once the camera has scaled it about the page's middle and
    /// moved its focus there.
    static func onScreen(_ point: CGPoint, camera: (scale: Double, focus: CGPoint), in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (point.x - size.width / 2) * camera.scale + (0.5 - camera.focus.x) * size.width * camera.scale,
            y: size.height / 2 + (point.y - size.height / 2) * camera.scale + (0.5 - camera.focus.y) * size.height * camera.scale
        )
    }
}

/// The selected clip's action and element on an accent tag under the cursor, as the take's plan names it.
private struct WebTargetTag: View {
    let action: PointerClip.Action
    let target: String

    var body: some View {
        HStack(spacing: 6) {
            Text(action.title)
                .font(.theme(.subheadline, weight: .semibold))
            Text(target)
                .font(.theme(.subheadline, .mono))
                .opacity(0.75)
                .lineLimit(1)
        }
        .foregroundStyle(EditorTheme.onAccent)
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(EditorTheme.accentFill, in: .rect(cornerRadius: 5, style: .continuous))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// The scale badge's magnifier, a little apart from its text.
private struct WebScaleLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
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
