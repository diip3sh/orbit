//
//  InspectorColorRow.swift
//  Reco
//

import SwiftUI

/// A title on the left and its color wells on the right edge, as a switch's row. A `ColorPicker` puts its well
/// right after its own title, so wells stood at different places down the column.
struct InspectorColorRow<Wells: View>: View {
    let title: LocalizedStringKey
    let wells: Wells

    init(_ title: LocalizedStringKey, @ViewBuilder wells: () -> Wells) {
        self.title = title
        self.wells = wells()
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            wells
                .labelsHidden()
        }
    }
}
