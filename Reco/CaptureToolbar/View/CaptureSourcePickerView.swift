//
//  CaptureSourcePickerView.swift
//  Reco
//

import AppKit
import SwiftUI

/// The windows or displays to record, as thumbnails in a dark glass panel above the capture toolbar.
/// A click records that one; Esc or Cancel closes it.
struct CaptureSourcePickerView: View {
    let picker: CaptureSourcePicker
    let presence: PanelPresence

    /// Room around the panel for its glass's edge and shadow, inside the window
    static let margin: CGFloat = 12

    private typealias Grid = CaptureSourceGrid

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.spacing) {
            header
            content
        }
        .frame(width: size.width - Grid.padding * 2, height: size.height - Grid.padding * 2, alignment: .top)
        // The pill adds 4 pt of its own
        .padding(Grid.padding - 4)
        .captureToolbarPill(isInteractive: false)
        .environment(\.colorScheme, .dark)
        .padding(Self.margin)
        .panelPresentation(isPresented: presence.isShown, anchor: .bottom)
    }

    private var size: CGSize {
        Grid.size(for: picker.sources?.count)
    }

    private var header: some View {
        HStack {
            Text(picker.kind == .display ? "Choose a Display to Record" : "Choose a Window to Record")
                .font(.headline)
            Spacer()
            Button("Cancel") { picker.cancel() }
                .buttonStyle(.captureToolbar)
                .keyboardShortcut(.cancelAction)
        }
        .frame(height: Grid.headerHeight)
    }

    @ViewBuilder
    private var content: some View {
        if picker.failed {
            message("Allow Reco to record the screen in System Settings → Privacy & Security, then try again.")
        } else if let sources = picker.sources {
            if sources.isEmpty {
                message(picker.kind == .display ? "No displays to record." : "No windows to record.")
            } else {
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
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .strokeBorder(.white.opacity(configuration.isPressed ? 0.9 : isHovered ? 0.6 : 0), lineWidth: 2)
                    .frame(height: CaptureSourceGrid.thumbnailHeight)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            // Only the press lands at once; hover and release ease
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isHovered || configuration.isPressed)
    }
}
