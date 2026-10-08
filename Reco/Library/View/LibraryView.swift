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
                // Solid, so it reads apart from the sidebar's glass: the window's own colour matched the sidebar's
                // within a few levels (55 against 57 in dark mode), so the two read as one surface
                .background(LibraryGrid.background)
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

    /// The coordinate space the date headers measure themselves in, for the rail's active date.
    static let gridSpace = "libraryGrid"

    /// The content area's colour: the window's ground.
    static let background = EditorTheme.stage

    /// Columns at least this wide, filling the row; tiles sit closer side by side than date to date.
    private static let columns = [GridItem(.adaptive(minimum: 200), spacing: EditorTheme.spacing, alignment: .top)]

    /// Each date header's distance below the top of the grid, by ``LibraryDateGroup/id``. Only the
    /// headers a lazy grid has built have one, and one below the fold is treated as not reached yet.
    @State private var headerTops: [String: CGFloat] = [:]

    var body: some View {
        let shown = viewModel.shown
        let groups = viewModel.shownGroups

        Group {
            if viewModel.items == nil, let error = viewModel.error {
                ContentUnavailableView {
                    Label("Can't Read Your Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    // Where the folders are chosen
                    SettingsLink {
                        Label("Choose Folders in Settings…", image: "button-settings")
                    }
                    .buttonStyle(.editorSecondary)
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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Self.columns, spacing: EditorTheme.largeSpacing) {
                            ForEach(groups) { group in
                                Section {
                                    ForEach(group.items) { item in
                                        LibraryTile(item: item, thumbnail: viewModel.thumbnails[item.url], viewModel: viewModel)
                                            .task {
                                                await viewModel.loadThumbnail(for: item)
                                            }
                                    }
                                } header: {
                                    Text(group.title)
                                        .font(.theme(.headline))
                                        .foregroundStyle(EditorTheme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        // Where the rail scrolls to, and what it measures
                                        .id(group.id)
                                        .background { headerTop(of: group) }
                                }
                            }
                        }
                        .padding(EditorTheme.largeSpacing)
                        // The rail floats over the grid, so the last column keeps clear of it
                        .padding(.trailing, groups.count > 1 ? LibraryDateRail.width : 0)
                    }
                    .coordinateSpace(name: Self.gridSpace)
                    .overlay(alignment: .trailing) {
                        if groups.count > 1 {
                            LibraryDateRail(groups: groups, active: activeDate) { date in
                                withMotion {
                                    proxy.scrollTo(date, anchor: .top)
                                }
                            }
                        }
                    }
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

    /// The date the grid is looking at: the last one whose header has passed the top, or the first one
    /// still below it, which is the first date before anything has scrolled.
    private var activeDate: String? {
        LibraryDateGroup.active(in: viewModel.shownGroups, headerTops: headerTops, topLine: Self.topLine)
    }

    /// Where a header counts as the one being read: the grid's own top padding, so the first date is
    /// marked as soon as the grid is at its top.
    private static let topLine = EditorTheme.largeSpacing

    /// Reports where a date's header sits, which moves as the grid scrolls. Only a few headers exist at
    /// a time, so this is a handful of updates per frame at most.
    private func headerTop(of group: LibraryDateGroup) -> some View {
        GeometryReader { proxy in
            let top = proxy.frame(in: .named(Self.gridSpace)).minY
            Color.clear
                .onChange(of: top, initial: true) { _, newTop in
                    headerTops[group.id] = newTop
                }
        }
    }
}

/// New: a screenshot, a screen recording or a web recording.
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
            }
        } label: {
            Label("New", systemImage: "plus")
        }
        .help("Take a screenshot or start a recording")
    }
}
