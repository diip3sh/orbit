//
//  LibraryPicturePreview.swift
//  Reco
//

import SwiftUI

/// The picture a click opened over the grid (`LibraryScatter`): it springs out of its tile to fit the view, and back
/// into the tile on close, each time from wherever it is, so a click mid-flight turns it round. Its size changes, not
/// its scale, so the tile's crop opens out to the whole picture. The tile's picture shows until the sharp one is
/// decoded. The Quick Access card's Copy and Save and a Delete sit under it; ← and → take it to the picture
/// before or after it in the grid, which it then closes into. A click anywhere else over the grid, or Esc, closes it;
/// with Reduce Motion, or when its tile isn't laid out, it fades in and out where it fits.
struct LibraryPicturePreview: View {
    let scatter: LibraryScatter

    /// The opened tile, `nil` while it isn't laid out.
    let tile: Anchor<CGRect>?
    let viewModel: LibraryViewModel

    /// The picture so many places along the grid from this one, if there is one.
    let neighbour: (Int) -> LibraryItem?

    /// Asks the grid to show another item here: a neighbour, or this one where Save moved it.
    let show: (LibraryItem) -> Void

    /// Asks the grid to close the picture.
    let close: () -> Void

    /// The picture is back in its tile: the grid shows the tile again and removes this.
    let didClose: () -> Void

    /// The picture's spring, out and back, and the other tiles' on the way home: snappier than kosmica's response
    /// 0.30 s at 0.9 damping, at 0.25 s and 0.85 (stiffness 631.7 and damping 42.7 at mass 1), which overshoots by
    /// 0.6%, about SwiftUI's `.snappy` bounce.
    static let motion = Animation.spring(response: 0.25, dampingFraction: 0.85)

    /// The other tiles' spring outwards, a little slower than the picture's (stiffness 503.6, damping 38.1).
    static let scatterMotion = Animation.spring(response: 0.28, dampingFraction: 0.85)

    /// The other tiles fade out fast as they leave, and back in as they come home, done before the picture has
    /// settled in its tile so the tile shows whole when it takes over.
    static let fadeOut = Animation.linear(duration: 0.13)
    static let fadeIn = Animation.easeOut(duration: 0.25)

    /// Kosmica's 50 px around the opened picture, and Copy, Save and Delete.
    private static let margin: CGFloat = 50

    /// Copy, Save and Delete sit this far under the picture, in a row this tall: the large glass buttons' height,
    /// measured on macOS 27 (2026-10-15; the row is 288 pt wide).
    private static let actionsGap = EditorTheme.mediumSpacing
    private static let actionsHeight: CGFloat = 29

    @State private var isExpanded = false

    /// The sharp picture and what it is of: the arrows change the item before the next one is decoded.
    @State private var picture: (item: LibraryItem, image: CGImage)?

    /// Copy's tick shows for 1.5 s, on the picture it was for.
    @State private var copied: LibraryItem?

