//
//  SettingsLabeledContentStyle.swift
//  Reco
//

import SwiftUI

/// A labelled value or control as a Settings row.
struct SettingsLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        SettingsRow {
            configuration.label
        } trailing: {
            configuration.content
        }
    }
}

extension LabeledContentStyle where Self == SettingsLabeledContentStyle {
    static var settings: Self { SettingsLabeledContentStyle() }
}
