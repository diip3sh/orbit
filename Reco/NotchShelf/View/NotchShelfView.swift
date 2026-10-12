//
//  NotchShelfView.swift
//  Reco
//

import SwiftUI

/// The notch shelf (spec 0013): a black shape at the top of the screen that is the notch (or a pill),
/// peeks a little when the pointer is on it, and grows into a strip of the newest screenshots when it stays.
/// Pure black like the notch, in light and dark appearance alike, so the content uses the dark scheme (and the
/// theme's dark values).
///
/// Size, radii and shadow all follow two flags under one spring each (`NotchMotion`), so the shape visibly
/// grows out of the notch. With Reduce Motion nothing moves: the shape changes at once and the content
/// cross-fades.
struct NotchShelfView: View {
    let viewModel: NotchShelfViewModel

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        let geometry = viewModel.geometry
        let isExpanded = viewModel.isExpanded
        let isPeeking = viewModel.isPeeking
        let size: CGSize = isExpanded ? geometry.expanded.size : isPeeking ? geometry.peek.size : geometry.collapsed.size
        let shadowOpacity: Double = isExpanded ? NotchMotion.expandedShadowOpacity : isPeeking ? NotchMotion.peekShadowOpacity : 0
        let shape = NotchShape(
            topRadius: isExpanded ? NotchMotion.expandedTopRadius : NotchMotion.collapsedTopRadius,
            bottomRadius: isExpanded ? NotchMotion.expandedBottomRadius : NotchMotion.collapsedBottomRadius
        )

        shape
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                // Laid out at its full size whatever the shape's, so it doesn't reflow as the shape grows
                NotchShelfContent(viewModel: viewModel, isShown: isExpanded)
                    .frame(width: geometry.expanded.width, height: geometry.expanded.height, alignment: .top)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(shadowOpacity), radius: NotchMotion.shadowRadius)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Where both change at once (the pointer stayed: the peek ends as it opens) the first, nearer modifier wins
            .animation(reducesMotion ? nil : isExpanded ? NotchMotion.expand : NotchMotion.collapse, value: isExpanded)
            .animation(reducesMotion ? nil : isPeeking ? NotchMotion.peekIn : NotchMotion.peekOut, value: isPeeking)
            .environment(\.colorScheme, .dark)
    }
}

/// The header and the strip of screenshots, each arriving and leaving on its own transition
private struct NotchShelfContent: View {
    let viewModel: NotchShelfViewModel
    let isShown: Bool

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            if isShown {
                NotchShelfHeader(count: viewModel.items?.count)
                    .transition(reducesMotion ? Self.fade : NotchMotion.headerTransition)
                NotchShelfStrip(viewModel: viewModel)
                    .transition(reducesMotion ? Self.fade : NotchMotion.bodyTransition)
            }
        }
        .padding(.top, viewModel.geometry.contentTopInset)
        .padding(.horizontal, NotchMotion.expandedTopRadius + EditorTheme.mediumSpacing)
        .padding(.bottom, EditorTheme.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static let fade = AnyTransition.opacity.animation(EditorTheme.fadeMotion)
}

private struct NotchShelfHeader: View {
    let count: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EditorTheme.tightSpacing) {
            Text("Screenshots")
                .font(.theme(.subheadline, weight: .bold))
                .foregroundStyle(EditorTheme.ink)
            if let count, count > 0 {
                Text(count, format: .number)
                    .font(.theme(.subheadline))
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .frame(height: 20)
    }
}

private struct NotchShelfStrip: View {
    let viewModel: NotchShelfViewModel

    var body: some View {
        if let items = viewModel.items, items.isEmpty {
            Text("No screenshots yet")
                .font(.theme(.subheadline))
                .foregroundStyle(EditorTheme.dim)
                .frame(maxWidth: .infinity, maxHeight: NotchShelfTile.size.height)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditorTheme.smallSpacing) {
                    ForEach(viewModel.items ?? []) { item in
                        NotchShelfTile(
                            item: item, thumbnail: viewModel.thumbnails[item.url], isCopied: viewModel.copiedURL == item.url,
                            pointer: viewModel.pointer
                        ) {
                            Task { await viewModel.copy(item) }
                        }
                        .task {
                            await viewModel.loadThumbnail(for: item)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: NotchShelfTile.size.height)
        }
    }
}

/// One screenshot: click to copy, drag to drop the file into an app
private struct NotchShelfTile: View {
    nonisolated static let size = CGSize(width: 140, height: 88)

    let item: LibraryItem
    let thumbnail: CGImage?
    let isCopied: Bool
    let pointer: CGPoint?
    let copy: () -> Void

    @State private var frame = CGRect.zero
    @GestureState private var isPressed = false

    private var isHovered: Bool { pointer.map(frame.contains) ?? false }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)

        ZStack {
            EditorTheme.control
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .scaledToFill()
            }
            EditorTheme.stage.opacity(isPressed ? 0.25 : 0)
            if isCopied {
                EditorTheme.stage.opacity(0.6)
                Label("Copied", systemImage: "checkmark")
                    .font(.theme(.caption, weight: .bold))
                    .foregroundStyle(EditorTheme.ink)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(shape)
        // Hover rings the tile in the accent instead of washing out the picture
        .overlay(shape.strokeBorder(isHovered ? EditorTheme.accent : EditorTheme.hairline, lineWidth: isHovered ? 2 : 1))
        .scaleEffect(isPressed ? 0.96 : 1)
        .contentShape(shape)
        // The hosting view's coordinates, which the pointer is in
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .editorMotion(isPressed ? nil : EditorTheme.quickMotion, value: isPressed)
        // A press shows on the frame it lands; moving 4 pt ends it, so the file drag takes over
        .simultaneousGesture(
            LongPressGesture(minimumDuration: .infinity, maximumDistance: 4).updating($isPressed) { _, pressed, _ in pressed = true }
        )
        .editorMotion(EditorTheme.quickMotion, value: isCopied)
        // Not a Button: its press tracking would swallow the mouse-down that starts a drag
        .onTapGesture(perform: copy)
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .accessibilityElement()
        .accessibilityLabel(item.name)
        .accessibilityHint("Copies the screenshot")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, copy)
    }
}