    /// Counts the moves out and back, so the end of one that was turned round is ignored.
    @State private var moves = 0

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        // A proxy is the only way to resolve the tile's anchor, which follows the grid wherever it has scrolled
        GeometryReader { proxy in
            // The picture fits above its buttons, so the two are centred together
            let bounds = CGRect(origin: .zero, size: proxy.size).insetBy(dx: Self.margin, dy: Self.margin)
                .divided(atDistance: Self.actionsGap + Self.actionsHeight, from: .maxYEdge).remainder
            let fitted = LibraryScatter.fitted(aspectRatio: viewModel.aspectRatios[scatter.item] ?? 16 / 10, in: bounds)
            let start = reducesMotion ? nil : tile.map { proxy[$0] }
            let frame = isExpanded ? fitted : start ?? fitted

            ZStack(alignment: .topLeading) {
                Button(action: close) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        image(in: frame)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close \(scatter.item.name)")

                actions
                    .frame(width: frame.width)
                    .offset(x: frame.minX, y: frame.maxY + Self.actionsGap)
                    // Gone before the picture is far on its way back, like the other tiles
                    .opacity(isExpanded ? 1 : 0)
                    .animation(isExpanded ? Self.fadeIn : Self.fadeOut, value: isExpanded)
            }
            .opacity(isExpanded || start != nil ? 1 : 0)
            .task(id: scatter.item) {
                guard picture?.item != scatter.item else { return }
                let size = CGSize(width: fitted.width * displayScale, height: fitted.height * displayScale)
                if let image = await viewModel.picture(of: scatter.item, maximumSize: size) {
                    picture = (scatter.item, image)
                }
            }
        }
        // Another picture takes this one's place by taking its shape
        .animation(reducesMotion ? EditorTheme.fadeMotion : Self.motion, value: scatter.item)
        .background {
            Group {
                Button("Previous Picture") { step(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Picture") { step(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        // On its way back the grid takes clicks again, so the same tile can be opened again mid-flight
        .allowsHitTesting(scatter.isOpen)
        .onAppear { move(open: true) }
        .onChange(of: scatter.isOpen) { _, isOpen in
            move(open: isOpen)
        }
    }

    private func image(in frame: CGRect) -> some View {
        let shape = RoundedRectangle(cornerRadius: isExpanded ? EditorTheme.largeRadius : EditorTheme.radius, style: .continuous)
        let image = picture.flatMap { $0.item == scatter.item ? $0.image : nil } ?? viewModel.loadedThumbnail(for: scatter.item)

        return EditorTheme.control
            .overlay {
                // The next picture fades in over the last as the frame takes its shape
                ZStack {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .id(scatter.item)
                .transition(.opacity)
            }
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay { shape.strokeBorder(EditorTheme.hairline) }
            .offset(x: frame.minX, y: frame.minY)
    }

    /// Copy, Save and Delete, as the Quick Access card has them, Delete tinted with the danger colour. Save moves a screenshot
    /// out of the history, so it shows only for one there; anything else is already where it stays.
    private var actions: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Button(action: copy) {
                ShortcutLabel(title: "Copy", keys: "⌘C", confirmation: "Copied", isConfirmed: copied == scatter.item)
            }
            .keyboardShortcut("c", modifiers: .command)
            if !viewModel.isSaved(scatter.item) {
                Button(action: save) {
                    ShortcutLabel(title: "Save", keys: "⌘S")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("Move it from the history into the screenshot folder")
            }
            Button(role: .destructive, action: delete) {
                ShortcutLabel(title: "Delete", keys: "⌘⌫")
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .help("Move to Trash")
        }
        .buttonStyle(QuickAccessGlassButtonStyle())
        // Their shortcuts stay registered while the picture closes
        .disabled(!scatter.isOpen)
    }

    private func copy() {
        let item = scatter.item
        Task {
            await viewModel.copy(item)
            copied = item
            try? await Task.sleep(for: .seconds(1.5))
            if copied == item {
                copied = nil
            }
        }
    }

    private func save() {
        let item = scatter.item
        Task {
            guard let saved = await viewModel.save(item) else { return }
            // The same pixels, so the saved picture doesn't blur while it is decoded again
            if let picture, picture.item == item {
                self.picture = (saved, picture.image)
            }
            show(saved)
        }
    }

    /// The next picture takes the deleted one's place, or the one before it at the end; with neither, the grid fades
    /// this out.
    private func delete() {
        let item = scatter.item
        let next = neighbour(1) ?? neighbour(-1)
        Task {
            if await viewModel.trash(item), let next {
                show(next)
            }
        }
    }

    private func step(by offset: Int) {
        guard scatter.isOpen, let item = neighbour(offset) else { return }
        show(item)
    }

    private func move(open: Bool) {
        moves += 1
        let move = moves
        withAnimation(reducesMotion ? EditorTheme.fadeMotion : Self.motion, completionCriteria: .removed) {
            isExpanded = open
        } completion: {
            if !open, move == moves {
                didClose()
            }
        }
    }
}

/// The opened tile's bounds, for the picture to leave from and land back in.
nonisolated struct LibraryOpenedTile: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
