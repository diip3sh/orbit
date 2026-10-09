//
//  MotionFrameRenderer+Story.swift
//  Reco
//

import CoreImage

/// Story films' parts of a frame (spec 0015), after Lovable's chat launch: new words in the brand's gradient behind a thin
/// caret, the gradient running through a layer (a shimmer) or sweeping across one and its group (a wash).
nonisolated extension MotionFrameRenderer {

    // MARK: - New words

    /// A voice or reply's newest parts in the gradient, laid across the run of them still in it and each turning to the
    /// text's colour over ``TextReveal/tintLength``; a voice's thin caret after the newest letter, from ``kineticCaretLead``
    /// before the first to ``kineticCaretHold`` after the last.
    static func voiced(_ shown: CIImage, image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        guard layer.gradient.count >= 2 else { return shown }
        let (parts, pixels) = (layer.parts, { (rect: CGRect) in revealPixels(of: rect, in: layer) })
        var shown = shown
        let typed = parts.indices.filter { reveal.fraction(ofPart: $0, at: time) > 0 }
        let young = typed.filter { time - reveal.start(ofPart: $0) < TextReveal.tintLength }
        if let first = young.first, let last = young.last {
            // One gradient across the run, its last colour at the newest part's end
            let run = pixels(parts[first]).union(pixels(parts[last]))
            let sheet = gradient(layer.gradient, from: run.minX, to: max(run.maxX, run.minX + 1), over: image.extent)
            for index in young {
                let age = (time - reveal.start(ofPart: index)) / TextReveal.tintLength
                let piece = image.cropped(to: pixels(parts[index]))
                let tinted = sheet.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: piece])
                shown = tinted.fading(to: 1 - age * age).composited(over: shown)
            }
        }
        guard reveal.style == .voice else { return shown }
        let end = reveal.end(parts: parts.count) + kineticCaretHold
        guard reveal.start - kineticCaretLead <= time, time < end + 0.1, let box = typed.last.map({ parts[$0] }) ?? parts.first else { return shown }
        // A thin bar after the newest letter, a little taller than the letters (Lovable's: 4 % of its line wide)
        let line = box.height
        let caret = CGRect(x: (typed.isEmpty ? box.minX : box.maxX) + line * 0.06, y: box.minY + line * 0.04, width: line * voiceCaretWidth, height: line * 0.92)
        let bar = CIImage(color: ciColor(color(of: layer.gradient, at: voiceCaretShare))).cropped(to: pixels(caret))
        return (time > end ? bar.fading(to: 1 - (time - end) / 0.1) : bar).composited(over: shown)
    }

    /// A voice's caret: its width in lines, and where along the gradient its colour is (Lovable's pink-red).
    static let voiceCaretWidth = 0.045
    static let voiceCaretShare = 0.75

    // MARK: - Shimmer and wash

    /// The layer's own pixels with a shimmer running through them as their colour, if one is on at `time`: the gradient
    /// mirrored and repeated every ``shimmerPeriod`` of its width, sliding right a width every ``shimmerCrossing`` s, in over
    /// 0.15 s and out over 0.3 s before it ends (unless it runs to the scene's end).
    static func shimmered(_ content: CIImage, layer: MotionPlan.Layer, at time: Double, sceneDuration: Double) -> CIImage {
        guard layer.gradient.count >= 2, let tint = layer.tints.first(where: { $0.kind == .shimmer && $0.start <= time && time < $0.start + $0.duration }) else {
            return content
        }
        let extent = content.extent
        guard extent.width > 0, !extent.isInfinite else { return content }
        let since = time - tint.start
        let toEnd = tint.start + tint.duration >= sceneDuration - 1e-3 ? .infinity : tint.start + tint.duration - time
        let strength = min(since / 0.15, toEnd / 0.3, 1)
        // Warm to cool across it at first, sliding right a width every crossing: Lovable's "Chat" went from an orange C to
        // a blue one in about half a second
        let mirrored = layer.gradient + layer.gradient.dropLast().reversed()
        let period = extent.width * shimmerPeriod
        let offset = (since / shimmerCrossing * extent.width).truncatingRemainder(dividingBy: period)
        let sheet = repeating(mirrored, period: period, offset: extent.minX - extent.width + offset, over: extent)
        let tinted = sheet.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: content])
        return strength < 1 ? tinted.fading(to: max(strength, 0)).composited(over: content) : tinted
    }

    static let shimmerPeriod = 2.0
    static let shimmerCrossing = 0.5

    /// `drawn` (a layer in output pixels) with the washes on at `time` over it: a band of the gradient a little wider than
    /// what it washes, its warm end leading, sweeping in from the right over ``washSweep`` of its length and screened over
    /// the layer's pixels, then gone over its last third. `bounds` is what each wash spans, in output pixels.
    static func washed(_ drawn: CIImage, layer: MotionPlan.Layer, at time: Double, bounds: (Int) -> CGRect?) -> CIImage {
        layer.tints.filter { $0.kind == .wash && $0.start <= time && time < $0.start + $0.duration }.reduce(drawn) { image, tint in
            guard layer.gradient.count >= 2, let area = bounds(tint.over), area.width > 0 else { return image }
            let progress = (time - tint.start) / tint.duration
            let sweep = MotionEasing.enter.progress(min(progress / washSweep, 1), duration: 1)
            let fade = min(max((1 - progress) / (1 - washHold), 0), 1)
            // The band's leading (warm) edge from the right edge to past the left, the band 1.2 widths long
            let band = area.width * 1.2
            let leading = area.maxX - sweep * (area.width + 0.2 * area.width)
            // Its cool end to its pink: Lovable's box went blue, violet and pink, never orange
            let colors = stride(from: 0, through: washReach, by: washReach / 4).map { color(of: layer.gradient, at: $0) }
            let sheet = gradient(colors, from: leading + band, to: leading, over: area.insetBy(dx: -band, dy: 0))
            let soft = CIImage(color: .white).cropped(to: CGRect(x: leading, y: area.minY, width: band, height: area.height))
                .applyingFilter("CIMaskToAlpha").applyingGaussianBlur(sigma: area.width * 0.06).cropped(to: area)
            let light = sheet.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: soft]).fading(to: washStrength * fade)
            let screened = light.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
            return screened.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: image]).composited(over: image)
        }
    }

    /// How much of a wash's length its sweep takes, when it starts to go (Lovable's: across in 0.5 s, covered to 0.8 s,
    /// gone by 1.2), and how strongly it's screened.
    static let washSweep = 0.45
    static let washHold = 0.66
    static let washStrength = 0.9

    /// How far along the gradient a wash's colours run.
    static let washReach = 0.55

    // MARK: - Gradients

    /// `colors` from `start` to `end` across x, held past either end, over `extent`: a row of ``rampPixels`` stretched
    /// across, as gradients cropped side by side left a hairline at each seam.
    static func gradient(_ colors: [RGBAColor], from start: Double, to end: Double, over extent: CGRect) -> CIImage {
        let ramp = Self.ramp(start <= end ? colors : colors.reversed())
        let (low, span) = (min(start, end), max(abs(end - start), 1e-3))
        return ramp.clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: span / Double(rampPixels), y: 1).concatenating(CGAffineTransform(translationX: low, y: 0)))
            .cropped(to: extent)
    }

    /// `colors` repeated every `period` along x from `offset`, over `extent`: whole cycles side by side, each a pixel
    /// wider than its place, so no seam shows where they meet (a cycle ends on the colour the next starts on).
    private static func repeating(_ colors: [RGBAColor], period: Double, offset: Double, over extent: CGRect) -> CIImage {
        var sheet = CIImage.empty()
        var start = offset - period
        while start < extent.maxX {
            let cell = CGRect(x: start - 1, y: extent.minY, width: period + 2, height: extent.height).intersection(extent)
            if !cell.isEmpty {
                sheet = gradient(colors, from: start, to: start + period, over: cell).composited(over: sheet)
            }
            start += period
        }
        return sheet.cropped(to: extent)
    }

    static let rampPixels = 256

    /// `colors` evenly along a row of ``rampPixels``, mixed as their encoded values, as Core Image's gradients mix them.
    private static func ramp(_ colors: [RGBAColor]) -> CIImage {
        var pixels = [Float](repeating: 1, count: rampPixels * 4)
        for index in 0..<rampPixels {
            let color = color(of: colors, at: Double(index) / Double(rampPixels - 1))
            pixels[index * 4] = Float(color.red)
            pixels[index * 4 + 1] = Float(color.green)
            pixels[index * 4 + 2] = Float(color.blue)
            pixels[index * 4 + 3] = Float(color.alpha)
        }
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        // A row: clamped, it repeats up and down the frame. Scaled tall first, its region of interest rounded to nothing
        return CIImage(bitmapData: data, bytesPerRow: rampPixels * 16, size: CGSize(width: rampPixels, height: 1), format: .RGBAf, colorSpace: nil)
    }

    /// The colour `share` of the way along `colors`.
    static func color(of colors: [RGBAColor], at share: Double) -> RGBAColor {
        let position = min(max(share, 0), 1) * Double(colors.count - 1)
        let (lower, upper) = (Int(position.rounded(.down)), min(Int(position.rounded(.down)) + 1, colors.count - 1))
        let mix = position - Double(lower)
        let (below, above) = (colors[lower], colors[upper])
        return RGBAColor(
            red: below.red + (above.red - below.red) * mix, green: below.green + (above.green - below.green) * mix,
            blue: below.blue + (above.blue - below.blue) * mix, alpha: below.alpha + (above.alpha - below.alpha) * mix
        )
    }

    private static func ciColor(_ color: RGBAColor) -> CIColor {
        CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
