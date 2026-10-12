//
//  TimelineToolbar.swift
//  Reco
//
//  Created by Diip3sh on 10.10.26.
//

import SwiftUI

/// The timeline's toolbar card: cutting and adding tools on the left, the time and transport in the
/// middle, Copy Frame and the timeline's zoom on the right, and the ruler — with the playhead's
/// knob — under a hairline. Space plays and pauses, ← and → step a frame, S splits at the playhead,
/// Z adds a zoom there, M a mask, ⌫ removes the selection, ⇧⌘C copies the frame and ⌘-/⌘= zoom
/// the timeline.
struct TimelineToolbar: View {
    @Bindable var viewModel: EditorViewModel

    /// Shows a check for a moment after Copy Frame, since nothing else on screen changes.
    @State private var copiedFrame = false

    /// The ruler's width, which the playhead's knob is placed with.
    @State private var rulerWidth: CGFloat = 0

    /// The card's width, which the bar's compact tiers follow. Measured from the proposal, not the
    /// content: the bar's own minimum width would pin the preview column, and a narrow window would
    /// clip the inspector (measured 2026-10-12: the full bar needs ~690 pt, the window is 900+).
    @State private var cardWidth: CGFloat = .infinity

    private static let barHeight: CGFloat = 44
    private static let rulerHeight: CGFloat = 28
    private static let cardHeight: CGFloat = barHeight + 1 + rulerHeight

    /// The tiers a narrowing card drops through: the zoom slider, the duration, the speed menu's name.
    private static let fullWidth: CGFloat = 690
    private static let midWidth: CGFloat = 610
    private static let narrowWidth: CGFloat = 550

    /// 0 shows everything; 1 drops the zoom slider; 2 also drops the duration; 3 also shortens Speed.
    private var tier: Int {
        cardWidth >= Self.fullWidth ? 0 : cardWidth >= Self.midWidth ? 1 : cardWidth >= Self.narrowWidth ? 2 : 3
    }

