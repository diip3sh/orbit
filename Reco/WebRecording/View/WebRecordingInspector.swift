//
//  WebRecordingInspector.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's inspector: the selected clip (stepping through the clips, its action, target, zoom
/// and timing) or the page (viewport, resolution, length), and what Render makes.
struct WebRecordingInspector: View {
    @Bindable var viewModel: WebRecordingViewModel

    enum Tab {
        case clip, page
    }

    @State private var tab = Tab.clip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WebSegmentedTrack(selection: $tab, options: [
                .init(value: .clip, title: "Clip", symbol: "cursorarrow"),
                .init(value: .page, title: "Page", symbol: "globe")
            ])
            .padding([.horizontal, .top], WebPanel.padding)

            ScrollView {
                VStack(alignment: .leading, spacing: EditorTheme.largeSpacing) {
                    switch tab {
                    case .clip: clipTab
                    case .page: WebPageSettings(viewModel: viewModel)
                    }
                }
                .padding(WebPanel.padding)
            }
            .scrollIndicators(.never)
            // A render plays the script as it was
            .disabled(!viewModel.isEditable)

            Text("""
                Render makes a \(viewModel.script.videoSize.pixels), \(WebScript.frameRate) fps movie in the \
                recordings folder and opens it in the editor.
                """)
                .font(.theme(.subheadline))
                .foregroundStyle(EditorTheme.dim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(WebPanel.padding)
        }
        .onChange(of: viewModel.selection) { _, selection in
            if selection != nil {
                tab = .clip
            }
        }
    }

    @ViewBuilder private var clipTab: some View {
        WebClipCard(viewModel: viewModel)
        if let clip = Binding(unwrapping: $viewModel.selectedPointerClip) {
            WebPointerClipSettings(viewModel: viewModel, clip: clip)
        } else if let clip = Binding(unwrapping: $viewModel.selectedScrollClip) {
            WebScrollClipSettings(viewModel: viewModel, clip: clip)
        }
        if viewModel.selection != nil {
            WebClipTiming(viewModel: viewModel)
        }
    }
}

/// The selected clip's name and kind beside its icon, and arrows that step to the clip before or after it.
private struct WebClipCard: View {
    let viewModel: WebRecordingViewModel

    var body: some View {
        let isSelected = viewModel.selection != nil
        HStack(spacing: EditorTheme.mediumSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? EditorTheme.accent : EditorTheme.dim)
                .frame(width: 36, height: 36)
                .background(isSelected ? EditorTheme.accent.opacity(0.15) : WebPanel.fill, in: .rect(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.theme(.title3, weight: .semibold))
                    .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.theme(.callout))
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            stepper
        }
        .padding(EditorTheme.mediumSpacing)
        .webField(in: RoundedRectangle(cornerRadius: EditorTheme.radius, style: .continuous))
    }

    private var stepper: some View {
        let count = viewModel.clipOrder.count
        let position = viewModel.selectedClipIndex.map { "\($0 + 1)" } ?? "–"
        return HStack(spacing: 2) {
            step("Previous Clip", symbol: "chevron.left", by: -1)
            Text("\(position) / \(count)")
                .font(.theme(.subheadline, .mono))
                .foregroundStyle(EditorTheme.dim)
                .monospacedDigit()
                .accessibilityLabel("Clip \(position) of \(count)")
            step("Next Clip", symbol: "chevron.right", by: 1)
        }
    }

    private func step(_ title: LocalizedStringKey, symbol: String, by offset: Int) -> some View {
        Button(title, systemImage: symbol) {
            viewModel.selectClip(by: offset)
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 10, weight: .semibold))
        .buttonStyle(EditorIconButtonStyle(diameter: 22))
        .disabled(!viewModel.canSelectClip(by: offset))
    }

    private var symbol: String {
        if let clip = viewModel.selectedPointerClip {
            return clip.action.symbol
        }
        return viewModel.selectedScrollClip == nil ? "square.dashed" : ScrollClip.symbol
    }

    private var title: String {
        if let clip = viewModel.selectedPointerClip {
            return clip.target.name
        }
        if let clip = viewModel.selectedScrollClip {
            return "To \(Int(clip.offset.y)) px"
        }
        return String(localized: "No clip selected")
    }

    private var subtitle: String {
        if let clip = viewModel.selectedPointerClip {
            return String(localized: "\(clip.action.title) · Cursor lane")
        }
        if viewModel.selectedScrollClip != nil {
            return String(localized: "Scroll · Scroll lane")
        }
        return String(localized: "Select on the timeline")
    }
}

