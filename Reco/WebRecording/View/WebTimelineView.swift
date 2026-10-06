//
//  WebTimelineView.swift
//  Reco
//

import SwiftUI

/// The script's timeline: buttons that add clips at the playhead, a time ruler, the Cursor and
/// Scroll lanes, and the playhead. Dragging scrubs the page and cursor; ⌫ deletes the selected clip.
struct WebTimelineView: View {
    let viewModel: WebRecordingViewModel

    @State private var width: CGFloat = 0
    @FocusState private var isFocused: Bool

    private static let rulerHeight: CGFloat = 16
    private static let labelWidth: CGFloat = 52
    private static let spacing = EditorTheme.smallSpacing

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    var body: some View {
        let script = viewModel.script
        let duration = script.duration

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            WebTimelineHeader(viewModel: viewModel)

            HStack(alignment: .top, spacing: Self.spacing) {
                VStack(alignment: .leading, spacing: Self.spacing) {
                    Color.clear
                        .frame(height: Self.rulerHeight)
                    Text("Cursor")
                        .frame(height: TimelineLane<PointerClip, EmptyView>.height)
                    Text("Scroll")
                        .frame(height: TimelineLane<ScrollClip, EmptyView>.height)
                }
                .font(.caption)
                .foregroundStyle(EditorTheme.dim)
                .frame(width: Self.labelWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: Self.spacing) {
                    TimelineRuler(duration: duration)
                        .frame(height: Self.rulerHeight)

                    TimelineLane(
                        clips: script.pointer, duration: duration, width: width,
                        onSelect: select, onMove: viewModel.moveClip, onMoveStart: viewModel.moveClipStart, onMoveEnd: viewModel.moveClipEnd,
                        selection: viewModel.selection
                    ) { clip, isDragged in
                        let symbol = clip.action.symbol
                        let zooms = WebCamera.zooms(on: clip, in: viewModel.script)
                        TimelineBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged) {
                            // The icon alone on a clip too short for its name, rather than a cut-off name
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: EditorTheme.tightSpacing) {
                                    Label(Self.name(of: clip), systemImage: symbol)
                                    if zooms {
                                        Image(systemName: "plus.magnifyingglass")
                                            .accessibilityLabel("Zoomed")
                                    }
                                }
                                Image(systemName: zooms ? "plus.magnifyingglass" : symbol)
                            }
                        }
                        .help(Self.name(of: clip))
                    }
                    .help("Hovers and clicks: the cursor is on the clip's target from its start to its end")

                    TimelineLane(
                        clips: script.scrolls, duration: duration, width: width,
                        onSelect: select, onMove: viewModel.moveClip, onMoveStart: viewModel.moveClipStart, onMoveEnd: viewModel.moveClipEnd,
                        selection: viewModel.selection
                    ) { clip, isDragged in
                        let start = script.scrollOffset(at: clip.range.lowerBound).y
                        let span = Text("\(start, format: .number.precision(.fractionLength(0))) → \(clip.offset.y, format: .number.precision(.fractionLength(0)))")
                        TimelineBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged) {
                            ViewThatFits(in: .horizontal) {
                                Label { span } icon: { Image(systemName: "arrow.up.arrow.down") }
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        .help(span)
                    }
                    .help("Scrolls: the page moves from where the previous one ended")
                }
                .overlay(alignment: .topLeading) {
                    Playhead(knobHeight: Self.rulerHeight)
                        .offset(x: duration > 0 ? viewModel.playhead / duration * width - Playhead.knobWidth / 2 : 0)
                        .allowsHitTesting(false)
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard width > 0 else { return }
                            isFocused = true
                            viewModel.seek(to: value.location.x / width * duration)
                        }
                        .onEnded { value in
                            if abs(value.translation.width) < Self.clickTolerance {
                                viewModel.selection = nil
                            }
                        }
                )
                .coordinateSpace(.named(TrimHandle.coordinateSpace))
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onDeleteCommand {
            viewModel.deleteSelection()
        }
        .editorMotion(value: script.pointer)
        .editorMotion(value: script.scrolls)
        .editorMotion(value: viewModel.selection)
    }

    private func select(_ id: UUID) {
        isFocused = true
        viewModel.selection = id
    }

    /// What a type clip types, in quotes; otherwise its target.
    private static func name(of clip: PointerClip) -> String {
        if clip.action == .type {
            return "“\(clip.text ?? "")”"
        }
        return name(of: clip.target)
    }

    /// The target's element as the last step of its selector, e.g. `button.buy`, or its point.
    private static func name(of target: WebTarget) -> String {
        if let selector = target.selector, let last = selector.split(separator: " > ").last {
            return String(last)
        }
        return "\(Int(target.point.x)), \(Int(target.point.y))"
    }
}

