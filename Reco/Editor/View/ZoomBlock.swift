//
//  ZoomBlock.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A zoom on the timeline's zoom lane: a dashed "Auto · 2×" chip while it's the app's, a solid
/// "2×" one once the user has touched it.
struct ZoomBlock: View {
    let zoom: ZoomSegment
    let isSelected: Bool
    let isDragged: Bool

    var body: some View {
        TimelineBlock(tone: zoom.isAutomatic ? .automatic : .manual, isSelected: isSelected, isDragged: isDragged) {
            // The icon alone on a zoom too short for its label, rather than a cut-off label
            ViewThatFits(in: .horizontal) {
                Label {
                    Text(zoom.isAutomatic ? "Auto · \(scale)" : scale)
                } icon: {
                    Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
                }
                Image(systemName: zoom.followsCursor ? "cursorarrow" : "scope")
            }
        }
    }

    private var scale: String {
        SpeedRange.label(for: zoom.scale)
    }
}
