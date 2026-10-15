//
//  LibraryTile.swift
//  Reco
//

import SwiftUI

/// One item in the Library's grid: its picture at its own shape, a play mark on a movie, and its name while
/// pointed at. Clicking opens a movie in the editor and a picture over the grid; the context menu and the •••
/// button on hover open, reveal, copy or trash it.
struct LibraryTile: View {
    let item: LibraryItem

    /// Width over height, `nil` until read (or unreadable), when the tile is a recording's usual 16:10.
    let aspectRatio: Double?
    let viewModel: LibraryViewModel

    /// The picture open over the grid, if any, which pushes this tile away or stands in for it.
    let scatter: LibraryScatter?

    /// Opens this picture over the grid, from the tile's centre.
    let openPicture: (CGPoint) -> Void

    /// Loaded the first time the tile scrolls into view.
    @State private var thumbnail: CGImage?
    @State private var isHovered = false

    /// The tile's centre in the grid's content, which only a new layout changes.
    @State private var centre = CGPoint.zero

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    init(item: LibraryItem, aspectRatio: Double?, viewModel: LibraryViewModel, scatter: LibraryScatter?, openPicture: @escaping (CGPoint) -> Void) {
        self.item = item
        self.aspectRatio = aspectRatio
        self.viewModel = viewModel
        self.scatter = scatter
        self.openPicture = openPicture
        _thumbnail = State(initialValue: viewModel.loadedThumbnail(for: item))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: EditorTheme.radius, style: .continuous)
        let isOpened = scatter?.item == item
        // The opened tile too, so it stays hidden when the arrows move the picture on
        let isScattered = scatter?.isOpen == true

        Button {
            if item.isMovie {
                viewModel.open(item)
            } else {
                openPicture(centre)
            }
        } label: {
            EditorTheme.control
                .aspectRatio(aspectRatio ?? 16 / 10, contentMode: .fit)
                .overlay {
                    if let thumbnail {
                        // Fills the tile: a picture of the same shape fits it exactly, a first frame of another
                        // shape (before the shape was read) is cropped rather than letterboxed
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: EditorTheme.tightSpacing) {
                        if item.isMovie {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(EditorTheme.ink)
                                .frame(width: 24, height: 24)
                                .editorSurface(in: .circle, fill: EditorTheme.raised)
                                .accessibilityHidden(true)
                        }
                        if isHovered {
                            Text(item.name)
                                .font(.theme(.caption, weight: .medium))
                                .foregroundStyle(EditorTheme.ink)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, EditorTheme.smallSpacing)
                                .frame(height: 24)
                                .editorSurface(in: .capsule, fill: EditorTheme.raised)
                                .transition(.opacity)
                        }
                    }
                    .padding(EditorTheme.smallSpacing)
                }
                .clipShape(shape)
                // A hairline edge, so a picture as dark as the window still has one
                .overlay {
                    shape.strokeBorder(isHovered ? EditorTheme.faint : EditorTheme.hairline)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onScrollVisibilityChange(threshold: 0.01) { isVisible in
            guard isVisible, thumbnail == nil else { return }
            Task { thumbnail = await viewModel.thumbnail(for: item) }
        }
        // The same actions as the context menu, for those who don't right-click. Built only while pointed at:
        // a menu is an AppKit pop-up button, too much to keep under every tile
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Menu {
                    LibraryItemActions(item: item, viewModel: viewModel)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EditorTheme.ink)
                        .frame(width: 24, height: 24)
                        .editorSurface(in: .circle, fill: EditorTheme.raised)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(EditorTheme.smallSpacing)
                .transition(.opacity)
                .help("More")
                .accessibilityLabel("More")
            }
        }
        .contextMenu {
            LibraryItemActions(item: item, viewModel: viewModel)
        }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .editorMotion(.smooth, value: thumbnail != nil)
        .help(item.url.lastPathComponent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityValue(Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute()))
        .accessibilityAddTraits(.isButton)
        .anchorPreference(key: LibraryOpenedTile.self, value: .bounds) { isOpened ? $0 : nil }
        .offset(reducesMotion ? .zero : scatter?.offset(ofTileAt: centre) ?? .zero)
        // The innermost animation wins, so the offset springs while the opacity below fades
        .animation(scatter?.isOpen == true ? LibraryPicturePreview.scatterMotion : LibraryPicturePreview.motion, value: scatter)
        .opacity(isScattered ? 0 : 1)
        .animation(isScattered ? LibraryPicturePreview.fadeOut : LibraryPicturePreview.fadeIn, value: isScattered)
        // At once, outside both: the picture over the grid stands in for the tile from its first frame to its last
        .opacity(isOpened ? 0 : 1)
        // Outside the offset, so the push doesn't move the point it's pushed from
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .named(LibraryGrid.gridSpace))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { centre in
            self.centre = centre
        }
        // Opened by the arrows, or moved by a deletion while open: the others are pushed from here now
        .onChange(of: isOpened ? centre : nil) { _, centre in
            if let centre, scatter?.isOpen == true, centre != scatter?.origin {
                openPicture(centre)
            }
        }
    }
}

/// What can be done with an item, shared by the tile's context menu and its ••• menu.
private struct LibraryItemActions: View {
    let item: LibraryItem
    let viewModel: LibraryViewModel

    var body: some View {
        Button(item.isMovie ? "Open in Editor" : "Open", systemImage: "arrow.up.forward.app") {
            viewModel.open(item)
        }
        Button("Show in Finder", systemImage: "folder") {
            viewModel.reveal(item)
        }
        Button("Copy", systemImage: "doc.on.doc") {
            Task { await viewModel.copy(item) }
        }
        Divider()
        Button("Move to Trash", systemImage: "trash", role: .destructive) {
            Task { await viewModel.trash(item) }
        }
    }
}
