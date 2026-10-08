//
//  InspectorTabBar.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import SwiftUI

/// The inspector's tabs as icons on one track, a line between groups; the chosen one's fill slides to
/// it, as in ``SegmentedChoice``. A tab with nothing to edit is dimmed and says why in its tooltip.
struct InspectorTabBar: View {
    @Binding var selection: InspectorTab
    let isAvailable: (InspectorTab) -> Bool

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            let tabs = InspectorTab.allCases
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                if index > 0, tab.group != tabs[index - 1].group {
                    Rectangle()
                        .fill(EditorTheme.hairline)
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)
                }
                button(for: tab)
            }
        }
        .padding(2)
        .background(EditorTheme.softHairline, in: .capsule)
        .editorMotion(EditorTheme.quickMotion, value: selection)
    }

    private func button(for tab: InspectorTab) -> some View {
        let isSelected = tab == selection
        let available = isAvailable(tab)
        return Button {
            selection = tab
        } label: {
            Label(tab.title, systemImage: tab.symbol)
                .labelStyle(.iconOnly)
                .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(EditorTheme.stage)
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.4)
        .help(available ? tab.title : tab.unavailableReason)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
