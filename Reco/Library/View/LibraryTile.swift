//
//  LibraryTile.swift
//  Reco
//

import SwiftUI

/// One item in the Library's grid: its picture, what kind it is, its name and when it was saved.
/// Clicking opens it; the context menu and the ••• button on hover reveal, copy or trash it.
struct LibraryTile: View {
    let item: LibraryItem
    let thumbnail: CGImage?
    let viewModel: LibraryViewModel

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)

        Button {
            viewModel.open(item)
        } label: {
            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                EditorTheme.softHairline
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            // A screenshot keeps its shape; a movie fills the frame
                            Image(decorative: thumbnail, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: item.isMovie ? .fill : .fit)
                                .transition(.opacity)
                        }
                    }
                    .clipShape(shape)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: item.kind.symbol)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.55), in: .circle)
                            .padding(EditorTheme.smallSpacing)
                            .accessibilityHidden(true)
                    }
                    .overlay {
                        shape.strokeBorder(isHovered ? EditorTheme.faint : EditorTheme.softHairline)
                    }

                VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                    Text(item.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(EditorTheme.dim)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        // The same actions as the context menu, for those who don't right-click
        .overlay(alignment: .topTrailing) {
            Menu {
                LibraryItemActions(item: item, viewModel: viewModel)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.55), in: .circle)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(EditorTheme.smallSpacing)
            .opacity(isHovered ? 1 : 0)
            .help("More")
            .accessibilityLabel("More")
        }
        .contextMenu {
            LibraryItemActions(item: item, viewModel: viewModel)
        }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .editorMotion(.smooth, value: thumbnail != nil)
        .help(item.url.lastPathComponent)
        .accessibilityElement(children: .combine)
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
