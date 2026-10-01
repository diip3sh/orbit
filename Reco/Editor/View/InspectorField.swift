//
//  InspectorField.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A control under its title, for controls too wide to sit beside it.
struct InspectorField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            Text(title)
            content
        }
    }
}
