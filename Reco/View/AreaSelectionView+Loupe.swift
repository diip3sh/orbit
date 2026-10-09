//
//  AreaSelectionView+Loupe.swift
//  Reco
//

import AppKit

extension AreaSelectionView {

    /// Shows the loupe beside `point` with the pixel under it at its centre while `visible`, else takes it away.
    /// Only over a frozen screen: a live selection has no still pixels to magnify.
    func updateLoupe(at point: CGPoint, visible: Bool) {
        guard visible, let frozenScreen else {
            hideLoupe()
            return
        }
        let loupe = loupe ?? LoupeView(image: frozenScreen)
        if self.loupe == nil {
            addSubview(loupe)
            self.loupe = loupe
        }
        loupe.frame = LoupeGeometry.frame(beside: point, in: bounds)
        loupe.pixel = LoupeGeometry.pixel(
            under: point, in: bounds, imageSize: CGSize(width: frozenScreen.width, height: frozenScreen.height)
        )
    }

    func hideLoupe() {
        loupe?.removeFromSuperview()
        loupe = nil
    }

    /// The pointer has gone to another display, whose own view shows the loupe
    override func mouseExited(with event: NSEvent) {
        hideLoupe()
    }
}
