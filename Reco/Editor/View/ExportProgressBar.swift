//
//  ExportProgressBar.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A thin bar filling up, under the percentage done.
struct ExportProgressBar: View {

    /// From 0 to 1.
    let progress: Double

    var title: LocalizedStringKey = "Exporting…"

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
            HStack {
                Text(title)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .monospaced()
                    .contentTransition(.numericText(value: progress))
                    .foregroundStyle(EditorTheme.dim)
            }
            .font(.callout)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .labelsHidden()
        }
        .editorMotion(.smooth(duration: 0.3), value: progress)
    }
}
