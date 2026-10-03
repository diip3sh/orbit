//
//  LineIcon.swift
//  Reco
//

import SwiftUI

/// A 1.5 pt line icon from `Assets.xcassets/LineIcons`, drawn in the foreground style and scaled with Dynamic
/// Type like a symbol. `iconsax-` ones are Iconsax Linear (MIT, iconsax-react); the text scan is Iconsax's scan
/// frame around text lines; `tabler-pin` is Tabler's (MIT, tabler.io), drawn at Iconsax's 1.5 stroke, since
/// Iconsax has no pin.
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
