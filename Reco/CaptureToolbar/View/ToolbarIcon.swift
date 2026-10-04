//
//  ToolbarIcon.swift
//  Reco
//

import SwiftUI

/// A capture toolbar icon: Hugeicons stroke-rounded (MIT), generated as template PNGs into
/// `Assets.xcassets/ToolbarIcons`, so it takes the foreground style. Scales with the text size.
struct ToolbarIcon: View {
    let resource: ImageResource
    @ScaledMetric(relativeTo: .body) private var size = 20

    init(_ resource: ImageResource) {
        self.resource = resource
    }

    var body: some View {
        Image(resource)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
