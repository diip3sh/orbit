//
//  LibraryTile.swift
//  Reco
//

import SwiftUI

/// One item in the Library's grid: its picture at its own shape, a play mark on a movie, and its name while
/// pointed at. Clicking opens a movie in the editor and a picture in Quick Look; the context menu and the •••
/// button on hover open, reveal, copy or trash it.
struct LibraryTile: View {
    let item: LibraryItem

    /// Width over height, `nil` until read (or unreadable), when the tile is a recording's usual 16:10.
    let aspectRatio: Double?
    let viewModel: LibraryViewModel

    /// Loaded the first time the tile scrolls into view.
    @State private var thumbnail: CGImage?
    @State private var isHovered = false

    init(item: LibraryItem, aspectRatio: Double?, viewModel: LibraryViewModel) {
        self.item = item
        self.aspectRatio = aspectRatio
        self.viewModel = viewModel
        _thumbnail = State(initialValue: viewModel.loadedThumbnail(for: item))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: EditorTheme.radius, style: .continuous)

        Button {
            viewModel.preview(item)
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
            viewModel.copy(item)
        }
        Divider()
        Button("Move to Trash", systemImage: "trash", role: .destructive) {
            Task { await viewModel.trash(item) }
        }
    }
}
