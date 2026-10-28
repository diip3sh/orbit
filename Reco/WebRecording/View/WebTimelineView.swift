//
//  WebTimelineView.swift
//  Reco
//

import SwiftUI

/// The script's timeline under the stage: the playhead's time and the script's length on the left, the transport
/// in the middle and what Render makes (or its progress) on the right; the ruler with the playhead's knob; the
/// Cursor and Scroll lanes with their clips; and a count of the clips. Dragging the ruler or a lane scrubs the page
/// and cursor; Space plays, ← and → step a frame, ⌫ deletes the selected clip.
struct WebTimelineView: View {
    let viewModel: WebRecordingViewModel

    /// The lanes' width, which the ruler and the playhead share.
    @State private var width: CGFloat = 0
    @FocusState private var isFocused: Bool

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    /// From the panel's edge to the lanes, holding their names.
    private static let labelWidth: CGFloat = 88
    private static let rulerHeight: CGFloat = 28
    private static let laneHeight: CGFloat = 70
    private static let laneSpacing: CGFloat = 8

    /// A lane's clips, and the selected one's range a little around it.
    private static let clipHeight: CGFloat = 56
    private static let rangeHeight: CGFloat = 80

    var body: some View {
        let script = viewModel.script
        let viewport = TimelineViewport(duration: script.duration)

        VStack(spacing: 0) {
            WebTransportRow(viewModel: viewModel)
                .padding(.top, EditorTheme.mediumSpacing)
                .padding(.horizontal, 20)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Self.laneSpacing) {
                    Color.clear.frame(height: Self.rulerHeight + 10 - Self.laneSpacing)
                    laneName("Cursor")
                    laneName("Scroll")
                }
                .frame(width: Self.labelWidth, alignment: .leading)

                VStack(spacing: 0) {
                    ruler(viewport)
                    lanes(script, viewport: viewport)
                        .padding(.top, 10)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
            .padding(.top, EditorTheme.tightSpacing)
            .padding(.leading, 20)
            .padding(.trailing, EditorTheme.mediumSpacing)

            footer
                .padding(.top, EditorTheme.largeSpacing)
                .padding(.bottom, EditorTheme.mediumSpacing)
                .padding(.horizontal, 20)
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

    private func laneName(_ name: LocalizedStringKey) -> some View {
        Text(name)
            .font(.theme(.callout))
            .foregroundStyle(EditorTheme.dim)
            .frame(height: Self.laneHeight)
    }

    /// The ruler, with the playhead's knob; dragging it scrubs.
    private func ruler(_ viewport: TimelineViewport) -> some View {
        TimelineRuler(viewport: viewport)
            .frame(height: Self.rulerHeight)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard width > 0 else { return }
                        viewModel.seek(to: value.location.x / width * viewModel.script.duration)
                    }
            )
            .overlay(alignment: .topLeading) {
                PlayheadKnob()
                    .offset(x: playheadX - Playhead.knobWidth / 2, y: 6)
                    .opacity(width > 0 && viewModel.script.duration > 0 ? 1 : 0)
            }
    }

