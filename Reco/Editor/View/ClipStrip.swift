//
//  ClipStrip.swift
//  Reco
//

import SwiftUI

/// The clips in playing order, above the timeline, which stays in source order since every lane is timed on the source
/// (spec 0023, section 5). Clicking a clip selects it and dragging one moves it. Shown once there's more than one.
struct ClipStrip: View {
    let viewModel: EditorViewModel

    @Environment(\.displayScale) private var displayScale

    @State private var width: CGFloat = 0

    /// The clip being dragged and how far.
    @State private var drag: (index: Int, distance: CGFloat)?

    private static let height: CGFloat = 40
    private static let spacing: CGFloat = EditorTheme.tightSpacing

    /// A clip's largest width, so two clips don't fill the row.
    private static let maximumWidth: CGFloat = 120

    var body: some View {
        let clips = viewModel.clips
        if clips.count > 1 {
            HStack(spacing: 0) {
                Text("Clips")
                    .font(.theme(.caption))
                    .foregroundStyle(EditorTheme.dim)
                    .frame(width: EditorTimelineView.trackLabelWidth, alignment: .leading)
                row(clips)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
            .frame(height: Self.height)
            .transition(.opacity)
        }
    }

    private func row(_ clips: [Range<Double>]) -> some View {
        let slot = min((width + Self.spacing) / CGFloat(clips.count), Self.maximumWidth + Self.spacing)
        return HStack(spacing: Self.spacing) {
            ForEach(clips, id: \.lowerBound) { clip in
                let index = clips.firstIndex(of: clip) ?? 0
                ClipChip(
                    index: index,
                    duration: viewModel.timeMap.outputRanges(ofSource: clip).reduce(0) { $0 + $1.upperBound - $1.lowerBound },
                    picture: viewModel.thumbnail(at: (clip.lowerBound + clip.upperBound) / 2),
                    isSelected: viewModel.selection == .segment(clip),
                    displayScale: displayScale
                ) {
                    viewModel.selectClip(clip)
                }
                .frame(width: max(slot - Self.spacing, 1))
                .offset(x: offset(ofClip: index, slot: slot, count: clips.count))
                .zIndex(drag?.index == index ? 1 : 0)
                .simultaneousGesture(reorder(index, slot: slot, count: clips.count))
                .accessibilityAction(named: "Move Earlier") { viewModel.moveClip(index, to: index - 1) }
                .accessibilityAction(named: "Move Later") { viewModel.moveClip(index, to: index + 1) }
            }
        }
        .editorMotion(value: clips)
    }

    /// Follows the pointer when it's the one dragged, and makes room for it otherwise.
    private func offset(ofClip index: Int, slot: CGFloat, count: Int) -> CGFloat {
        guard let drag else { return 0 }
        guard drag.index != index else { return drag.distance }
        let target = EditorViewModel.clipTarget(from: drag.index, distance: drag.distance, slot: slot, count: count)
        if drag.index < index, index <= target {
            return -slot
        }
        return target <= index && index < drag.index ? slot : 0
    }

    private func reorder(_ index: Int, slot: CGFloat, count: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag = (index, $0.translation.width) }
            .onEnded { value in
                drag = nil
                viewModel.moveClip(index, to: EditorViewModel.clipTarget(from: index, distance: value.translation.width, slot: slot, count: count))
            }
    }
}

/// One clip: its picture, its place and how long it plays.
private struct ClipChip: View {
    let index: Int
    let duration: Double
    let picture: CGImage?
    let isSelected: Bool
    let displayScale: CGFloat
    let select: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: EditorTheme.smallRadius)

    var body: some View {
        Button(action: select) {
            ZStack(alignment: .bottomLeading) {
                VideoTrack.tint.opacity(0.35)
                if let picture {
                    Image(decorative: picture, scale: displayScale)
                        .resizable()
                        .scaledToFill()
                }
                Text(duration, format: .number.precision(.fractionLength(1)))
                    .font(.theme(.caption))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(.horizontal, EditorTheme.tightSpacing)
                    .lineLimit(1)
            }
            .clipShape(Self.shape)
            .contentShape(Self.shape)
            .overlay {
                Self.shape.strokeBorder(isSelected ? EditorTheme.accent : EditorTheme.ink.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .pointerStyle(.grabIdle)
        .help("Drag to play this clip earlier or later")
        .accessibilityLabel("Clip \(index + 1), \(duration.formatted(.number.precision(.fractionLength(1)))) seconds")
    }
}
