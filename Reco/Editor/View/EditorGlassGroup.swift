//
//  EditorGlassGroup.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Glass shapes drawn together, so macOS 26 renders them in one pass and blends those that touch.
struct EditorGlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }
}
