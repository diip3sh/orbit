//
//  ClickEffectPicture.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import SwiftUI

/// A click effect's tile picture: nothing, a ring over a faint fill, or two rings.
struct ClickEffectPicture: View {
    let effect: ClickHighlightStyle.Effect

    var body: some View {
        switch effect {
        case .off:
            Image(systemName: "circle.slash")
        case .circle:
            Circle()
                .fill(.primary.opacity(0.2))
                .overlay(Circle().strokeBorder(.primary, lineWidth: 1.5))
                .frame(width: 16, height: 16)
        case .ripple:
            Circle()
                .strokeBorder(.primary.opacity(0.5), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.primary, lineWidth: 1.5).frame(width: 10, height: 10))
        }
    }
}
