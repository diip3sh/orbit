//
//  LibraryView.swift
//  Reco
//

import QuickLook
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
            .scrollContentBackground(.hidden)
            .translucentColumn()
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            LibraryGrid(viewModel: viewModel)
                // Solid, so it reads apart from the sidebar's blurred desktop
                .background(LibraryGrid.background)
        }
        .searchable(text: $viewModel.search, placement: .toolbar, prompt: "Search by name")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LibraryFilterMenu(orientation: $viewModel.orientation, sort: $viewModel.sort)
            }
            ToolbarItem(placement: .primaryAction) {
                LibraryNewMenu(actions: viewModel.actions)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}

/// The section's items, or why there are none.
private struct LibraryGrid: View {
    @Bindable var viewModel: LibraryViewModel

    /// The grid's content, which the date headers measure themselves in, for the rail's active date. Nonisolated:
    /// `onGeometryChange` reads it in a `Sendable` closure.
    nonisolated static let gridSpace = "libraryGrid"

    /// The content area's colour: the window's ground.
    static let background = EditorTheme.stage

    /// Each date header's distance below the top of the grid's content, by ``LibraryDateGroup/id``. Only the
    /// headers a lazy grid has built have one, and one below the fold is treated as not reached yet. In the
    /// content, not the scroll view, so it changes with the layout and not on every frame of a scroll: a
    /// state write per frame ran this body (filtering, sorting and grouping every item) as often, 10–13 s of
    /// CPU over 15 s of scrolling 266 items (M2, Release, 2026-10-09).
    @State private var headerTops: [String: CGFloat] = [:]

    /// The date the rail marks, written only when another one reaches the top.
    @State private var activeDate: String?

    var body: some View {
        let shown = viewModel.shown
        let groups = viewModel.shownGroups
        // Down the right edge while there are dates to go between
        let showsRail = viewModel.sort.groupsByDate && groups.count > 1

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
                if !viewModel.search.isEmpty {
                    ContentUnavailableView.search(text: viewModel.search)
                } else if let orientation = viewModel.orientation {
                    ContentUnavailableView(
                        "No \(orientation.title) Items",
                        systemImage: orientation.symbol,
                        description: Text("Choose Any Shape in Filter to see everything in \(viewModel.section.title).")
                    )
                } else {
                    ContentUnavailableView(viewModel.section.title, systemImage: viewModel.section.symbol, description: Text(viewModel.section.emptyMessage))
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: EditorTheme.largeSpacing) {
                            if viewModel.sort.groupsByDate {
                                ForEach(groups) { group in
                                    VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                                        Text(group.title)
                                            .font(.theme(.headline))
                                            .foregroundStyle(EditorTheme.ink)
                                            // Where the rail scrolls to, and what it measures
                                            .id(group.id)
                                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.gridSpace)).minY } action: { top in
                                                headerTops[group.id] = top
                                            }
                                        LibraryMasonry(items: group.items, viewModel: viewModel)
                                    }
                                }
                            } else {
                                LibraryMasonry(items: shown, viewModel: viewModel)
                            }
                        }
                        .coordinateSpace(name: Self.gridSpace)
                        .padding(EditorTheme.largeSpacing)
                        // The rail floats over the grid, so the last column keeps clear of it
                        .padding(.trailing, showsRail ? LibraryDateRail.width : 0)
                    }
                    // A header is at the grid's top padding, where it counts as read, once the content has scrolled by its
                    // top: the content starts that padding down
                    .onScrollGeometryChange(for: String?.self) { geometry in
                        LibraryDateGroup.active(in: groups, headerTops: headerTops, topLine: geometry.contentOffset.y)
                    } action: { _, date in
                        activeDate = date
                    }
                    .softTopEdge()
                    .overlay(alignment: .trailing) {
                        if showsRail {
                            LibraryDateRail(groups: groups, active: activeDate ?? groups.first?.id) { date in
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
        // The pictures shown, in the grid's order, so the arrow keys go from one to the next
        .quickLookPreview($viewModel.previewed, in: shown.filter { !$0.isMovie }.map(\.url))
        .navigationTitle(viewModel.section.heading)
        .navigationSubtitle(Text("^[\(shown.count) item](inflect: true)"))
    }
}

/// One date's items (or all of them, in name order) as a masonry grid. Pictures load as their tiles scroll
/// into view: the masonry isn't lazy, so a month's tiles are all built at once.
private struct LibraryMasonry: View {
    let items: [LibraryItem]
    let viewModel: LibraryViewModel

    var body: some View {
        // Columns at least this wide, filling the row; tiles sit closer than date to date
        MasonryLayout(minimumColumnWidth: 200, spacing: EditorTheme.smallSpacing) {
            ForEach(items) { item in
                LibraryTile(item: item, aspectRatio: viewModel.aspectRatios[item], viewModel: viewModel)
            }
        }
    }
}

/// Filter: the pictures' shape, and the grid's order.
private struct LibraryFilterMenu: View {
    @Binding var orientation: LibraryOrientation?
    @Binding var sort: LibrarySort

    var body: some View {
        Menu {
            Picker("Shape", selection: $orientation) {
                Text("Any Shape").tag(LibraryOrientation?.none)
                ForEach(LibraryOrientation.allCases, id: \.self) { orientation in
                    Label(orientation.title, systemImage: orientation.symbol).tag(Optional(orientation))
                }
            }
            .pickerStyle(.inline)
            Picker("Sort By", selection: $sort) {
                ForEach(LibrarySort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
        } label: {
            // Filled while a shape narrows the grid, so a short grid says why
            Label("Filter", systemImage: orientation == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
        }
        .menuIndicator(.hidden)
        .help("Show one shape, and choose the order")
    }
}

private extension View {

    /// The grid fades out under the toolbar's glass as it scrolls up, as Finder's does.
    @ViewBuilder
    func softTopEdge() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
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
        .menuIndicator(.hidden)
        .help("Take a screenshot or start a recording")
    }
}
