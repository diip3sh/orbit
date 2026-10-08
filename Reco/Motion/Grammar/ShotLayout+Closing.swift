//
//  ShotLayout+Closing.swift
//  Reco
//

import CoreGraphics

/// New Raycast's closing as the film the user approved laid it out (spec 0012, after Raycast's last 9 s):
/// small mono caps on black, the name at 0.32 of the width and the product's words swapped beside it,
/// right-aligned at 0.68, a cut every 0.42 s; the last word held 0.74 s, then the two sliding together
/// over 1.4 s into one line, a dimmer line under it 0.3 s later, and 1.55 s after that the logo alone.
/// Draw it over a plain black field.
nonisolated extension ShotLayout {

    /// The caps' size: 2.5 % of the frame's height in cap height, SF Mono's being 0.7 of its size.
    static let closingCapHeight = 0.025

    /// When the first word cuts in, and how long each word shows before the next.
    static let closingSwaps = 0.25
    static let closingSwapInterval = 0.42

    /// When a closing's parts come, from its scene's start.
    nonisolated struct ClosingTimes {
        /// When each word cuts in.
        let words: [Double]

        /// The last word held 0.74 s, then the name and it sliding together over 1.4 s, the line under
        /// them 0.3 s later and the logo alone 1.55 s after that.
        let slide, settled, underline, logo: Double

        init(words count: Int) {
            words = (0..<count).map { closingSwaps + closingSwapInterval * Double($0) }
            slide = closingSwaps + closingSwapInterval * Double(max(count - 1, 0)) + 0.74
            settled = slide + 1.4
            underline = settled + 0.3
            logo = underline + 1.55
        }
    }

    /// The least a closing needs: everything in, and what's last on screen read for 1.2 s. Cut at 3 s,
    /// a Linear closing never came together.
    static func closingLength(words: Int, hasLogo: Bool) -> Double {
        let times = ClosingTimes(words: words)
        return (hasLogo ? times.logo : times.underline) + 1.2
    }

    static func closing(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let words = (shot.items ?? []).compactMap(\.text).filter { !$0.isEmpty }
        guard let name = shot.text, let last = words.last else { return Layout() }
        let style = context.style
        let caps = { (string: String, color: RGBAColor) in
            var content = text(string.uppercased(), size: closingCapHeight * size.height / 0.7, color: color, width: nil, style: style, alignment: .leading)
            (content.face, content.weight) = (.mono, .medium)
            return content
        }
        let middle = size.height / 2
        let (swaps, times) = (closingSwaps, ClosingTimes(words: words.count))
        let (slide, settled, underline, logo) = (times.slide, times.settled, times.underline, times.logo)
        let ending = shot.asset == nil ? Double.infinity : logo
        // The lockup: the name and the last word a space apart, centred
        let nameContent = caps(name, style.text)
        let lastContent = caps(last, style.text)
        let (nameWidth, lastWidth) = (TextImage(nameContent, scale: 0).size.width, TextImage(lastContent, scale: 0).size.width)
        let lockupLeft = (size.width - nameWidth - 0.6 * nameContent.size - lastWidth) / 2
        var layout = Layout()
        var nameLayer = anchored("\(context.scene.id).name", nameContent, at: [0.32 * size.width, middle, 0], anchor: 0, during: swaps..<ending)
        nameLayer.keyframes[.positionX] = slid(0.32 * size.width, onto: lockupLeft, over: slide...settled)
        layout.layers.append(nameLayer)
        for (index, word) in words.enumerated() {
            let isLast = index == words.count - 1
            let start = times.words[index]
            var layer = anchored(
                "\(context.scene.id).word\(index)", caps(word, style.text), at: [0.68 * size.width, middle, 0], anchor: 1,
                during: start..<(isLast ? ending : start + closingSwapInterval)
            )
            if isLast {
                layer.keyframes[.positionX] = slid(0.68 * size.width, onto: size.width - lockupLeft, over: slide...settled)
            }
            layout.layers.append(layer)
        }
        if let line = shot.detail, !line.isEmpty {
            // The film's second line was the words' colour at 0.55
            let dim = RGBAColor(red: style.text.red * 0.55, green: style.text.green * 0.55, blue: style.text.blue * 0.55, alpha: style.text.alpha)
            let content = caps(line, dim)
            let below = middle + 1.45 * TextImage(nameContent, scale: 0).size.height
            layout.layers.append(anchored("\(context.scene.id).detail", content, at: [size.width / 2, below, 0], anchor: 0.5, during: underline..<ending))
        }
        if let asset = shot.asset {
            // The wordmark 4.3 % of the frame's height, as the film's
            let height = 0.043 * size.height
            let ratio = context.sizes[asset].map { $0.width / max($0.height, 1) } ?? 5
            var layer = uiLayer("\(context.scene.id).logo", asset: asset, width: height * ratio, at: [size.width / 2, middle, 0])
            layer.keyframes[.opacity] = cut(logo..<Double.infinity)
            layout.layers.append(layer)
        }
        return layout
    }

    /// A line of caps with its anchor at `position`, `anchor` along its width (0 its left edge, 1 its
    /// right), shown `during` that time.
    private static func anchored(_ id: String, _ content: TextContent, at position: SIMD3<Double>, anchor: Double, during: Range<Double>) -> MotionLayer {
        var transform = Transform3D(position: position)
        transform.anchor = CGPoint(x: anchor, y: 0.5)
        var layer = MotionLayer(id: id, content: .text(content), transform: transform)
        layer.keyframes[.opacity] = cut(during)
        return layer
    }

    /// Opacity cut in and out at the ends of `shown`, no fade: Raycast's swaps are cuts.
    private static func cut(_ shown: Range<Double>) -> [Keyframe] {
        var keyframes = [Keyframe(time: 0, value: 0, easing: .hold), Keyframe(time: shown.lowerBound, value: 1, easing: .hold)]
        if shown.upperBound.isFinite {
            keyframes.append(Keyframe(time: shown.upperBound, value: 0, easing: .hold))
        }
        return keyframes
    }

    /// A slide from `start` onto `end` over `span`, settling as the film's lockup did.
    private static func slid(_ start: Double, onto end: Double, over span: ClosedRange<Double>) -> [Keyframe] {
        [Keyframe(time: span.lowerBound, value: start, easing: .cubicBezier(0.2, 0, 0, 1)), Keyframe(time: span.upperBound, value: end)]
    }
}
