//
//  CaptureSourcePickerView.swift
//  Reco
//

import AppKit
import SwiftUI

/// The windows or displays to record, as thumbnails above the capture toolbar. Nothing is drawn but a
/// raised surface behind them, so what is offered is the window's picture and its name: no panel with a
/// title or a button in it. A click records that one; Esc or a click elsewhere closes it.
///
/// It shares the toolbar's window rather than sitting in one of its own — a second window would take
/// key from the bar and macOS would draw the bar's controls as inactive while it was open.
///
/// It slides up out of the bar on a spring and its tiles follow one after another, then all of it slides
/// back down into the bar the same way. Reduce Motion fades it instead.
struct CaptureSourcePickerView: View {
    let picker: CaptureSourcePicker

    private typealias Grid = CaptureSourceGrid

    /// How far below its place the frost, and each tile on it, starts
    static let rise: CGFloat = 16

    /// A little bounce, so the row lands rather than stops
    static let motion = Animation.spring(response: 0.38, dampingFraction: 0.8)

    /// Between one tile's start and the next's, arriving; leaving is quicker
    static let stagger = 0.035
    /// Tiles past this many start with the last of them, so a long row doesn't trail
    static let staggeredTiles = 5

    /// How long it stays mounted after it closes: the spring plus the leaving stagger
    nonisolated static let exitDelay = Duration.milliseconds(450)

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        let isShown = hasAppeared && picker.isOpen
        content
            .frame(width: panelSize.width, height: panelSize.height)
            .clipShape(.rect(cornerRadius: PickerBackdrop.cornerRadius, style: .continuous))
            .pickerBackdrop()
            .foregroundStyle(EditorTheme.ink)
            // Scoped, so the window growing around it in the same update isn't animated
            .animation(reducesMotion ? EditorTheme.fadeMotion : Self.motion) { view in
                view
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reducesMotion ? 0 : Self.rise)
            }
            .onAppear { hasAppeared = true }
    }

    /// What the tiles take up, padding included, so the bar's window can be measured around it
    private var panelSize: CGSize {
        guard let sources = picker.sources, !sources.isEmpty else { return Grid.messageSize }
        return Grid.size(for: sources.count)
    }

    @ViewBuilder
    private var content: some View {
        if picker.failed {
            notice("Allow Orbit to record the screen in System Settings → Privacy & Security, then try again.")
        } else if let sources = picker.sources {
            if sources.isEmpty {
                notice(picker.kind == .display ? "No displays to record." : "No windows to record.")
            } else {
                row(sources)
            }
        } else {
            // Only a load slow enough to be noticed: a warm one shows the tiles straight away
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// One row, scrolled sideways past four tiles. The scroll view spans the backdrop, so tiles scroll
    /// out under its edges rather than being cut off inside its padding.
    private func row(_ sources: [CaptureSource]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Not lazy: every tile takes part in the entrance, and their thumbnails are drawn anyway
                HStack(spacing: Grid.spacing) {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        CaptureSourceTile(
                            source: source,
                            thumbnail: picker.thumbnails[source.id],
                            isHighlighted: picker.highlighted == source.id,
                            onHover: { picker.highlight(source.id) },
                            action: { picker.pick(source) }
                        )
                        .id(source.id)
                        .modifier(StaggeredEntrance(index: index, isPresented: picker.isOpen))
                    }
                }
                .padding(.vertical, Grid.padding)
            }
            .contentMargins(.horizontal, Grid.padding, for: .scrollContent)
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            // A tile moved to with the keyboard is scrolled into view
            .onChange(of: picker.highlighted) { _, id in
                guard let id else { return }
                withMotion { proxy.scrollTo(id) }
            }
        }
        // ← and → move the highlight; Return (the bar's action) records it
        .background {
            Group {
                Button("Previous") { picker.moveHighlight(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next") { picker.moveHighlight(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(EditorTheme.dim)
            .multilineTextAlignment(.center)
            .padding(Grid.padding)
    }
}

/// A tile comes up after the one before it, and goes back down the same way, a little quicker. It runs
/// from the tile's own appearance, so tiles that arrive after a slow load still come up in turn.
private struct StaggeredEntrance: ViewModifier {
    let index: Int
    let isPresented: Bool

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isShown = hasAppeared && isPresented
        let step = isShown ? CaptureSourcePickerView.stagger : CaptureSourcePickerView.stagger / 2
        let delay = Double(min(index, CaptureSourcePickerView.staggeredTiles)) * step
        content
            .animation(reducesMotion ? EditorTheme.fadeMotion : CaptureSourcePickerView.motion.delay(delay)) { view in
                view
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reducesMotion ? 0 : CaptureSourcePickerView.rise)
            }
            .onAppear { hasAppeared = true }
    }
}

