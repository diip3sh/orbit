//
//  CaptureSourcePickerView.swift
//  Reco
//

import AppKit
import SwiftUI

/// The windows or displays to record, as thumbnails above the capture toolbar. Nothing is drawn but a
/// light frost behind them, so what is offered is the window's picture and its name: no panel with a
/// title or a button in it. A click records that one; Esc or a click elsewhere closes it.
///
/// It shares the toolbar's window rather than sitting in one of its own — a second window would take
/// key from the bar and macOS would draw the bar's controls as inactive while it was open.
struct CaptureSourcePickerView: View {
    let picker: CaptureSourcePicker

    private typealias Grid = CaptureSourceGrid

    var body: some View {
        content
            .frame(width: panelSize.width - Grid.padding * 2, height: panelSize.height - Grid.padding * 2)
            .padding(Grid.padding)
            .pickerBackdrop()
            .environment(\.colorScheme, .dark)
            .panelPresentation(isPresented: picker.isOpen, anchor: .bottom, motion: EditorTheme.quickMotion)
    }

    /// What the tiles take up, padding included, so the bar's window can be measured around it
    private var panelSize: CGSize {
        guard let sources = picker.sources, !sources.isEmpty else { return Grid.messageSize }
        return Grid.size(for: sources.count)
    }

    @ViewBuilder
    private var content: some View {
        if picker.failed {
            notice("Allow Reco to record the screen in System Settings → Privacy & Security, then try again.")
        } else if let sources = picker.sources {
            if sources.isEmpty {
                notice(picker.kind == .display ? "No displays to record." : "No windows to record.")
            } else {
                grid(sources)
            }
        } else {
            // Only a load slow enough to be noticed: a warm one shows the tiles straight away
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func grid(_ sources: [CaptureSource]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(Grid.tileWidth), spacing: Grid.spacing), count: Grid.columns(for: sources.count)),
                spacing: Grid.spacing
            ) {
                ForEach(sources) { source in
                    CaptureSourceTile(source: source, thumbnail: picker.thumbnails[source.id]) {
                        picker.pick(source)
                    }
                }
            }
        }
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

extension View {
    /// The picker's own frost, behind the tiles
    fileprivate func pickerBackdrop() -> some View {
        modifier(PickerBackdrop())
    }
}

/// The frost the tiles and their names sit on: without it they land straight on whatever is under the
/// panel and the names can't be read. A plain dark frost — no edge, no tint of its own, and lighter than
/// the bar's glass, so it reads as one surface with the bar rather than a second panel. Solid with Reduce
/// Transparency, which has no blur to fall back on.
private struct PickerBackdrop: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .background {
                if reducesTransparency {
                    shape.fill(CaptureToolbarView.ground.opacity(0.88))
                } else {
                    // Dark enough for white labels over any window, whatever is behind the panel
                    shape.fill(.ultraThinMaterial)
                    shape.fill(CaptureToolbarView.ground.opacity(0.55))
                }
            }
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(.white.opacity(0.4))
                }
            }
    }
}

/// One window or display: its picture, then its app's icon, title and subtitle. A ring marks it under
/// the pointer; the press shows at once.
private struct CaptureSourceTile: View {
    let source: CaptureSource
    let thumbnail: CGImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                picture
                label
            }
        }
        .buttonStyle(CaptureSourceTileStyle())
        .accessibilityLabel(source.subtitle.isEmpty ? source.title : "\(source.title), \(source.subtitle)")
    }

    private var picture: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 4, style: .continuous))
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .frame(width: CaptureSourceGrid.tileWidth, height: CaptureSourceGrid.thumbnailHeight)
        .editorMotion(EditorTheme.quickMotion, value: thumbnail == nil)
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
                    .font(.callout)
                    .lineLimit(1)
                Text(source.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: CaptureSourceGrid.tileWidth, height: CaptureSourceGrid.labelHeight, alignment: .leading)
    }
}

private struct CaptureSourceTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CaptureSourceTileBody(configuration: configuration)
    }
}

private struct CaptureSourceTileBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .overlay(alignment: .top) {
                shape
                    // The accent, as the toolbar marks what is chosen: full on press, softer under the pointer
                    .strokeBorder(CaptureToolbarView.live.opacity(configuration.isPressed ? 1 : isHovered ? 0.7 : 0), lineWidth: 2)
                    .frame(height: CaptureSourceGrid.thumbnailHeight)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            // Only the press lands at once; hover and release ease
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isHovered || configuration.isPressed)
    }
}
