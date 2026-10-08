//
//  MotionSoundSection.swift
//  Reco
//

import SwiftUI

/// The video's sound (spec 0013): the score and the effects, each on or off and raised or lowered from
/// where the rules put it.
struct MotionSoundSection: View {
    let viewModel: MotionEditorViewModel

    var body: some View {
        InspectorSection("Sound") {
            Toggle("Score", isOn: binding(\.score))
            InspectorSlider("Score Level", value: binding(\.scoreLevel), in: MotionSound.levels, label: decibels)
                .disabled(!sound.score)
            Toggle("Effects", isOn: binding(\.effects))
            InspectorSlider("Effects Level", value: binding(\.effectsLevel), in: MotionSound.levels, label: decibels)
                .disabled(!sound.effects)
        }
        .toggleStyle(.inspector)
    }

    private var sound: MotionSound {
        viewModel.document?.sound ?? MotionSound()
    }

    private func decibels(_ value: Double) -> Text {
        Text("\(value, format: .number.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false))) dB")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MotionSound, Value>) -> Binding<Value> {
        Binding {
            sound[keyPath: keyPath]
        } set: { value in
            viewModel.edit("Sound", coalescing: true) { $0.sound[keyPath: keyPath] = value }
        }
    }
}
