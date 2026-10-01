//
//  ZoomBlock.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A zoom on the timeline's zoom lane, with its scale when there's room.
struct ZoomBlock: View {
    let zoom: ZoomSegment
    let isSelected: Bool
    let isDragged: Bool

    var body: some View {
        TimelineBlock(isSelected: isSelected, isDragged: isDragged) {
            Label {
                Text("\(zoom.scale, format: .number.precision(.fractionLength(0...2)))×")
            } icon: {
                Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
            }
        }
    }
}
