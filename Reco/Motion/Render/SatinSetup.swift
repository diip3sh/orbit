//
//  SatinSetup.swift
//  Reco
//

import CoreGraphics

/// How the satin is lit for one shot: where its folds lie, where the light pools, the slab of matte
/// glass a wide shot sees over it, and how the light falls on UI on glass. The setups are the four
/// shots of the film the user approved (spec 0012, L0), whose stills were tuned against New Raycast's
/// frames at 2.0 s and 5.0 s; a video's scenes over satin take them in turn, so each shot is lit
/// afresh, as a film's are.
///
/// Positions on the cloth are in shorter sides of the frame from its top-left corner, y down.
nonisolated struct SatinSetup: Sendable {

    /// A ridge in the cloth that starts and ends: a crest through `center` at `angle` degrees (y
    /// down), fading out a Gaussian `length` along it either side, `near` wide on the light's side
    /// and `far` on the other, curving away from the light by `bend` per shorter side squared.
    nonisolated struct Fold: Sendable {
        var center: CGPoint
        var angle: Double
        var length: Double
        var near: Double
        var far: Double
        var bend = 0.0
        var height: Double
    }

    /// Where the key light falls on the cloth: a Gaussian `radius` wide at `strength`.
    nonisolated struct Pool: Sendable {
        var center: CGPoint
        var radius: Double
        var strength: Double
    }

    /// A slab of matte glass lying in focus over the cloth. Its edge runs through `point` (fractions
    /// of the frame's width and height) at `angle` degrees, chamfered as Raycast's is: a dark groove
    /// `bevel` pixels in, the bevel's lit face just outside it, the face falling off over `falloff`
    /// pixels to the drop, and a shadow on the cloth beyond. Lengths are pixels at 1080p.
    nonisolated struct Slab: Sendable {
        var point: CGPoint
        var angle: Double

        /// Its face's grey, of 255, darkening by `tilt` every 400 pixels in from the edge.
        var level: Double
        var tilt: Double
        var bevel: Double

        /// How much the groove darkens and the bevel's face brightens the slab.
        var groove: Double
        var glint: Double
        var falloff: Double

        /// How much the shadow darkens the cloth at the edge, and how far it reaches.
        var shadow: Double
        var shadowWidth: Double

        /// The blur over the whole frame that keeps the edge from reading as drawn.
        var softness: Double
    }

    /// How the shot's light falls on a panel of dark glass (``GlassRenderer``), as measured on
    /// Raycast's search pill. Levels are of 255, lengths pixels at 1080p, points fractions of the frame.
    nonisolated struct Glass: Sendable {
        /// The rim, a band round the outline: its level, how much brighter where it faces left (the key
        /// is low on the left), how much of the ground under it shows, and a highlight on its inner edge
        /// where it faces left.
        var rimLevel = 41.0
        var rimLit: Double
        var rimSeen = 0.3
        var rimInner: Double

        /// A bright line along the rim's outer edge where it faces up, `glintDepth` deep, fading with
        /// distance from `glintSource` over `glintFall` frame widths.
        var glint: Double
        var glintDepth: Double
        var glintSource: CGPoint
        var glintFall: Double

        /// The body: the ground seen through it, `transmit` of its light blurred by `blur`, over a dark
        /// `base`.
        var base = 10.0
        var transmit = 0.45
        var blur = 40.0

        /// A soft pool of light in it: its centre, radius (frame heights) and level.
        var pool: CGPoint
        var poolRadius: Double
        var poolLevel: Double

        /// The key's reflection: a band through `sheen` at `sheenAngle` degrees, `sheenWidth` wide,
        /// `sheenLevel` bright at the panel's top and fading over `sheenFall` down it.
        var sheen: CGPoint
        var sheenAngle: Double
        var sheenWidth: Double
        var sheenLevel: Double
        var sheenFall: Double

        /// The shadow it casts on the ground: how dark, how soft, how far down.
        var shadow = 0.5
        var shadowBlur: Double
        var shadowDrop: Double
    }

    var folds: [Fold]
    var pools: [Pool]

    /// Towards the key light: x right, y down, z out of the screen.
    var light: SIMD3<Double>

    /// The crests' light, scaled down to the film's low key before it's encoded.
    var exposure: Double

    /// The depth of field's blur, in pixels at 1080p.
    var defocus: Double

    /// The height a fold is lit fully at; lower, its light falls off as this power.
    var crest: Double
    var occlusion: Double

    /// How far the folds slide each second, in shorter sides.
    var drift: CGVector

    /// How fast the folds' lines wander, and how much the pools swell and shrink, as a share of
    /// their radius.
    var undulation: Double
    var breathing: Double

    /// Where the setup's clock stands as its shot begins: the film's time it was tuned at.
    var clock: Double

    var slab: Slab?

    var glass: Glass

    /// The kernel takes this many folds and pools; a setup with fewer has the rest flat or dark.
    static let mostFolds = 5
    static let mostPools = 4

    /// The film's shots in order: the search bar in macro, the wider shot with the slab, the
    /// results, the page they open.
    static let film = [macro, wide, results, page]

    /// The setup the `index`-th of a video's scenes over satin is lit by.
    static func forShot(_ index: Int) -> SatinSetup {
        film[index % film.count]
    }

    /// Folds across the frame from the upper left, the key pooling in the top-left corner and a
    /// second light far to the right, the middle left dark for the UI (still A, against Raycast's
    /// 2.0 s).
    static let macro = SatinSetup(
        folds: [
            Fold(center: CGPoint(x: 0.15, y: 0.13), angle: -24, length: 0.9, near: 0.11, far: 0.06, bend: 0.08, height: 0.06),
            Fold(center: CGPoint(x: 0.42, y: 0.38), angle: -20, length: 0.9, near: 0.1, far: 0.06, bend: 0.06, height: 0.03),
            Fold(center: CGPoint(x: 0.25, y: 0.62), angle: -14, length: 0.8, near: 0.08, far: 0.05, bend: 0.06, height: 0.025),
            Fold(center: CGPoint(x: 0.6, y: 1.02), angle: -6, length: 1.4, near: 0.25, far: 0.12, height: 0.05),
            Fold(center: CGPoint(x: 1.68, y: 0.12), angle: -25, length: 0.6, near: 0.22, far: 0.12, height: 0.06)
        ],
        pools: [
            Pool(center: CGPoint(x: 0, y: 0), radius: 0.42, strength: 1),
            Pool(center: CGPoint(x: 1.85, y: 0), radius: 0.55, strength: 0.6),
            Pool(center: CGPoint(x: 0.6, y: 1.1), radius: 1, strength: 0.2)
        ],
        light: [-0.5, -0.6, 0.62], exposure: 0.09, defocus: 8, crest: 0.06, occlusion: 1.6,
        drift: CGVector(dx: -0.012, dy: 0.004), undulation: 0.35, breathing: 0.06, clock: 0,
        glass: Glass(
            rimLit: 38, rimInner: 40, glint: 145, glintDepth: 3, glintSource: CGPoint(x: 0.44, y: 0), glintFall: 0.5,
            pool: CGPoint(x: 0.7, y: 0.62), poolRadius: 0.35, poolLevel: 16,
            sheen: CGPoint(x: 0.78, y: 0.24), sheenAngle: 112, sheenWidth: 180, sheenLevel: 26, sheenFall: 500, shadowBlur: 40, shadowDrop: 30
        )
    )

    /// A bent fold lit from above on the right, the slab across the lower left (still B, against
    /// Raycast's 5.0 s).
    static let wide = SatinSetup(
        folds: wideFolds,
        pools: [
            Pool(center: CGPoint(x: 1.1, y: 0.34), radius: 0.5, strength: 0.8),
            Pool(center: CGPoint(x: 1.75, y: 0), radius: 0.3, strength: 0.5),
            Pool(center: CGPoint(x: 0.4, y: 0.12), radius: 0.35, strength: 0.7),
            Pool(center: CGPoint(x: 0, y: 1.08), radius: 0.38, strength: 0.35)
        ],
        light: [-0.3, -0.7, 0.65], exposure: 0.2, defocus: 9, crest: 0.07, occlusion: 1.4,
        drift: CGVector(dx: -0.010, dy: 0.006), undulation: 0.3, breathing: 0.05, clock: 3.2,
        slab: Slab(
            point: CGPoint(x: 0, y: 0.423), angle: -43.5, level: 160, tilt: 8, bevel: 13, groove: 0.36, glint: 0.08, falloff: 7,
            shadow: 0.6, shadowWidth: 25, softness: 1
        ),
        glass: wideGlass
    )

    /// The wide shot's folds under the macro's light, pooling in two corners.
    static let results = SatinSetup(
        folds: wideFolds,
        pools: [Pool(center: CGPoint(x: 0.2, y: 0), radius: 0.5, strength: 0.8), Pool(center: CGPoint(x: 0, y: 1), radius: 0.5, strength: 0.5)],
        light: macro.light, exposure: macro.exposure, defocus: macro.defocus, crest: macro.crest, occlusion: macro.occlusion,
        drift: macro.drift, undulation: macro.undulation, breathing: macro.breathing, clock: 14.6,
        glass: relit(wideGlass) {
            $0.glintSource = CGPoint(x: 0.1, y: 0)
            ($0.sheen, $0.sheenAngle, $0.sheenWidth, $0.sheenLevel, $0.sheenFall) = (CGPoint(x: 0.35, y: 0.3), 125, 260, 30, 700)
            ($0.pool, $0.poolRadius, $0.poolLevel) = (CGPoint(x: 0.45, y: 0.55), 0.4, 10)
        }
    )

    /// The macro's folds, its key pooled wider and the right-hand light brighter.
    static let page = SatinSetup(
        folds: macro.folds,
        pools: [
            Pool(center: CGPoint(x: 0, y: 0), radius: 0.5, strength: 1),
            Pool(center: CGPoint(x: 1.85, y: 0.05), radius: 0.45, strength: 0.7),
            Pool(center: CGPoint(x: 0.6, y: 1.1), radius: 1, strength: 0.25)
        ],
        light: macro.light, exposure: macro.exposure, defocus: macro.defocus, crest: macro.crest, occlusion: macro.occlusion,
        drift: macro.drift, undulation: macro.undulation, breathing: macro.breathing, clock: 13.2,
        glass: relit(wideGlass) {
            $0.glintSource = CGPoint(x: 0.3, y: 0)
            ($0.sheen, $0.sheenAngle, $0.sheenWidth, $0.sheenLevel, $0.sheenFall) = (CGPoint(x: 0.5, y: 0.3), 120, 240, 30, 500)
        }
    )

    /// Glass in the wide shot (still B): a fainter rim, its light from the upper right.
    private static let wideGlass = Glass(
        rimLit: 12, rimInner: 0, glint: 100, glintDepth: 2, glintSource: CGPoint(x: 0.6, y: 0), glintFall: 0.6,
        pool: CGPoint(x: 0.4, y: 0.45), poolRadius: 0.3, poolLevel: 6,
        sheen: CGPoint(x: 0.52, y: 0.39), sheenAngle: 132, sheenWidth: 200, sheenLevel: 38, sheenFall: 420, shadowBlur: 30, shadowDrop: 20
    )

    /// `glass` changed by `change`: the film relit the wide shot's glass for its closer shots.
    private static func relit(_ glass: Glass, _ change: (inout Glass) -> Void) -> Glass {
        var glass = glass
        change(&glass)
        return glass
    }

    private static let wideFolds = [
        Fold(center: CGPoint(x: 1.3, y: 0.16), angle: -11, length: 0.7, near: 0.2, far: 0.05, bend: 0.35, height: 0.07),
        Fold(center: CGPoint(x: 1.65, y: -0.02), angle: -25, length: 0.4, near: 0.12, far: 0.08, height: 0.05),
        Fold(center: CGPoint(x: 0.32, y: 0.25), angle: -44, length: 0.45, near: 0.08, far: 0.06, height: 0.05),
        Fold(center: CGPoint(x: 0.08, y: 0.95), angle: -30, length: 0.5, near: 0.15, far: 0.09, bend: 0.2, height: 0.045),
        Fold(center: CGPoint(x: 0.12, y: 0.7), angle: -35, length: 0.4, near: 0.12, far: 0.07, height: 0.025)
    ]
}