/// Laid out like the editor's transport: buttons that add a hover, click, typing or scroll at the
/// playhead; Play in the middle; the render's progress while one runs, and the playhead's time.
private struct WebTimelineHeader: View {
    let viewModel: WebRecordingViewModel

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            HStack(spacing: EditorTheme.tightSpacing) {
                Button("Add Hover", systemImage: "cursorarrow") {
                    viewModel.addPointerClip(.hover)
                }
                .help("Add a hover at the playhead, then click its element in the page")
                .disabled(!viewModel.canAddPointerClip)

                Button("Add Click", systemImage: "cursorarrow.click") {
                    viewModel.addPointerClip(.click)
                }
                .help("Add a click at the playhead, then click its element in the page")
                .disabled(!viewModel.canAddPointerClip)

                Button("Add Typing", systemImage: "keyboard") {
                    viewModel.addPointerClip(.type)
                }
                .help("Add typing at the playhead, then click its field in the page")
                .disabled(!viewModel.canAddPointerClip)

                Button("Add Scroll", systemImage: "arrow.up.arrow.down") {
                    Task {
                        await viewModel.addScrollClip()
                    }
                }
                .help("Add a scroll at the playhead to where the page is scrolled now")
                .disabled(!viewModel.canAddScrollClip)

                Button("Delete Clip", systemImage: "trash") {
                    viewModel.deleteSelection()
                }
                .help("Delete the selected clip (⌫)")
                .disabled(viewModel.selection == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(viewModel.isPlaying ? "Pause" : "Play", systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill") {
                viewModel.togglePlayback()
            }
            .buttonStyle(.editorProminentIcon)
            .contentTransition(.symbolEffect(.replace))
            .keyboardShortcut(.space, modifiers: [])
            .help(viewModel.isPlaying ? "Pause (Space)" : "Play the script in the page (Space)")
            .disabled(!viewModel.canPlay)

            HStack(spacing: EditorTheme.mediumSpacing) {
                // Here rather than over the page, which stays in view while it renders
                if let progress = viewModel.renderProgress {
                    // Short enough to sit beside the time at the window's smallest width with the inspector open
                    HStack(spacing: EditorTheme.smallSpacing) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                            .accessibilityLabel("Rendering")
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(EditorTheme.dim)
                        Button("Cancel Render", systemImage: "xmark") {
                            viewModel.cancelRender()
                        }
                        .keyboardShortcut(.cancelAction)
                        .help("Cancel the render (Esc)")
                    }
                    .transition(.opacity)
                }

                HStack(spacing: EditorTheme.tightSpacing) {
                    Text(Self.format(viewModel.playhead))
                    Text("/ \(Self.format(viewModel.script.duration))")
                        .foregroundStyle(EditorTheme.dim)
                }
                .monospaced()
            }
            .font(.callout)
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.editorIcon)
        .editorMotion(value: viewModel.renderProgress == nil)
    }

    /// "00:02.50", as the editor's transport writes it.
    private static func format(_ time: Double) -> String {
        Duration.seconds(time).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
