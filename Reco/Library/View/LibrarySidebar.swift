//
//  LibrarySidebar.swift
//  Reco
//

import SwiftUI

/// The Library's sections with their counts, on a translucent column with the traffic lights at its top.
struct LibrarySidebar: View {
    @Bindable var viewModel: LibraryViewModel

    private static var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.largeRadius) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The traffic lights' row: `SettingsWindowConfigurator` moves them here
            Color.clear
                .frame(height: SettingsWindowConfigurator.titlebarHeight)

            ForEach(LibrarySection.allCases, id: \.self) { section in
                Button {
                    viewModel.section = section
                } label: {
                    HStack(spacing: 10) {
                        Label(section.title, systemImage: section.symbol)
                        Spacer(minLength: 0)
                        Text(viewModel.count(in: section), format: .number)
                            .font(.theme(.callout, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(EditorTheme.dim)
                    }
                }
                .buttonStyle(SettingsSidebarRowStyle(isSelected: viewModel.section == section))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, EditorTheme.spacing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(EditorTheme.panel.opacity(0.3), in: Self.shape)
        .overlay(Self.shape.strokeBorder(EditorTheme.ink.opacity(0.1)))
    }
}
