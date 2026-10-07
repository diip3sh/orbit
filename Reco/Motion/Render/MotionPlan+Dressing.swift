//
//  MotionPlan+Dressing.swift
//  Reco
//

import Foundation

nonisolated extension MotionPlan.Layer {

    /// The layer with the glass and typing (spec 0012) of `asset`, lifted as `lift`, put on it, in a
    /// scene `sceneDuration` seconds long. A layer that types is drawn by its typing, not one image.
    func dressed(showing lifted: UIContent, asset: MotionAsset, lift: UILiftCache.Lift, sceneDuration: Double, bundle: URL) -> MotionPlan.Layer {
        var layer = self
        if asset.glass == true {
            // Canvas pixels per CSS pixel
            let scale = size.width / lift.size.width
            layer.glass = GlassRenderer.Shape(radius: (lift.radius ?? 0) * scale, rim: GlassRenderer.rimWidth * scale)
        }
        if var typing = TypedField(asset, showing: lifted, lift: lift, layer: self, bundle: bundle) {
            // The caret blinks from when the layer first shows, to a sixtieth of a second
            typing.shown = stride(from: 0, through: sceneDuration, by: 1.0 / 60).first { value(.opacity, at: $0) > 0 } ?? 0
            layer.typing = typing
        }
        return layer
    }
}
