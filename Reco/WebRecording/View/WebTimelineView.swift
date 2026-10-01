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

        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
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
                        onSelect: select, onMove: viewModel.moveClip, onMoveStart: viewModel.moveClipStart, onMoveEnd: viewModel.moveClipEnd
                    ) { clip, isDragged in
                        TimelineBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged) {
                            Label(Self.name(of: clip.target), systemImage: clip.action == .click ? "cursorarrow.click" : "cursorarrow")
                        }
                    }
                    .help("Hovers and clicks: the cursor is on the clip's target from its start to its end")

                    TimelineLane(
                        clips: script.scrolls, duration: duration, width: width,
                        onSelect: select, onMove: viewModel.moveClip, onMoveStart: viewModel.moveClipStart, onMoveEnd: viewModel.moveClipEnd
                    ) { clip, isDragged in
                        let start = script.scrollOffset(at: clip.range.lowerBound).y
                        TimelineBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged) {
                            Label {
                                Text("\(start, format: .number.precision(.fractionLength(0))) → \(clip.offset.y, format: .number.precision(.fractionLength(0)))")
                            } icon: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
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

    /// The target's element as the last step of its selector, e.g. `button.buy`, or its point.
    private static func name(of target: WebTarget) -> String {
        if let selector = target.selector, let last = selector.split(separator: " > ").last {
            return String(last)
        }
        return "\(Int(target.point.x)), \(Int(target.point.y))"
    }
}

/// Buttons that add a hover, click or scroll at the playhead, and the playhead's time.
private struct WebTimelineHeader: View {
    let viewModel: WebRecordingViewModel

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Button("Hover", systemImage: "cursorarrow") {
                viewModel.addPointerClip(.hover)
            }
            .help("Add a hover at the playhead, then click its element in the page")
            .disabled(!viewModel.canAddPointerClip)

            Button("Click", systemImage: "cursorarrow.click") {
                viewModel.addPointerClip(.click)
            }
            .help("Add a click at the playhead, then click its element in the page")
            .disabled(!viewModel.canAddPointerClip)

            Button("Scroll", systemImage: "arrow.up.arrow.down") {
                Task {
                    await viewModel.addScrollClip()
                }
            }
            .help("Add a scroll at the playhead to where the page is scrolled now")
            .disabled(!viewModel.canAddScrollClip)

            Spacer()

            HStack(spacing: EditorTheme.tightSpacing) {
                Text(Self.format(viewModel.playhead))
                Text("/ \(Self.format(viewModel.script.duration))")
                    .foregroundStyle(EditorTheme.dim)
            }
            .font(.callout)
            .monospaced()
        }
        .buttonStyle(.editorGhost)
        .labelStyle(.titleAndIcon)
    }

    /// "0:02.50"
    private static func format(_ time: Double) -> String {
        Duration.seconds(time).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 2)))
    }
}
