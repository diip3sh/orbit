//
//  MotionLayerSection.swift
//  Reco
//

import SwiftUI

/// A layer of the selected scene and its moves: when each starts, how long it takes and how far it
/// goes, with the grammar's defaults shown until they're changed.
struct MotionLayerSection: View {
    let viewModel: MotionEditorViewModel

    var body: some View {
        InspectorSection("Layer") {
            let layers = viewModel.laidOutScene?.layers ?? []
            Picker("Layer", selection: Binding { viewModel.selectedLayer } set: { viewModel.selectedLayer = $0 }) {
                Text("None").tag(String?.none)
                ForEach(layers) { layer in
                    Text(layer.name).tag(Optional(layer.id))
                }
            }
            if let layer = viewModel.layer {
                ForEach(layer.moves.indices, id: \.self) { index in
                    MotionMoveRow(viewModel: viewModel, layer: layer, index: index)
                }
                Menu("Add Move", systemImage: "plus") {
                    ForEach(MotionMove.Kind.allCases.filter { MotionMove($0).problem(on: layer.content) == nil }, id: \.self) { kind in
                        Button(kind.rawValue) {
                            var changed = layer
                            changed.moves.append(MotionMove(kind))
                            viewModel.layer = changed
                        }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.editorGhost)
            }
        }
    }
}

/// One move: its start, duration and intensity, and a button that removes it.
private struct MotionMoveRow: View {
    let viewModel: MotionEditorViewModel
    let layer: MotionLayer
    let index: Int

    var body: some View {
        let move = layer.moves[index]
        let timing = viewModel.timing(of: move, on: layer)
        let length = viewModel.scene?.duration ?? 1

        VStack(spacing: EditorTheme.smallSpacing) {
            HStack {
                Text(move.kind.rawValue)
                    .bold()
                Spacer()
                Button("Remove", systemImage: "minus.circle") {
                    var changed = layer
                    changed.moves.remove(at: index)
                    viewModel.layer = changed
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.editorIcon)
            }
            InspectorSlider("Start", value: value(\.start, default: timing.start), in: 0...length) {
                Text("\($0, format: .number.precision(.fractionLength(2))) s")
            }
            InspectorSlider("Duration", value: value(\.duration, default: timing.duration), in: 0.05...max(length, 0.05)) {
                Text("\($0, format: .number.precision(.fractionLength(2))) s")
            }
            InspectorSlider("Intensity", value: value(\.intensity, default: 1), in: 0.1...3) {
                Text("\($0, format: .number.precision(.fractionLength(0...2)))×")
            }
        }
        .padding(.vertical, EditorTheme.tightSpacing)
    }

    /// A move's field, showing the grammar's default until it's set.
    private func value(_ keyPath: WritableKeyPath<MotionMove, Double?>, default fallback: Double) -> Binding<Double> {
        Binding {
            layer.moves[index][keyPath: keyPath] ?? fallback
        } set: { value in
            var changed = layer
            changed.moves[index][keyPath: keyPath] = value
            viewModel.layer = changed
        }
    }
}
