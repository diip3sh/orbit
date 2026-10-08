//
//  CaptureToolbarPill.swift
//  Reco
//

import SwiftUI

extension View {

    /// One of the toolbar's groups: a solid surface with a hairline edge. No shadow: the bar's window
    /// leaves only `CaptureToolbarView.margin` around it, less than the floating shadow needs.
    func captureToolbarPill(tint: Color = CaptureToolbarView.ground) -> some View {
        padding(4)
            .editorSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous), fill: tint)
    }
}