    /// The Cursor and Scroll lanes, with the playhead's line through them.
    private func lanes(_ script: WebScript, viewport: TimelineViewport) -> some View {
        VStack(spacing: Self.laneSpacing) {
            cursorLane(script, viewport: viewport)
                .help("Hovers and clicks: the cursor is on the clip's target from its start to its end")
            scrollLane(script, viewport: viewport)
                .help("Scrolls: the page moves from where the previous one ended")
        }
        .overlay(alignment: .topLeading) {
            PlayheadLine()
                .offset(x: playheadX - Playhead.lineWidth / 2)
                .opacity(width > 0 && script.duration > 0 ? 1 : 0)
                .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard width > 0 else { return }
                    isFocused = true
                    viewModel.seek(to: value.location.x / width * script.duration)
                }
                .onEnded { value in
                    if abs(value.translation.width) < Self.clickTolerance {
                        viewModel.selection = nil
                    }
                }
        )
        .coordinateSpace(.named(TrimHandle.coordinateSpace))
    }

    /// Each cursor clip's action and target, marked when the camera zooms around it.
    private func cursorLane(_ script: WebScript, viewport: TimelineViewport) -> some View {
        lane(script.pointer, viewport: viewport) { clip, isDragged in
            let zooms = WebCamera.zooms(on: clip, in: script)
            WebClipBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged, height: Self.clipHeight) {
                Label {
                    HStack(spacing: EditorTheme.tightSpacing) {
                        Text(Self.title(of: clip))
                        if zooms {
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundStyle(EditorTheme.dim)
                                .accessibilityLabel("Zoomed")
                        }
                    }
                } icon: {
                    Image(systemName: clip.action.symbol)
                }
            } detail: {
                Text(clip.target.name)
            }
            .help("\(Self.title(of: clip)) · \(clip.target.name)")
        }
    }

    /// Each scroll's span in CSS pixels, and its easing as a curve.
    private func scrollLane(_ script: WebScript, viewport: TimelineViewport) -> some View {
        lane(script.scrolls, viewport: viewport) { clip, isDragged in
            let start = script.scrollOffset(at: clip.range.lowerBound).y
            let span = Text("\(Int(start.rounded()).description) → \(Int(clip.offset.y.rounded()).description) px")
            WebClipBlock(isSelected: clip.id == viewModel.selection, isDragged: isDragged, height: Self.clipHeight) {
                Label { span } icon: { Image(systemName: ScrollClip.symbol) }
            } detail: {
                WebEasingCurve(easing: clip.easing)
                    .stroke(EditorTheme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(height: 14)
                    .padding(.trailing, EditorTheme.tightSpacing)
            }
            .help(span)
        }
    }

    /// A lane's track, with a hairline at each of the ruler's labelled times, and its clips. The clips' row is
    /// taller than the track, so the selected clip's range can stand out of it.
    private func lane<Clip: TimelineClip, Block: View>(
        _ clips: [Clip], viewport: TimelineViewport, @ViewBuilder block: @escaping (Clip, Bool) -> Block
    ) -> some View {
        TimelineLane(
            clips: clips, viewport: viewport, width: width,
            onSelect: select, onMove: viewModel.moveClip, onMoveStart: viewModel.moveClipStart, onMoveEnd: viewModel.moveClipEnd,
            selection: viewModel.selection, height: Self.rangeHeight, handle: TrimHandle.Pill(height: 28, outset: 8),
            block: block
        )
        .padding(.vertical, (Self.laneHeight - Self.rangeHeight) / 2)
        .background {
            let shape = RoundedRectangle(cornerRadius: WebPanel.radius, style: .continuous)
            ZStack {
                shape.fill(EditorTheme.stage.opacity(0.6))
                Canvas { context, size in
                    guard viewport.visible > 0 else { return }
                    var lines = Path()
                    for time in TimelineRuler.majors(in: viewport, width: size.width) {
                        lines.addRect(CGRect(x: viewport.x(at: time, width: size.width), y: 0, width: 1, height: size.height))
                    }
                    context.fill(lines, with: .color(EditorTheme.ink.opacity(0.04)))
                }
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }

    /// How many clips the script has, and its length.
    private var footer: some View {
        let count = viewModel.script.pointer.count + viewModel.script.scrolls.count
        return Text("^[\(count) clip](inflect: true) · \(viewModel.script.duration, format: .number.precision(.fractionLength(1))) s")
            .font(.theme(.callout))
            .foregroundStyle(EditorTheme.dim)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }

    private var playheadX: CGFloat {
        let duration = viewModel.script.duration
        return duration > 0 ? viewModel.playhead / duration * width : 0
    }

    private func select(_ id: UUID) {
        isFocused = true
        viewModel.selection = id
    }

    /// The action, and for typing what it types: "Type “Orbit”".
    private static func title(of clip: PointerClip) -> String {
        if clip.action == .type {
            return "\(clip.action.title) “\(clip.text ?? "")”"
        }
        return clip.action.title
    }
}

/// The time and the script's length, the transport, and what Render makes or how far it is.
private struct WebTransportRow: View {
    @Bindable var viewModel: WebRecordingViewModel

    /// Lengths the menu offers, in seconds.
    private static let presetLengths: [Double] = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        ZStack {
            HStack(spacing: EditorTheme.mediumSpacing) {
                time
                Spacer(minLength: EditorTheme.smallSpacing)
                trail
            }

            transport
        }
        .frame(height: 40)
        .editorMotion(value: viewModel.renderProgress == nil)
    }

    /// "00:04.40 / 10.00": the playhead's leading zeros dim, and the length a menu.
    private var time: some View {
        HStack(alignment: .firstTextBaseline, spacing: EditorTheme.smallSpacing) {
            let text = Self.format(viewModel.playhead)
            let lead = Self.dimmedPrefix(of: text)
            Text("\(Text(lead).foregroundStyle(EditorTheme.dim))\(Text(text.dropFirst(lead.count)).foregroundStyle(EditorTheme.ink))")
                .font(.theme(.title3, weight: .medium, .mono))
                .accessibilityLabel(text)

            Menu {
                Picker("Length", selection: $viewModel.duration) {
                    ForEach(lengths, id: \.self) { length in
                        Text("\(length, format: .number) s").tag(length)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: EditorTheme.tightSpacing) {
                    Text("/ \(Self.formatLength(viewModel.script.duration))")
                        .font(.theme(.callout, .mono))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(EditorTheme.dim)
                .contentShape(.rect)
                .headerMenuAnchor()
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .help("The script's length")
            .disabled(!viewModel.isEditable)
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// The menu's lengths that keep every clip, with the script's own.
    private var lengths: [Double] {
        let lengths = Self.presetLengths.filter { $0 >= viewModel.script.minimumAllowedDuration }
        return Set(lengths + [viewModel.script.duration]).sorted()
    }

    /// Previous frame, play/pause, next frame.
    private var transport: some View {
        HStack(spacing: 10) {
            Button("Previous Frame", systemImage: "backward.frame.fill") {
                viewModel.step(byFrames: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .help("Step back a frame (←)")
            .disabled(!viewModel.canStep)
            .buttonStyle(EditorIconButtonStyle(diameter: 32))

            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    // The triangle's weight sits left of its box's middle
                    .padding(.leading, viewModel.isPlaying ? 0 : 2)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(viewModel.isPlaying ? "Pause (Space)" : "Play the script in the page (Space)")
            .disabled(!viewModel.canPlay)
            .buttonStyle(WebInkCircleButtonStyle())

            Button("Next Frame", systemImage: "forward.frame.fill") {
                viewModel.step(byFrames: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .help("Step forward a frame (→)")
            .disabled(!viewModel.canStep)
            .buttonStyle(EditorIconButtonStyle(diameter: 32))
        }
    }

    /// What Render makes, or the render's progress while one runs.
    @ViewBuilder
    private var trail: some View {
        if let progress = viewModel.renderProgress {
            HStack(spacing: EditorTheme.smallSpacing) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .accessibilityLabel("Rendering")
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.theme(.subheadline, .mono))
                    .foregroundStyle(EditorTheme.dim)
                Button("Cancel Render", systemImage: "xmark") {
                    viewModel.cancelRender()
                }
                .buttonStyle(EditorIconButtonStyle(diameter: 24))
                .keyboardShortcut(.cancelAction)
                .help("Cancel the render (Esc)")
            }
            .transition(.opacity)
        } else {
            let size = viewModel.script.videoSize
            HStack(spacing: EditorTheme.mediumSpacing) {
                Text("\(WebScript.frameRate) fps")
                Text(size.pixels)
            }
            .font(.theme(.subheadline, .mono))
            .foregroundStyle(EditorTheme.dim)
            .help("Render makes a movie this size, at this frame rate")
            .transition(.opacity)
        }
    }

    /// "00:04.40".
    private static func format(_ time: Double) -> String {
        Duration.seconds(time).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }

    /// "10.00", or "1:30.00" from a minute.
    private static func formatLength(_ time: Double) -> String {
        time < 60
            ? time.formatted(.number.precision(.fractionLength(2)))
            : Duration.seconds(time).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 2)))
    }

    /// The zeros and colons before the time's first figure that counts, keeping the one before the point: "00:0"
    /// of "00:04.40".
    static func dimmedPrefix(of text: String) -> String {
        let whole = text.prefix { $0 != "." }.dropLast()
        return String(whole.prefix { $0 == "0" || $0 == ":" })
    }
}

/// A clip on a lane: a raised card with its icon and name over a detail line, the accent ring when selected and,
/// behind it, the selected clip's range standing a little out of it. The icon alone when the clip is too short.
private struct WebClipBlock<Title: View, Detail: View>: View {
    let isSelected: Bool
    let isDragged: Bool
    let height: CGFloat
    @ViewBuilder let title: Title
    @ViewBuilder let detail: Detail

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: EditorTheme.radius, style: .continuous)
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: WebPanel.radius, style: .continuous)
                    .fill(EditorTheme.accent.opacity(0.06))
                    .padding(.horizontal, -8)
                    .allowsHitTesting(false)
            }

            shape
                .fill(EditorTheme.raised)
                .overlay {
                    shape.fill(EditorTheme.ink.opacity(isHovered || isDragged ? 0.04 : 0))
                }
                .overlay {
                    shape.strokeBorder(isSelected ? EditorTheme.accent : EditorTheme.ink.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                }
                .overlay(alignment: .leading) {
                    ViewThatFits(in: .horizontal) {
                        VStack(alignment: .leading, spacing: 6) {
                            heading
                            detail
                                .font(.theme(.subheadline, .mono))
                                .foregroundStyle(EditorTheme.dim)
                        }
                        heading
                            .labelStyle(.iconOnly)
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                }
                .frame(height: height)
                .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: 6, y: 3)
        }
        .contentShape(.rect)
        .pointerStyle(isDragged ? .grabActive : .grabIdle)
        .onHover { isHovered = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
    }

    private var heading: some View {
        title
            .labelStyle(WebClipLabelStyle())
            .font(.theme(.callout, weight: .semibold))
            .foregroundStyle(EditorTheme.ink)
    }
}

private struct WebClipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.system(size: 11, weight: .medium))
            configuration.title
        }
    }
}

/// A scroll's easing as a curve across the clip, from where it starts (bottom left) to where it ends.
nonisolated struct WebEasingCurve: Shape {
    let easing: Easing

    func path(in rect: CGRect) -> Path {
        Path { path in
            let steps = 24
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let point = CGPoint(x: rect.minX + progress * rect.width, y: rect.maxY - easing(progress) * rect.height)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }
}