extension View {
    /// The picker's own surface, behind the tiles
    fileprivate func pickerBackdrop() -> some View {
        modifier(PickerBackdrop())
    }
}

/// The surface the tiles and their names sit on: without it they land straight on whatever is under the
/// panel and the names can't be read. Raised, a step lighter than the bar, so it reads as a layer over it.
private struct PickerBackdrop: ViewModifier {
    static let cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .editorSurface(in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous), fill: EditorTheme.raised)
    }
}

/// One window or display: its picture, then its app's icon, title and subtitle. A ring marks the
/// highlighted one (the pointer's, or where ← → moved it); the press shows at once.
private struct CaptureSourceTile: View {
    let source: CaptureSource
    let thumbnail: CGImage?
    let isHighlighted: Bool
    let onHover: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                CaptureSourcePicture(thumbnail: thumbnail, isHighlighted: isHighlighted)
                label
            }
        }
        .buttonStyle(CaptureSourceTileStyle())
        .onHover { if $0 { onHover() } }
        .accessibilityLabel(source.subtitle.isEmpty ? source.title : "\(source.title), \(source.subtitle)")
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let icon = source.processID.flatMap({ NSRunningApplication(processIdentifier: $0)?.icon }) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(source.title)
                    .font(.theme(.callout))
                    .lineLimit(1)
                Text(source.subtitle)
                    .font(.theme(.caption))
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: CaptureSourceGrid.tileWidth, height: CaptureSourceGrid.labelHeight, alignment: .leading)
    }
}

/// The window's picture at its own shape, fitted into the tile and sitting on its name. No box around
/// it: a box in the tile's 16:10 left a wide or tall window small inside a bigger frame.
private struct CaptureSourcePicture: View {
    let thumbnail: CGImage?
    let isHighlighted: Bool

    // Set by the tile's button style, inside the label, so it is read here and not on the tile
    @Environment(\.isTilePressed) private var isPressed

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        Group {
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .scaledToFit()
                    .clipShape(shape)
                    .transition(.opacity)
            } else {
                // Until it is drawn, the tile's shape stands in
                shape.fill(EditorTheme.control)
            }
        }
        .overlay {
            // The accent, as the toolbar marks what is chosen: full on press, softer when highlighted
            shape.strokeBorder(EditorTheme.accent.opacity(isPressed ? 1 : isHighlighted ? 0.7 : 0), lineWidth: 2)
        }
        .frame(width: CaptureSourceGrid.tileWidth, height: CaptureSourceGrid.thumbnailHeight, alignment: .bottom)
        .editorMotion(EditorTheme.quickMotion, value: thumbnail == nil)
        // Only the press lands at once; the highlight eases
        .editorMotion(isPressed ? nil : EditorTheme.quickMotion, value: isHighlighted || isPressed)
    }
}

/// Hands the press to the tile's label, which draws the ring around the picture alone
private struct CaptureSourceTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.isTilePressed, configuration.isPressed)
            .contentShape(.rect)
    }
}

extension EnvironmentValues {
    @Entry fileprivate var isTilePressed = false
}
