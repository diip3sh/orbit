//
//  MotionFrameRenderer+Editorial.swift
//  Reco
//

import CoreImage

/// Editorial films' registration marks (spec 0017): ElevenLabs framed what it showed in dotted hairlines across the whole
/// frame, a solid square where they cross.
nonisolated extension MotionFrameRenderer {

    /// The marks round layer `index` of `scene`, in output pixels: the hairlines along the box ``marksClearance`` outside it
    /// and its group's layers as `placements` put them, so they follow it; in their own colour, else ink on a light ground
    /// and white on a dark one.
    static func marks(of index: Int, in scene: MotionPlan.Scene, placements: [MotionPlan.Placement], plan: MotionPlan) -> CIImage {
        let points = placements.filter { scene.isLayer($0.layer, within: index) }.flatMap(\.corners)
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(), let minY = points.map(\.y).min(), let maxY = points.map(\.y).max()
        else { return .empty() }
        let back = scene.palette.back
        let ink = 0.2126 * back.red + 0.7152 * back.green + 0.0722 * back.blue > 0.5 ? 0.0 : 1
        let color = scene.layers[index].marks?.color ?? RGBAColor(red: ink, green: ink, blue: ink, alpha: 1)
        let (unit, scale, frame) = (plan.outputSize.height / 1080, plan.outputScale, CGRect(origin: .zero, size: plan.outputSize))
        let (line, side, clearance) = (max((marksLine * unit).rounded(), 1), (marksSquare * unit).rounded(), marksClearance * unit)
        let dashes = CIFilter(name: "CIStripesGenerator", parameters: [
            "inputCenter": CIVector(x: 0, y: 0), "inputColor0": CIColor(red: color.red, green: color.green, blue: color.blue, alpha: marksLineOpacity),
            "inputColor1": CIColor.clear, "inputWidth": marksDash * unit, "inputSharpness": 1
        ])?.outputImage ?? .empty()
        let (across, down) = (dashes, dashes.transformed(by: CGAffineTransform(rotationAngle: .pi / 2)))
        let square = CIImage(color: CIColor(red: color.red, green: color.green, blue: color.blue))
        let (left, right) = ((minX * scale - clearance).rounded(), (maxX * scale + clearance).rounded())
        let (bottom, top) = (((plan.canvas.height - maxY) * scale - clearance).rounded(), ((plan.canvas.height - minY) * scale + clearance).rounded())
        var image = CIImage.empty()
        for row in [bottom, top] {
            image = across.cropped(to: CGRect(x: 0, y: row - line / 2, width: frame.width, height: line)).composited(over: image)
        }
        for column in [left, right] {
            image = down.cropped(to: CGRect(x: column - line / 2, y: 0, width: line, height: frame.height)).composited(over: image)
        }
        for column in [left, right] {
            for row in [bottom, top] {
                image = square.cropped(to: CGRect(x: column - side / 2, y: row - side / 2, width: side, height: side)).composited(over: image)
            }
        }
        return image.cropped(to: frame)
    }

    /// Measured at 1080p: the squares 12 px as a box opened, 8–9 once open; the hairlines 1–2 px, dotted every 6 px, about a
    /// fifth of the way from the ground to black; the dots 41–46 px outside the tile they framed.
    static let marksSquare = 10.0
    static let marksLine = 1.5
    static let marksDash = 3.0
    static let marksLineOpacity = 0.3
    static let marksClearance = 42.0

    /// A text eaten by two bars from its ends to its middle (spec 0018), in its image's pixels: what's between the bars, and the
    /// bars, at whole pixels; before it starts, the text as it is. Drawn in the room its bars start in, as letters are.
    static func eaten(_ content: CIImage, of layer: MotionPlan.Layer, by eat: MotionPlan.Eat, at time: Double) -> CIImage {
        let (scale, size, room) = (layer.rasterScale, layer.size, layer.revealRoom)
        let extent = CGRect(x: -room.width, y: -room.height, width: size.width + room.width * 2, height: size.height + room.height * 2)
            .applying(CGAffineTransform(scaleX: scale, y: scale))
        let clear = CIImage(color: .clear).cropped(to: extent)
        guard time >= eat.start, let line = layer.parts.map(\.height).max() else { return content.composited(over: clear) }
        let progress = MoveExpansion.eatEasing.progress((time - eat.start) / eat.duration, duration: eat.duration)
        // The left bar's inner edge, from a gap outside the text's start to its middle; the right bar's mirrors it
        let gap = line * MoveExpansion.eatGap
        let edge = ((-gap + progress * (size.width / 2 + gap)) * scale).rounded()
        let bar = CGSize(width: (line * MoveExpansion.eatBar.width * scale).rounded(), height: (line * MoveExpansion.eatBar.height * scale).rounded())
        let (right, bottom) = (size.width * scale - edge, ((size.height * scale - bar.height) / 2).rounded())
        let ink = CIImage(color: CIColor(red: eat.color.red, green: eat.color.green, blue: eat.color.blue, alpha: eat.color.alpha))
        let between = content.cropped(to: CGRect(x: edge, y: extent.minY, width: max(right - edge, 0), height: extent.height))
        return ink.cropped(to: CGRect(x: edge - bar.width, y: bottom, width: bar.width, height: bar.height))
            .composited(over: ink.cropped(to: CGRect(x: right, y: bottom, width: bar.width, height: bar.height)))
            .composited(over: between).composited(over: clear).cropped(to: extent)
    }
}
