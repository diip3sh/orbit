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

    private static var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.largeRadius) }

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            LibrarySidebar(viewModel: viewModel)
                .frame(width: 232)

            VStack(spacing: 0) {
                LibraryHeader(viewModel: viewModel)
                LibraryGrid(viewModel: viewModel)
            }
            .background(LibraryGrid.background, in: Self.shape)
            .clipShape(Self.shape)
            .overlay(Self.shape.strokeBorder(EditorTheme.ink.opacity(0.05)))
        }
        .padding(EditorTheme.smallSpacing)
        .ignoresSafeArea()
        .frame(minWidth: 760, minHeight: 480)
        .editorWindowBackground()
        .background(SettingsWindowConfigurator())
    }
}

/// The section's items, or why there are none.
struct LibraryGrid: View {
    let viewModel: LibraryViewModel

    /// The grid's content, which the date headers measure themselves in, for the rail's active date, and the tiles,
    /// for the open picture's push. Nonisolated: `onGeometryChange` reads it in a `Sendable` closure.
    nonisolated static let gridSpace = "libraryGrid"

    /// The content panel's colour, a step up from the window's ground.
    static let background = EditorTheme.panel

    /// Each date header's distance below the top of the grid's content, by ``LibraryDateGroup/id``. Only the
    /// headers a lazy grid has built have one, and one below the fold is treated as not reached yet. In the
    /// content, not the scroll view, so it changes with the layout and not on every frame of a scroll: a
    /// state write per frame ran this body (filtering, sorting and grouping every item) as often, 10–13 s of
    /// CPU over 15 s of scrolling 266 items (M2, Release, 2026-10-09).
    @State private var headerTops: [String: CGFloat] = [:]

    /// The date the rail marks, written only when another one reaches the top.
    @State private var activeDate: String?

    /// The picture open over the grid, until it is back in its tile.
    @State private var scatter: LibraryScatter?

    var body: some View {
        let shown = viewModel.shown
        let groups = viewModel.shownGroups
        // Down the right edge while there are dates to go between
        let showsRail = viewModel.sort.groupsByDate && groups.count > 1
        // The dates leave with the tiles, so the open picture is alone
        let isScattered = scatter?.isOpen == true
        let fade = isScattered ? LibraryPicturePreview.fadeOut : LibraryPicturePreview.fadeIn

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
                                            .opacity(isScattered ? 0 : 1)
                                            .animation(fade, value: isScattered)
                                        LibraryMasonry(items: group.items, viewModel: viewModel, scatter: scatter, openPicture: open)
                                    }
                                }
                            } else {
                                LibraryMasonry(items: shown, viewModel: viewModel, scatter: scatter, openPicture: open)
                            }
                        }
                        .coordinateSpace(name: Self.gridSpace)
                        .padding(.horizontal, EditorTheme.largeSpacing)
                        .padding(.top, EditorTheme.smallSpacing)
                        .padding(.bottom, EditorTheme.largeSpacing)
                        // The rail floats over the grid, so the last column keeps clear of it
                        .padding(.trailing, showsRail ? LibraryDateRail.width : 0)
                    }
                    // The open picture leaves from its tile and lands back in it, so the grid holds still meanwhile
                    .scrollDisabled(scatter != nil)
                    // A header is at the grid's top padding, where it counts as read, once the content has scrolled by its
                    // top: the content starts that padding down
                    .onScrollGeometryChange(for: String?.self) { geometry in
                        LibraryDateGroup.active(in: groups, headerTops: headerTops, topLine: geometry.contentOffset.y)
                    } action: { _, date in
                        activeDate = date
                    }
                    .hidingTopScrollEdgeEffect()
                    .overlay(alignment: .trailing) {
                        if showsRail {
                            LibraryDateRail(groups: groups, active: activeDate ?? groups.first?.id) { date in
                                withMotion {
                                    proxy.scrollTo(date, anchor: .top)
                                }
                            }
                            .opacity(isScattered ? 0 : 1)
                            .animation(fade, value: isScattered)
                        }
                    }
                    .overlayPreferenceValue(LibraryOpenedTile.self) { tile in
                        if let scatter {
                            LibraryPicturePreview(scatter: scatter, tile: tile, viewModel: viewModel) { offset in
                                // Along the grid as it reads: by date, a date's tiles in their order
                                LibraryScatter.picture(offset, from: scatter.item, in: viewModel.sort.groupsByDate ? groups.flatMap(\.items) : shown)
                            } show: { item in
                                self.scatter?.item = item
                                // At once, behind the picture: its tile is where it closes into
                                proxy.scrollTo(item.id)
                            } close: {
                                self.scatter?.isOpen = false
                            } didClose: {
                                self.scatter = nil
                            }
                            // ponytail: opening another picture while one is on its way back drops that one into its tile at once
                            .id(scatter.id)
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A picture whose item left the grid (another section, a search, deleted) has no tile to go back to
        .onChange(of: scatter.map { shown.contains($0.item) } ?? false) { _, isShown in
            if !isShown {
                withAnimation(EditorTheme.fadeMotion) {
                    scatter = nil
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.items != nil, let error = viewModel.error {
                StatusBanner(message: error) { viewModel.error = nil }
                    .padding(EditorTheme.spacing)
            }
        }
    }

    /// Opens `item` over the grid from its tile at `centre`, turns back the one on its way home, or, for the picture
    /// the arrows moved to, pushes the others from its tile.
    private func open(_ item: LibraryItem, at centre: CGPoint) {
        if scatter?.item == item {
            scatter?.isOpen = true
            scatter?.origin = centre
        } else {
            scatter = LibraryScatter(item: item, origin: centre)
        }
    }
}

/// One date's items (or all of them, in name order) as a masonry grid. Pictures load as their tiles scroll
/// into view: the masonry isn't lazy, so a month's tiles are all built at once.
private struct LibraryMasonry: View {
    let items: [LibraryItem]
    let viewModel: LibraryViewModel
    let scatter: LibraryScatter?
    let openPicture: (LibraryItem, CGPoint) -> Void

    var body: some View {
        // Columns at least this wide, filling the row; tiles sit closer than date to date
        MasonryLayout(minimumColumnWidth: 200, spacing: EditorTheme.smallSpacing) {
            ForEach(items) { item in
                LibraryTile(item: item, aspectRatio: viewModel.aspectRatios[item], viewModel: viewModel, scatter: scatter) { centre in
                    openPicture(item, centre)
                }
            }
        }
    }
}

private extension View {

    /// Without the edge macOS 26 draws where the scrolling grid meets the title bar: the header is its own bar.
    @ViewBuilder
    func hidingTopScrollEdgeEffect() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
