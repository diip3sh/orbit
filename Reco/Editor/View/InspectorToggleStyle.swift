//
//  InspectorToggleStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The title on the left and a small switch on the right edge.
struct InspectorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle(configuration)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

extension ToggleStyle where Self == InspectorToggleStyle {
    static var inspector: Self { InspectorToggleStyle() }
}
