//
//  EditorHeader.swift
//  Reco
//

import SwiftUI

/// The top row of the editor's main panel, beside the traffic lights: the recording's name, then Style, Export…
/// (⌘E) and the inspector's toggle. In export, Back (Esc) in front of the name instead.
struct EditorHeader: View {
    let viewModel: EditorViewModel

    /// The export's visit, while it shows.
    let export: ExportSession?

    @Binding var isRenaming: Bool
    @Binding var showsInspector: Bool

    let openExport: () -> Void
    let closeExport: () -> Void

    /// The row's height, which the traffic lights are centred in.
    static let height: CGFloat = 60

    var body: some View {
        HStack(spacing: EditorTheme.mediumSpacing) {
            // The traffic lights' room: `SettingsWindowConfigurator` moves them here
            Color.clear
                .frame(width: 64, height: 1)

            if let export {
                Button(action: closeExport) {
                    Label("Editor", systemImage: "chevron.left")
                        .font(.theme(.body, weight: .medium))
                        .foregroundStyle(EditorTheme.ink)
                        .padding(.horizontal, 14)
                        .headerCapsule()
                }
                .buttonStyle(.plain)
                // Esc ends a rename first
                .keyboardShortcut(isRenaming ? nil : .cancelAction)
                .disabled(export.isExporting)
                .help("Back to the editor (Esc)")

                // Only to read as the back button's pair, as a browser's: from export there is nowhere forward
                Button("Export", systemImage: "chevron.right") {}
                    .labelStyle(.iconOnly)
                    .font(.theme(.body, weight: .medium))
                    .foregroundStyle(EditorTheme.ink)
                    .frame(width: 36)
                    .headerCapsule()
                    .buttonStyle(.plain)
                    .disabled(true)
            }

            RecordingNameField(name: RecordingRename.displayName(of: viewModel.videoURL), isRenaming: $isRenaming) { name in
                Task { await viewModel.rename(to: name) }
            }
            .disabled(export?.isExporting == true)

            Spacer(minLength: 0)

            if export == nil {
                StyleMenu(viewModel: viewModel)

                Button(action: openExport) {
                    HStack(spacing: EditorTheme.smallSpacing) {
                        Image("button-export")
                        Text("Export…")
                            .font(.theme(.body, weight: .semibold))
                        Text("⌘E")
                            .font(.theme(.subheadline, weight: .medium))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(EditorTheme.onAccent)
                    .padding(.horizontal, EditorTheme.spacing)
                    .headerProminentCapsule()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e")
                .help("Export the edited video")

                Button("Inspector", systemImage: "sidebar.trailing") {
                    showsInspector.toggle()
                }
                .buttonStyle(EditorIconButtonStyle(diameter: 32))
                .help(showsInspector ? "Hide the inspector" : "Show the inspector")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .frame(height: Self.height)
    }
}
