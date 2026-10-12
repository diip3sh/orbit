//
//  MotionSceneSection.swift
//  Reco
//

import SwiftUI

/// The selected scene: its shot and the shot's text, how long it lasts, how it begins and what it's
/// drawn over.
struct MotionSceneSection: View {
    let viewModel: MotionEditorViewModel

    var body: some View {
        InspectorSection("Scene") {
            if let scene = viewModel.scene {
                Picker("Shot", selection: shotKind) {
                    Text("None").tag(MotionShot.Kind?.none)
                    ForEach(MotionShot.Kind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(Optional(kind))
                    }
                }
                if scene.shot?.kind.showsText == true {
                    InspectorField("Text") {
                        TextField("Text", text: text(\.text), axis: .vertical)
                            .labelsHidden()
                    }
                }
                if scene.shot?.kind.showsDetail == true {
                    InspectorField("Detail") {
                        TextField("Detail", text: text(\.detail), axis: .vertical)
                            .labelsHidden()
                    }
                }
                InspectorSlider("Duration", value: binding(\.duration), in: 0.5...10) {
                    Text("\($0, format: .number.precision(.fractionLength(1))) s")
                }
                Picker("Seam", selection: binding(\.seam)) {
                    ForEach(MotionSeam.allCases, id: \.self) { seam in
                        Text(seam.rawValue).tag(seam)
                    }
                }
                Picker("Field", selection: binding(\.field)) {
                    Text("Same as video").tag(MotionField?.none)
                    ForEach(MotionField.allCases, id: \.self) { field in
                        Text(field.rawValue).tag(Optional(field))
                    }
                }
            } else {
                Label("Select a scene on the timeline.", systemImage: "cursorarrow.click")
                    .foregroundStyle(EditorTheme.dim)
            }
        }
    }

    /// The scene's shot; picking another keeps the slots already filled.
    private var shotKind: Binding<MotionShot.Kind?> {
        Binding {
            viewModel.scene?.shot?.kind
        } set: { kind in
            guard var scene = viewModel.scene else { return }
            scene.shot = kind.map { kind in
                var shot = scene.shot ?? MotionShot(kind)
                shot.kind = kind
                // What the shot needs and doesn't have yet, so picking it shows something
                let assets = viewModel.document?.assets.map(\.id) ?? []
                shot.text = shot.text ?? "Headline"
                shot.asset = shot.asset ?? assets.first
                if shot.items == nil, kind == .uiCascade || kind == .featureSequence {
                    shot.items = assets.map { ShotItem(text: kind == .featureSequence ? "Feature" : nil, asset: $0) }
                }
                return shot
            }
            viewModel.scene = scene
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MotionScene, Value>) -> Binding<Value> {
        Binding {
            viewModel.scene.map { $0[keyPath: keyPath] } ?? MotionScene(id: "", duration: 1)[keyPath: keyPath]
        } set: { value in
            guard var scene = viewModel.scene else { return }
            scene[keyPath: keyPath] = value
            viewModel.scene = scene
        }
    }

    /// A slot of the shot's; empty is none.
    private func text(_ keyPath: WritableKeyPath<MotionShot, String?>) -> Binding<String> {
        Binding {
            viewModel.scene?.shot?[keyPath: keyPath] ?? ""
        } set: { text in
            guard var scene = viewModel.scene else { return }
            scene.shot?[keyPath: keyPath] = text.isEmpty ? nil : text
            viewModel.scene = scene
        }
    }
}
