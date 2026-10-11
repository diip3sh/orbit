//
//  MotionFrameRenderer+Handoff.swift
//  Reco
//

import CoreImage

/// A flow seam drawn (spec 0020, ``MotionPlan/handOff(from:to:way:canvas:)``): one ground, the scene before's layers leaving,
/// the next's arriving over them, and what both scenes have travelling on top from one place to the other, as Keynote's Magic
/// Move and After Effects' shared elements do.
nonisolated extension MotionFrameRenderer {

    /// The frame `time` into a flow into the scene at `index`; layers drawn sharp where they are at `sharp`.
    static func handedOff(into index: Int, at time: Double, sharpAt sharp: Double, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let (before, next) = (plan.scenes[index - 1], plan.scenes[index])
        let carried = MotionPlan.carried(from: before, to: next)
        let past = before.duration + time
        var field = ground(index - 1, at: past, plan: plan)
        // A new ground comes up under what arrives
        if next.field != before.field {
            let progress = min(max(time / SeamExpansion.flowDuration, 0), 1)
            field = ground(index, at: time, plan: plan).fading(to: MotionEasing.enter.progress(progress, duration: 1)).composited(over: field)
        }
        let leaving = sceneImage(index - 1, at: past, sharpAt: before.duration + sharp, plan: plan, frames: frames, hiding: carried, onField: false)
        let arriving = sceneImage(index, at: time, sharpAt: sharp, plan: plan, frames: frames, hiding: carried, onField: false)
        return travelling(into: index, at: time, over: field, plan: plan, frames: frames)
            .composited(over: arriving.composited(over: leaving))
            .composited(over: field)
    }

    /// The layers both scenes have, part of the way from their places in the scene before to theirs in the next: a rectangle
    /// changing its size, corners and colour on the way, anything else turning into the next scene's in the middle of it.
    private static func travelling(into index: Int, at time: Double, over field: CIImage, plan: MotionPlan, frames: [MotionPlan.LayerKey: CIImage]) -> CIImage {
        let (before, next) = (plan.scenes[index - 1], plan.scenes[index])
        let carried = MotionPlan.carried(from: before, to: next)
        guard !carried.isEmpty else { return .empty() }
        let past = before.duration + time
        let carry = MotionPlan.flowCarry
        let progress = carry.easing.progress(min(max(time / carry.duration, 0), 1), duration: carry.duration)
        let change = min(max((progress - 0.3) / 0.4, 0), 1)
        let look = change * change * (3 - 2 * change)
        let (leaving, arriving) = (plan.placements(of: before, at: past), plan.placements(of: next, at: time))
        let carriedOut = Dictionary(leaving.filter { carried.contains(before.layers[$0.layer].id) }.map { (before.layers[$0.layer].id, $0) }) { first, _ in first }
        var image = CIImage.empty()
        for placement in arriving {
            let (layer, id) = (next.layers[placement.layer], next.layers[placement.layer].id)
            guard carried.contains(id), let from = carriedOut[id] else { continue }
            if let start = before.layers[from.layer].fill(at: past), let end = layer.fill(at: time) {
                let shape = ShapeMorph.image(of: ShapeMorph.interpolated(start, end, progress), scale: layer.rasterScale)
                // Seen throughout, though the groups it travels out of and into fade
                let moved = mixed(from, placement, progress, layer: placement.layer, opacity: max(from.opacity, placement.opacity))
                let drawn = layerImage(moved, in: index, over: field, at: time, placements: arriving, plan: plan, frames: frames, content: shape)
                image = drawn?.composited(over: image) ?? image
                continue
            }
            let opacity = max(from.opacity, placement.opacity)
            let out = mixed(from, placement, progress, layer: from.layer, opacity: opacity * (1 - look))
            let into = mixed(from, placement, progress, layer: placement.layer, opacity: opacity * look)
            if look < 1, let drawn = layerImage(out, in: index - 1, over: field, at: past, placements: leaving, plan: plan, frames: frames) {
                image = drawn.composited(over: image)
            }
            if look > 0, let drawn = layerImage(into, in: index, over: field, at: time, placements: arriving, plan: plan, frames: frames) {
                image = drawn.composited(over: image)
            }
        }
        return image
    }

    /// How far the scene before's leaving layers and the carried ones move while a shutter `shutter` long is open at `time`
    /// into a flow, in canvas pixels: the most any corner travels.
    static func flowTravel(into index: Int, at time: Double, across shutter: Double, plan: MotionPlan) -> Double {
        let (before, next) = (plan.scenes[index - 1], plan.scenes[index])
        let carried = MotionPlan.carried(from: before, to: next)
        let corners = { (time: Double) -> [String: [CGPoint]] in
            let past = before.duration + time
            let leaving = Dictionary(plan.placements(of: before, at: past).map { ("\($0.layer)", $0.corners) }) { first, _ in first }
            let carry = MotionPlan.flowCarry
            let progress = carry.easing.progress(min(max(time / carry.duration, 0), 1), duration: carry.duration)
            let out = Dictionary(plan.placements(of: before, at: past).filter { carried.contains(before.layers[$0.layer].id) }
                .map { (before.layers[$0.layer].id, $0) }) { first, _ in first }
            let travelling = plan.placements(of: next, at: time).compactMap { placement -> (String, [CGPoint])? in
                guard let from = out[next.layers[placement.layer].id] else { return nil }
                return ("carried \(placement.layer)", mixed(from, placement, progress, layer: placement.layer, opacity: 1).corners)
            }
            return leaving.merging(travelling) { first, _ in first }
        }
        let (opening, closing) = (corners(time - shutter / 2), corners(time + shutter / 2))
        return opening.compactMap { key, start in
            closing[key].map { end in zip(start, end).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0 }
        }.max() ?? 0
    }

    /// `progress` of the way from `from` to `to`, as the layer at `layer` with `opacity`.
    private static func mixed(
        _ origin: MotionPlan.Placement, _ target: MotionPlan.Placement, _ progress: Double, layer: Int, opacity: Double
    ) -> MotionPlan.Placement {
        let mix = { (start: Double, end: Double) in start + (end - start) * progress }
        let points = { (start: [CGPoint], end: [CGPoint]) in zip(start, end).map { CGPoint(x: mix($0.x, $1.x), y: mix($0.y, $1.y)) } }
        var placement = MotionPlan.Placement(
            layer: layer, corners: points(origin.corners, target.corners), depth: mix(origin.depth, target.depth), opacity: opacity,
            blur: mix(origin.blur, target.blur), scale: mix(origin.scale, target.scale)
        )
        placement.shadowCorners = (target.shadowCorners ?? origin.shadowCorners).map { end in points(origin.shadowCorners ?? end, end) }
        placement.defocus = origin.defocus.count == target.defocus.count ? zip(origin.defocus, target.defocus).map { mix($0, $1) } : target.defocus
        return placement
    }
}
