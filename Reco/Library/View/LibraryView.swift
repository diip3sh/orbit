//
//  LibraryView.swift
//  Reco
//

import SwiftUI

/// Reco's main window (spec 0010): a sidebar of sections, everything Reco made as a grid of pictures,
/// search, and New for a screenshot, a recording, a web recording or an agent's recording. It stays
/// open, unlike the menu bar's popover.
struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel

    var body: some View {
        NavigationSplitView {
            List(LibrarySection.allCases, id: \.self, selection: Binding($viewModel.section)) { section in
                Label(section.title, systemImage: section.symbol)
                    .badge(viewModel.count(in: section))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            LibraryGrid(viewModel: viewModel)
        }
        .searchable(text: $viewModel.search, placement: .toolbar, prompt: "Search by name")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LibraryNewMenu(actions: viewModel.actions)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}

/// The section's items, or why there are none.
private struct LibraryGrid: View {
    let viewModel: LibraryViewModel

    var body: some View {
        let shown = viewModel.shown

        Group {
            if viewModel.items == nil, let error = viewModel.error {
                ContentUnavailableView {
                    Label("Can't Read Your Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    // Where the folders are chosen
                    SettingsLink {
                        Text("Choose Folders in Settings…")
                    }
                    .buttonStyle(.editorGhost)
                }
            } else if viewModel.items == nil {
                ProgressView()
                    .controlSize(.small)
            } else if shown.isEmpty {
                if viewModel.search.isEmpty {
                    ContentUnavailableView(viewModel.section.title, systemImage: viewModel.section.symbol, description: Text(viewModel.section.emptyMessage))
                } else {
                    ContentUnavailableView.search(text: viewModel.search)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: EditorTheme.largeSpacing)], spacing: EditorTheme.largeSpacing) {
                        ForEach(shown) { item in
                            LibraryTile(item: item, thumbnail: viewModel.thumbnails[item.url], viewModel: viewModel)
                                .task {
                                    await viewModel.loadThumbnail(for: item)
                                }
                        }
                    }
                    .padding(EditorTheme.largeSpacing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if viewModel.items != nil, let error = viewModel.error {
                StatusBanner(message: error) { viewModel.error = nil }
                    .padding(EditorTheme.spacing)
            }
        }
        .navigationTitle(viewModel.section.title)
    }
}

/// New: a screenshot, a screen recording, a web recording or an agent's recording.
private struct LibraryNewMenu: View {
    let actions: LibraryViewModel.Actions

    var body: some View {
        Menu {
            Section("Screenshot") {
                Button("Capture Area", systemImage: "rectangle.dashed", action: actions.captureArea)
                Button("Capture Window", systemImage: "macwindow", action: actions.captureWindow)
                Button("Capture Screen", systemImage: "display", action: actions.captureScreen)
            }
            Section("Recording") {
                Button("Record Area…", systemImage: "rectangle.dashed.badge.record", action: actions.recordArea)
                Button("Record Window or Display…", systemImage: "macwindow", action: actions.recordWindowOrDisplay)
            }
            Section("Web") {
                Button("New Web Recording…", systemImage: "globe", action: actions.newWebRecording)
                Button("Record with AI Agent…", systemImage: "sparkles", action: actions.recordWithAgent)
            }
        } label: {
            Label("New", systemImage: "plus")
        }
        .help("Take a screenshot or start a recording")
    }
}
