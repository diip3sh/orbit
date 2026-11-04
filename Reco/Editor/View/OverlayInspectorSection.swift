//
//  OverlayInspectorSection.swift
//  Reco
//

import SwiftUI

/// The selected overlay's content and style, and when it shows.
struct OverlayInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        if let overlay = Binding(unwrapping: $viewModel.selectedOverlay) {
            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                InspectorSectionHeader("Overlay")
                switch overlay.wrappedValue.kind {
                case .text:
                    if let style = Binding(unwrapping: overlay.textStyle) {
                        TextOverlayCard(style: style)
                    }
                case .image(let bookmark):
                    ImageOverlayCard(viewModel: viewModel, bookmark: bookmark)
                case .arrow:
                    if let style = Binding(unwrapping: overlay.arrowStyle) {
                        ArrowOverlayCard(style: style)
                    }
                }
                OverlayTimingNote(timeMap: viewModel.timeMap, overlay: overlay.wrappedValue)
            }
            // Another overlay's fields start over, as its field's focus and picture don't carry over
            .id(overlay.wrappedValue.id)
        }
    }
}