/// A cursor clip's action, target, text, what to zoom on and how far.
private struct WebPointerClipSettings: View {
    let viewModel: WebRecordingViewModel
    @Binding var clip: PointerClip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Action")
            HStack(spacing: 0) {
                ForEach(PointerClip.Action.allCases, id: \.self) { action in
                    WebChoiceButton(title: LocalizedStringKey(action.title), key: String(action.key).uppercased(), isSelected: clip.action == action) {
                        clip.action = action
                    } icon: {
                        Image(systemName: action.symbol)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Target")
            WebInspectorField(title: "Target", text: $clip.target.selector.orEmpty, prompt: "CSS selector") {
                Button(viewModel.isPicking ? "Stop" : "Pick", systemImage: "scope", action: viewModel.togglePicking)
                    .buttonStyle(WebPillButtonStyle(height: 32))
                    .help(viewModel.isPicking ? "Stop picking" : "Click an element in the page to make it the target")
            }
        }

        if clip.action == .type {
            VStack(alignment: .leading, spacing: 10) {
                WebFieldTitle("Text")
                WebInspectorField("Text", text: $clip.text.orEmpty, prompt: "What to type", isMultiline: true)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Zoom on") {
                Text("Optional")
                    .font(.theme(.subheadline))
                    .foregroundStyle(EditorTheme.dim)
            }
            WebInspectorField("Zoom on", text: $clip.show.orEmpty, prompt: "Same as target")
        }
        .help("""
            An element to frame during the clip. Once any clip shows one, only those zoom; otherwise the zoom moves \
            in on the target just before the clip and out just after.
            """)

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Zoom") {
                Text(clip.zoom.map { $0.formatted(.number.precision(.fractionLength(1))) + "×" } ?? String(localized: "Off"))
                    .font(.theme(.callout, weight: .semibold, .mono))
                    .foregroundStyle(EditorTheme.ink)
                    .contentTransition(.numericText())
            }
            WebZoomRuler(zoom: $clip.zoom)
        }
    }
}

/// A scroll clip's end position and easing.
private struct WebScrollClipSettings: View {
    @Bindable var viewModel: WebRecordingViewModel
    @Binding var clip: ScrollClip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Scroll to")
            HStack(spacing: EditorTheme.smallSpacing) {
                TextField("Scroll to", value: $viewModel.selectedScrollY, format: .number.precision(.fractionLength(0)).grouping(.never))
                    .textFieldStyle(.plain)
                    .font(.theme(.body, .mono))
                Text("px")
                    .font(.theme(.body, .mono))
                    .foregroundStyle(EditorTheme.dim)
                Button("Use page", systemImage: "arrow.down.to.line") {
                    Task {
                        await viewModel.useCurrentScroll()
                    }
                }
                .buttonStyle(WebPillButtonStyle(height: 32))
                .help("Scroll to where the page is scrolled now")
            }
            .padding(.leading, EditorTheme.spacing)
            .padding(.trailing, 6)
            .frame(height: 44)
            .webField()
        }

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Easing")
            HStack(spacing: 0) {
                ForEach(Easing.allCases, id: \.self) { easing in
                    WebChoiceButton(title: Self.name(of: easing), isSelected: clip.easing == easing) {
                        clip.easing = easing
                    } icon: {
                        WebEasingCurve(easing: easing)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: 20, height: 16)
                    }
                }
            }
        }
    }

    private static func name(of easing: Easing) -> LocalizedStringKey {
        switch easing {
        case .linear: "Linear"
        case .easeIn: "Ease in"
        case .easeOut: "Ease out"
        case .easeInOut: "In & out"
        }
    }
}

/// The selected clip's start and end, in seconds, and how long that is.
private struct WebClipTiming: View {
    @Bindable var viewModel: WebRecordingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Timing") {
                Text("\(viewModel.selectionLength, format: .number.precision(.fractionLength(2))) s long")
                    .font(.theme(.subheadline))
                    .foregroundStyle(EditorTheme.dim)
            }
            HStack(spacing: EditorTheme.smallSpacing) {
                WebNumberCard(title: "Start", value: $viewModel.selectionStart)
                WebNumberCard(title: "End", value: $viewModel.selectionEnd)
            }
        }
    }
}

/// The page's viewport, the resolution it renders at, and the take's length.
private struct WebPageSettings: View {
    @Bindable var viewModel: WebRecordingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Viewport")
            HStack(spacing: 0) {
                ForEach(WebScript.Viewport.allCases, id: \.self) { viewport in
                    WebChoiceButton(
                        title: viewport.title, caption: viewport.size.pixels,
                        isSelected: viewModel.viewport == viewport
                    ) {
                        viewModel.viewport = viewport
                    } icon: {
                        Image(systemName: Self.symbol(of: viewport))
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Resolution") {
                Text(viewModel.script.videoSize.pixels)
                    .font(.theme(.subheadline, .mono))
                    .foregroundStyle(EditorTheme.dim)
            }
            WebSegmentedTrack(selection: $viewModel.scale, options: [
                .init(value: 1, title: "1×"),
                .init(value: 2, title: "2× Retina")
            ])
        }

        VStack(alignment: .leading, spacing: 10) {
            WebFieldTitle("Length") {
                Text("\(Int(WebScript.minimumDuration))–\(Int(WebScript.maximumDuration)) s")
                    .font(.theme(.subheadline))
                    .foregroundStyle(EditorTheme.dim)
            }
            WebNumberCard(title: "Duration", value: $viewModel.duration)
        }
        .help("Renders frame by frame: pages heavy with effects take longer than the video lasts.")
    }

    private static func symbol(of viewport: WebScript.Viewport) -> String {
        switch viewport {
        case .desktop: "desktopcomputer"
        case .laptop: "laptopcomputer"
        case .tablet: "ipad.landscape"
        case .phone: "iphone"
        }
    }
}

private extension Binding where Value == String? {

    /// The text, empty for `nil`; setting it empty makes it `nil`.
    var orEmpty: Binding<String> {
        Binding<String> {
            wrappedValue ?? ""
        } set: {
            wrappedValue = $0.isEmpty ? nil : $0
        }
    }
}