    var body: some View {
        // The card takes the width it is offered, so the timeline never asks the window for room
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack(spacing: EditorTheme.smallSpacing) {
                    tools
                        .frame(maxWidth: .infinity, alignment: .leading)

                    transport
                        .fixedSize()

                    trail
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, EditorTheme.smallSpacing)
                .frame(height: Self.barHeight)

                EditorTheme.hairline.frame(height: 1)

                TimelineRuler(viewport: viewModel.viewport)
                    .frame(height: Self.rulerHeight)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rulerWidth = $0 }
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.seek(toSource: viewModel.viewport.time(atX: value.location.x, width: rulerWidth))
                            }
                    )
                    .overlay(alignment: .topLeading) {
                        knob
                    }
                    .padding(.horizontal, EditorTheme.spacing)
            }
            .frame(width: proxy.size.width, height: Self.cardHeight)
            .background(EditorTheme.panel, in: .rect(cornerRadius: 14))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(EditorTheme.hairline)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            .buttonStyle(.editorIcon)
            .editorMotion(EditorTheme.quickMotion, value: tier)
            .onAppear { cardWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { _, width in cardWidth = width }
        }
        .frame(height: Self.cardHeight)
    }

    /// Cutting, adding and speed, left to right.
    private var tools: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Button("Split at Playhead", systemImage: "scissors") {
                viewModel.split()
            }
            .keyboardShortcut("s", modifiers: [])
            .help("Split at the playhead (S)")

            let deleted = deletedName
            Button(deleted.map { "Delete \($0)" } ?? "Cut Selection", systemImage: "trash") {
                viewModel.deleteSelection()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .help(deleted.map { "Delete the selected \($0.lowercased()) (⌫)" } ?? "Cut the selected part (⌫)")
            .disabled(!viewModel.canDeleteSelection)

            divider

            Button("Add Zoom", systemImage: "plus.magnifyingglass") {
                viewModel.addZoom()
            }
            .keyboardShortcut("z", modifiers: [])
            .help("Add a zoom at the playhead (Z)")
            .disabled(!viewModel.canAddZoom)

            Button("Add Mask", systemImage: "eye.slash") {
                viewModel.addMask()
            }
            .keyboardShortcut("m", modifiers: [])
            .help("Hide part of the frame from the playhead (M)")
            .disabled(!viewModel.canAddMask)

            divider

            speedMenu
        }
    }

    /// The selected part's speed as a small pill naming the current rate.
    private var speedMenu: some View {
        Menu {
            Picker("Speed", selection: $viewModel.selectedSpeed) {
                ForEach(SpeedRange.rates, id: \.self) { rate in
                    Text(SpeedRange.label(for: rate)).tag(rate)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                if tier < 3 {
                    Text(viewModel.canChangeSpeed ? SpeedRange.label(for: viewModel.selectedSpeed) : "Speed")
                        .transition(.opacity)
                }
                Image(systemName: "chevron.down")
                    .font(.theme(.caption2))
            }
            .font(.theme(.caption, weight: .medium))
            .foregroundStyle(EditorTheme.dim)
            .padding(.horizontal, EditorTheme.smallSpacing)
            .frame(height: 30)
            .background(EditorTheme.control, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(EditorTheme.hairline)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(viewModel.canChangeSpeed ? "Speed of the selected part" : "Select a part to change its speed")
        .disabled(!viewModel.canChangeSpeed)
    }

    /// The playhead's time over the whole, then previous frame, play/pause, next frame. A narrow bar
    /// leaves the duration out.
    private var transport: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !viewModel.playback.isPlaying)) { _ in
                HStack(spacing: EditorTheme.tightSpacing) {
                    Text(Self.format(viewModel.playback.currentTime))
                        .foregroundStyle(EditorTheme.ink)
                    if tier < 2 {
                        Text("/ \(Self.format(viewModel.timeMap.outputDuration))")
                            .foregroundStyle(EditorTheme.dim)
                            .transition(.opacity)
                    }
                }
                .font(.theme(.callout).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
            }
            .padding(.trailing, EditorTheme.tightSpacing)

            Button("Previous Frame", systemImage: "backward.frame.fill") {
                viewModel.playback.step(by: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button(viewModel.playback.isPlaying ? "Pause" : "Play", systemImage: viewModel.playback.isPlaying ? "pause.fill" : "play.fill") {
                viewModel.playback.togglePlay()
            }
            .keyboardShortcut(.space, modifiers: [])
            .contentTransition(.symbolEffect(.replace))

            Button("Next Frame", systemImage: "forward.frame.fill") {
                viewModel.playback.step(by: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    /// Copy Frame and the timeline's own zoom.
    private var trail: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Button(copiedFrame ? "Copied" : "Copy Frame", systemImage: copiedFrame ? "checkmark" : "photo.on.rectangle") {
                Task {
                    guard await viewModel.copyFrame() else { return }
                    copiedFrame = true
                    try? await Task.sleep(for: .seconds(1.5))
                    copiedFrame = false
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .contentTransition(.symbolEffect(.replace))
            .help("Copy the frame at the playhead as an image (⇧⌘C)")

            divider

            Button("Zoom Timeline Out", systemImage: "minus.magnifyingglass") {
                viewModel.zoomTimeline(by: 1 / 1.5)
            }
            .keyboardShortcut("-", modifiers: .command)
            .help("Zoom the timeline out (⌘-)")
            .disabled(viewModel.viewport.showsAll)

            // The slider goes first when the bar is narrow; the buttons and ⌘-/⌘= still zoom
            if tier == 0 {
                EditorSlider(value: zoomLevel, range: 0...log2(TimelineViewport.maximumZoom))
                    .frame(width: 76)
                    .transition(.opacity)
            }

            Button("Zoom Timeline In", systemImage: "plus.magnifyingglass") {
                viewModel.zoomTimeline(by: 1.5)
            }
            .keyboardShortcut("=", modifiers: .command)
            .help("Zoom the timeline in (⌘=)")
            .disabled(viewModel.viewport.zoom >= TimelineViewport.maximumZoom)

            Button("Show Whole Recording", systemImage: "arrow.left.and.right") {
                viewModel.showWholeRecording()
            }
            .help("Show the whole recording")
            .disabled(viewModel.viewport.showsAll)
        }
    }

    /// The playhead's knob in the ruler, following playback.
    private var knob: some View {
        TimelineView(.animation(paused: !viewModel.playback.isPlaying)) { _ in
            let position = viewModel.viewport.x(at: viewModel.playheadSourceTime, width: rulerWidth)
            PlayheadKnob()
                .offset(x: position - Playhead.knobWidth / 2, y: 6)
                .opacity(position >= -Playhead.knobWidth && position <= rulerWidth + Playhead.knobWidth ? 1 : 0)
        }
    }

    /// The slider's level: zoom is multiplicative, so the slider moves in octaves.
    private var zoomLevel: Binding<Double> {
        Binding(
            get: { log2(max(viewModel.viewport.zoom, 1)) },
            set: { viewModel.setTimelineZoom(pow(2, $0)) }
        )
    }

    private var divider: some View {
        EditorTheme.ink.opacity(0.1)
            .frame(width: 1, height: 16)
    }

    /// What ⌫ deletes when it isn't a part of the recording.
    private var deletedName: String? {
        switch viewModel.selection {
        case .zoom: "Zoom"
        case .mask: "Mask"
        case .segment, nil: nil
        }
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
