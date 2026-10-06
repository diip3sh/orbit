//
//  MotionLintSection.swift
//  Reco
//

import SwiftUI

/// What the grammar's rules find in the document, scene by scene.
struct MotionLintSection: View {
    let findings: [MotionLint.Finding]

    var body: some View {
        InspectorSection("Rules") {
            if findings.isEmpty {
                Label("Nothing breaks the grammar's rules.", systemImage: "checkmark.circle")
                    .foregroundStyle(EditorTheme.dim)
            }
            ForEach(findings.indices, id: \.self) { index in
                let finding = findings[index]
                VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                    Text("\(finding.scene) · \(finding.rule.rawValue)")
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(EditorTheme.dim)
                    Text(finding.message)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
