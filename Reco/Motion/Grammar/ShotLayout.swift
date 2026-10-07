//
//  ShotLayout.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Lays a shot out into layers with moves and a camera, by the layout rules and the document's
/// style (spec 0011, *Grammar*). Deterministic: variety comes from the brand (face, alignment) and
/// the pacing, never chance.
nonisolated enum ShotLayout {

    /// What a shot puts in its scene.
    nonisolated struct Layout: Equatable, Sendable {
        var layers: [MotionLayer] = []
        var camera = MotionCamera()
    }

    /// Everything a shot is laid out from besides its slots.
    nonisolated struct Context: Sendable {
        let scene: MotionScene

        /// The scene's place in the video: drifts alternate direction from one to the next.
        let index: Int

        let canvas: MotionCanvas
        let style: StyleTokens

        /// The UI assets' sizes in CSS pixels, for those already lifted or measured.
        let sizes: [String: CGSize]

        var size: CGSize {
            canvas.size
        }
    }

    static func layout(_ shot: MotionShot, in context: Context) -> Layout {
        var layout = switch shot.kind {
        case .hook: hook(shot, in: context)
        case .title: title(shot, in: context)
        case .uiHero: uiHero(shot, in: context)
        case .uiFocus: uiFocus(shot, in: context)
        case .uiCascade: uiCascade(shot, in: context)
        case .featureSequence: featureSequence(shot, in: context)
        case .endCard: endCard(shot, in: context)
        case .closing: closing(shot, in: context)
        }
        // Drift and cut: every shot drifts, the cuts hiding its start and stop; but the ending, and a
        // feature sequence, whose captions hold still while its UI moves
        if context.canvas.pacing == .driftAndCut, !shot.kind.isEnding, shot.kind != .featureSequence {
            var drift = MotionMove(.drift)
            drift.direction = context.index.isMultiple(of: 2) ? .right : .left
            layout.camera.moves.insert(drift, at: 0)
        }
        return layout
    }

    // MARK: - Type

    /// How the brand's face reveals a headline: a sans wipes in blurred (Linear), a serif rises line
    /// by line, a mono is typed.
    static func headlineMove(for face: TextContent.Face) -> MotionMove.Kind {
        switch face {
        case .sans: .blurWipe
        case .serif: .lineMask
        case .mono: .type
        }
    }

    static func text(_ string: String, size: Double, color: RGBAColor, width: Double?, style: StyleTokens, alignment: TextContent.Alignment? = nil) -> TextContent {
        var content = TextContent(text: string)
        content.face = style.face
        // A serif headline reads best light; a sans one firm
        content.weight = style.face == .serif ? .regular : .semibold
        content.size = size
        content.color = color
        content.alignment = alignment ?? style.alignment
        content.width = width
        return content
    }

    /// A text layer placed by its alignment: its left edge at the margin, or centred, at `middle` (its
    /// vertical centre).
    static func textLayer(_ id: String, _ content: TextContent, middle: Double, in context: Context, moves: [MotionMove]) -> MotionLayer {
        let centred = content.alignment == .center
        let left = centred ? context.size.width / 2 : LayoutRules.margin(of: context.size)
        var transform = Transform3D(position: [left, middle, 0])
        transform.anchor = CGPoint(x: centred ? 0.5 : 0, y: 0.5)
        return MotionLayer(id: id, content: .text(content), transform: transform, moves: moves)
    }

    /// The widest a line of type may be.
    static func textWidth(in context: Context) -> Double {
        context.size.width - 2 * LayoutRules.margin(of: context.size)
    }

    /// A UI layer `width` canvas pixels wide, centred on `center`.
    static func uiLayer(_ id: String, asset: String, width: Double, at center: SIMD3<Double>, moves: [MotionMove] = []) -> MotionLayer {
        MotionLayer(id: id, content: .lifted(UIContent(asset: asset, width: width)), transform: Transform3D(position: center), moves: moves)
    }

    /// A UI asset's height at `width`, 16:10 until it's lifted.
    static func height(of asset: String, width: Double, in context: Context) -> Double {
        let size = context.sizes[asset]
        return width * (size.map { $0.height / max($0.width, 1) } ?? 0.625)
    }

    // MARK: - Shots

    /// At most six words over the product, dimmed and out of focus behind them.
    private static func hook(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        var layout = Layout()
        if let asset = shot.asset {
            var product = uiLayer("\(context.scene.id).product", asset: asset, width: size.width * 1.15, at: [size.width / 2, size.height / 2, 0])
            // Linear's dark UI at 0.3 and 6 px read as a black frame
            product.opacity = 0.45
            product.blur = 4 * size.height / 1080
            layout.layers.append(product)
        }
        let content = text(shot.text ?? "", size: size.height * 0.11, color: context.style.text, width: textWidth(in: context), style: context.style, alignment: .center)
        layout.layers.append(textLayer("\(context.scene.id).text", content, middle: size.height / 2, in: context, moves: [MotionMove(.blurIn)]))
        if context.canvas.pacing == .beats {
            layout.camera.moves.append(MotionMove(.push, start: 0, duration: context.scene.duration))
        }
        return layout
    }

    /// A headline revealed as the brand's face does, its last word rolling through the items' text
    /// (Linear for Agents), and a line under it 0.9 s later (Notion: 0.83–1.0 s).
    private static func title(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let headline = text(shot.text ?? "", size: LayoutRules.headlineSize(of: size), color: context.style.text, width: textWidth(in: context), style: context.style)
        let headlineHeight = TextImage(headline, scale: 0).size.height
        var moves = [MotionMove(headlineMove(for: context.style.face))]
        if case let words = (shot.items ?? []).compactMap(\.text), !words.isEmpty {
            var roll = MotionMove(.roll)
            roll.words = words
            moves.append(roll)
        }
        var layout = Layout()
        guard let line = shot.detail, !line.isEmpty else {
            layout.layers.append(textLayer("\(context.scene.id).headline", headline, middle: size.height / 2, in: context, moves: moves))
            return layout
        }
        let detail = text(line, size: LayoutRules.detailSize(of: size), color: context.style.dim, width: textWidth(in: context), style: context.style)
        let detailHeight = TextImage(detail, scale: 0).size.height
        let gap = size.height * 0.03
        let top = (size.height - headlineHeight - gap - detailHeight) / 2
        layout.layers.append(textLayer("\(context.scene.id).headline", headline, middle: top + headlineHeight / 2, in: context, moves: moves))
        layout.layers.append(textLayer(
            "\(context.scene.id).detail", detail, middle: top + headlineHeight + gap + detailHeight / 2, in: context,
            moves: [MotionMove(.fadeUp, start: MoveExpansion.entranceStart + 0.9)]
        ))
        return layout
    }

    /// The product flat and as large as the frame allows, arriving at once and settling as the camera
    /// pulls back onto it. It used to lie back on a plane larger than the frame with a band in focus
    /// (spike C's Linear Agent shot); the user found the tilted, cut-off, half-blurred UI the weakest
    /// shot of a Linear film (2026-10-07).
    private static func uiHero(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let asset = shot.asset ?? ""
        let width = LayoutRules.fittedWidth(of: context.sizes[asset], in: CGSize(width: size.width * 0.88, height: size.height * 0.82))
        var element = uiLayer("\(context.scene.id).product", asset: asset, width: width, at: [size.width / 2, size.height / 2, 0], moves: [MotionMove(.rise)])
        element.shadow = LayerShadow(opacity: 0.5, radius: 40 * size.height / 1080, offset: 28 * size.height / 1080)
        var layout = Layout(layers: [element])
        if context.canvas.pacing == .beats {
            layout.camera.moves.append(MotionMove(.pullBack))
        }
        return layout
    }

    /// One element close and flat, rising in; with a region, the rest dims and the view frames it.
    private static func uiFocus(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let asset = shot.asset ?? ""
        let width = LayoutRules.fittedWidth(of: context.sizes[asset], in: CGSize(width: size.width * 0.8, height: size.height * 0.75))
        let height = height(of: asset, width: width, in: context)
        var element = uiLayer("\(context.scene.id).product", asset: asset, width: width, at: [size.width / 2, size.height / 2, 0], moves: [MotionMove(.rise)])
        element.shadow = LayerShadow(opacity: 0.45, radius: 30 * size.height / 1080, offset: 20 * size.height / 1080)
        var layout = Layout()
        guard let region = shot.region else {
            layout.layers.append(element)
            return layout
        }
        var focus = MotionMove(.focus, start: MoveExpansion.entranceStart + 0.7)
        focus.region = region
        element.moves.append(focus)
        layout.layers.append(element)

        // Framed to fill 80% of the view, 1.1–3×, as a web take's shown elements
        let target = CGPoint(x: size.width / 2 + (region.midX - 0.5) * width, y: size.height / 2 + (region.midY - 0.5) * height)
        let zoom = min(max(min(size.width * 0.8 / (region.width * width), size.height * 0.8 / (region.height * height)), 1.1), 3)
        if context.canvas.pacing == .beats {
            var pan = MotionMove(.pan, start: MoveExpansion.entranceStart + 0.7)
            pan.target = target
            pan.intensity = zoom
            layout.camera.moves.append(pan)
        } else {
            // The camera doesn't ease in drift and cut: the shot starts framed, the element leaning
            // as spike C's composer did (12°, −10°, −4°) so the drift shows its depth
            layout.layers[0].transform.rotation = [12, -10, -4]
            layout.camera.position = [target.x, target.y, CameraProjection.dolly(forZoom: zoom, canvas: size)]
        }
        return layout
    }

    /// Elements side by side or stacked, entering one after another: in a row when that shows them
    /// larger (tall panels), else in a column. Three 400×560 panels stacked came out 190 px wide.
    private static func uiCascade(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let assets = (shot.items ?? []).compactMap(\.asset)
        let gap = size.height * 0.025
        let spacing = gap * Double(max(assets.count - 1, 0))
        let ratios = assets.map { height(of: $0, width: 1, in: context) }
        // A column as wide as fits 80% of the height, at most 55% of the width; a row as tall as fits
        // 86% of the width, at most 70% of the height
        let columnWidth = min(size.width * 0.55, (size.height * 0.8 - spacing) / max(ratios.reduce(0, +), 1e-6))
        let rowHeight = min(size.height * 0.7, (size.width * 0.86 - spacing) / max(ratios.map { 1 / max($0, 1e-6) }.reduce(0, +), 1e-6))
        let columnArea = ratios.map { columnWidth * columnWidth * $0 }.reduce(0, +)
        let rowArea = ratios.map { rowHeight * rowHeight / max($0, 1e-6) }.reduce(0, +)
        let inRow = rowArea > columnArea
        let widths = ratios.map { inRow ? rowHeight / max($0, 1e-6) : columnWidth }
        let extent = inRow ? widths.reduce(0, +) + spacing : ratios.map { $0 * columnWidth }.reduce(0, +) + spacing
        var edge = -extent / 2
        var rows: [MotionLayer] = []
        for (index, (asset, width)) in zip(assets, widths).enumerated() {
            let along = inRow ? width : width * ratios[index]
            let center: SIMD3<Double> = inRow ? [edge + along / 2, 0, 0] : [0, edge + along / 2, 0]
            rows.append(uiLayer("\(context.scene.id).item\(index)", asset: asset, width: width, at: center))
            edge += along + gap
        }
        let group = MotionLayer(
            id: "\(context.scene.id).items", content: .group(rows), transform: Transform3D(position: [size.width / 2, size.height / 2, 0]),
            moves: [MotionMove(.cascade)]
        )
        return Layout(layers: [group])
    }

    /// Each item its own slice of the scene, one after another like pages turning: a small index
    /// and its line on the left, word by word, and its UI larger on the right, leaning into the
    /// frame, sliding in sharpening and out blurred to the left as the next comes in.
    private static func featureSequence(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let items = shot.items ?? []
        let slice = context.scene.duration / Double(max(items.count, 1))
        var layout = Layout()
        for (index, item) in items.enumerated() {
            // Each comes in as the one before leaves, so the frame is never bare between them: 0.6 s
            // of nothing between Linear's Pulse and Documents showed only the field
            let start = index == 0 ? MoveExpansion.entranceStart : Double(index) * slice - 0.2
            // Out 0.1 s apart in the order they came (index, line, the UI to the left), the UI's 0.3 s
            // exit ending as its slice does, so no more than two leave at once; the last stays
            let leaving = { (order: Int) -> [MotionMove] in
                guard index < items.count - 1 else { return [] }
                var exit = MotionMove(.exit, start: Double(index + 1) * slice - 0.3 - 0.1 * Double(2 - order), duration: 0.3)
                exit.direction = order == 2 ? .left : nil
                return [exit]
            }
            if item.text != nil {
                layout.layers += featureText(item, index: index, start: start, leaving: leaving, in: context)
            }
            if let asset = item.asset {
                let alone = item.text == nil
                let box = alone ? CGSize(width: size.width * 0.8, height: size.height * 0.75) : CGSize(width: size.width * 0.56, height: size.height * 0.7)
                let width = LayoutRules.fittedWidth(of: context.sizes[asset], in: box)
                var slide = MotionMove(.slideIn, start: start + (alone ? 0 : 0.15))
                slide.direction = .left
                var element = uiLayer(
                    "\(context.scene.id).ui\(index)", asset: asset, width: width, at: [alone ? size.width / 2 : size.width * 0.665, size.height / 2, 0],
                    moves: [slide] + leaving(2)
                )
                // Turned towards the caption, so the frame has depth (spike C's composer: 12°, −10°, −4°)
                element.transform.rotation = alone ? [0, 0, 0] : [6, -12, 0]
                element.shadow = LayerShadow(opacity: 0.5, radius: 40 * size.height / 1080, offset: 28 * size.height / 1080)
                layout.layers.append(element)
            }
        }
        return layout
    }

    /// A feature's index ("01") over its line, at the margin beside its UI or centred alone.
    private static func featureText(_ item: ShotItem, index: Int, start: Double, leaving: (Int) -> [MotionMove], in context: Context) -> [MotionLayer] {
        let size = context.size
        let (string, hasUI) = (item.text ?? "", item.asset != nil)
        let width = hasUI ? size.width * 0.3 : textWidth(in: context)
        let alignment: TextContent.Alignment? = hasUI ? .leading : nil
        let line = text(string, size: LayoutRules.featureSize(of: size), color: context.style.text, width: width, style: context.style, alignment: alignment)
        var number = text(
            (index + 1).formatted(.number.precision(.integerLength(2))), size: LayoutRules.detailSize(of: size), color: context.style.accent ?? context.style.dim,
            width: nil, style: context.style, alignment: alignment
        )
        number.face = .mono
        number.weight = .medium
        let lineHeight = TextImage(line, scale: 0).size.height
        let numberHeight = TextImage(number, scale: 0).size.height
        let gap = size.height * 0.02
        let top = (size.height - numberHeight - gap - lineHeight) / 2
        return [
            textLayer("\(context.scene.id).index\(index)", number, middle: top + numberHeight / 2, in: context,
                      moves: [MotionMove(.fadeUp, start: start)] + leaving(0)),
            textLayer("\(context.scene.id).text\(index)", line, middle: top + numberHeight + gap + lineHeight / 2, in: context,
                      moves: [MotionMove(.wordByWord, start: start + 0.1)] + leaving(1))
        ]
    }

    /// The logo, a headline and the address or call to action, coming in once and then still (the
    /// reference films hold it 1.9–4.5 s).
    private static func endCard(_ shot: MotionShot, in context: Context) -> Layout {
        let size = context.size
        let style = context.style
        var stack: [(height: Double, layer: (Double) -> MotionLayer)] = []
        // One after another, 0.15 s apart, from the grammar's first move
        let start = { (position: Int) in MoveExpansion.entranceStart + 0.15 * Double(position) }
        if let logo = shot.asset {
            let width = LayoutRules.fittedWidth(of: context.sizes[logo], in: CGSize(width: size.width * 0.4, height: size.height * 0.12))
            stack.append((height(of: logo, width: width, in: context), { middle in
                uiLayer("\(context.scene.id).logo", asset: logo, width: width, at: [size.width / 2, middle, 0], moves: [MotionMove(.blurIn, start: start(0))])
            }))
        }
        if let string = shot.text, !string.isEmpty {
            let position = stack.count
            // Without a logo, the name stands in for it at a headline's size
            let nameSize = shot.asset == nil ? LayoutRules.headlineSize(of: size) : size.height * 0.07
            let content = text(string, size: nameSize, color: style.text, width: textWidth(in: context), style: style, alignment: .center)
            stack.append((TextImage(content, scale: 0).size.height, { middle in
                textLayer("\(context.scene.id).headline", content, middle: middle, in: context, moves: [MotionMove(.fadeUp, start: start(position))])
            }))
        }
        if let line = shot.detail, !line.isEmpty {
            let position = stack.count
            let content = text(line, size: LayoutRules.detailSize(of: size), color: style.accent ?? style.dim, width: textWidth(in: context), style: style, alignment: .center)
            stack.append((TextImage(content, scale: 0).size.height, { middle in
                textLayer("\(context.scene.id).detail", content, middle: middle, in: context, moves: [MotionMove(.fadeUp, start: start(position))])
            }))
        }
        let gap = size.height * 0.035
        let total = stack.map(\.height).reduce(0, +) + gap * Double(max(stack.count - 1, 0))
        var top = (size.height - total) / 2
        var layout = Layout()
        for entry in stack {
            layout.layers.append(entry.layer(top + entry.height / 2))
            top += entry.height + gap
        }
        return layout
    }
}
