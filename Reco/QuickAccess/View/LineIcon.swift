//
//  LineIcon.swift
//  Reco
//

import SwiftUI

/// A 1.5 pt line icon from `Assets.xcassets/LineIcons`, drawn in the foreground style and scaled with Dynamic
/// Type like a symbol. They are Hugeicons stroke-rounded (MIT, @hugeicons/core-free-icons), the capture toolbar's
/// set: the app's icons are SF Symbols and Hugeicons only.
struct LineIcon: View {

    let resource: ImageResource
    @ScaledMetric(relativeTo: .caption) private var size = 14

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
