//
//  LatticeSetup.swift
//  Reco
//

import Foundation

/// How the editorial film's lattice (``MotionField/paper``, ``MotionField/ink``) shows in one shot (spec 0017), measured on
/// ElevenLabs' launch film at 1080p (`~/Movies/Reco/references/elevenlabs-launch.mp4`). Each axis is read through a lens into
/// steps and the two staircases summed; the lines are where the sum is half way between whole numbers, so the rings are a
/// rounded square, a plus, then stepped diamonds. Settled, the film's rings crossed its middle column 111.5, 250.5, 377 and
/// 512 px from the middle: a step of 128 px past a middle magnified about 2.4×.
nonisolated struct LatticeSetup: Equatable, Sendable {

    /// How large the lattice shows once settled, against the film's end card (``step``).
    var scale: Double

    /// How large it shows as the shot opens, against ``scale``, and how long it holds there before settling.
    var from: Double
    var delay = 0.0

    /// How long it takes to settle, on the out-cubic easing.
    var settle: Double

    /// The shots' setups in turn, as the film's three: its opening zooming in as the wordmark opens (the middle ring 144 px
    /// across half its height at the cut, 205 px 1.5 s later); its dark beat settling from 1.54× in 1.2 s (1.27× after 0.3 s,
    /// 1.13× after 0.5 s); its end card holding at 1.53× while the mark sits, then settling in 0.9 s.
    static let shots = [
        LatticeSetup(scale: 1.84, from: 0.68, settle: 1.5),
        LatticeSetup(scale: 1, from: 1.54, settle: 1.2),
        LatticeSetup(scale: 1, from: 1.53, delay: 0.9, settle: 0.9)
    ]

    /// The setup for a scene's `index`th shot over `field`: ink is the film's dark beat.
    static func forShot(_ index: Int, of field: MotionField, isLast: Bool) -> LatticeSetup {
        isLast ? shots[2] : shots[(index + (field == .ink ? 1 : 0)) % 2]
    }

    /// How large the lattice shows `time` seconds into its shot, against ``step``.
    func zoom(at time: Double) -> Double {
        let progress = min(max((time - delay) / settle, 0), 1)
        return scale * (from + (1 - from) * MotionEasing.enter.progress(progress, duration: 1))
    }

    /// How fast its zoom's log changes `time` seconds into its shot, a second: the lines split into colours while it does.
    func zoomRate(at time: Double) -> Double {
        let step = 1.0 / 120
        return (log(zoom(at: time + step)) - log(zoom(at: time - step))) / (2 * step)
    }

    // MARK: - The film's lattice

    /// The step between rings and the lens: the middle's pixels pulled in by `reach` × tanh(r / `width`), so the middle shows
    /// magnified 1 / (1 − reach / width) and the rings past it a step apart (pixels at 1080p).
    static let step = 128.06
    static let lensReach = 67.3
    static let lensWidth = 101.6

    /// The share of a step each staircase takes to rise in the middle, and how much more each step out: its rings' corners
    /// in the middle, its outskirts' long diagonal waves. Fitted with the lens to the film's settled end card (its lines'
    /// mean distance from the model's 4.1 px at 960×540, against 6.5 for the best rise that didn't grow).
    static let rise = 0.642
    static let riseGrowth = 0.109

    /// The lines: a pixel wide at 1080p. On paper 21.5 % of the way to black (#f3f2f0 under #bebdbc: across a line the film's
    /// pixels sum to 45–53 levels down); on ink 17 % of the way to white (52–55 levels up across a line, as the dark beat settled).
    static let lineWidth = 1.0
    static let paperLine = 0.215
    static let inkLine = 0.17

    /// The lines' colour on `paper` for `field`: a share of the way to black on paper, to white on ink.
    static func line(on paper: RGBAColor, of field: MotionField) -> RGBAColor {
        let (toward, share) = field == .ink ? (1.0, inkLine) : (0.0, paperLine)
        let mix = { (value: Double) in value + (toward - value) * share }
        return RGBAColor(red: mix(paper.red), green: mix(paper.green), blue: mix(paper.blue), alpha: 1)
    }

    /// The film's paper and ink.
    static let paper = RGBAColor(red: 243.0 / 255, green: 242.0 / 255, blue: 240.0 / 255, alpha: 1)
    static let ink = RGBAColor(red: 10.0 / 255, green: 12.0 / 255, blue: 13.0 / 255, alpha: 1)

    /// How far the colour channels' zooms part per unit of the zoom's log a second: at the film's opening (about 0.3 a
    /// second) its outer lines had split into lilac, mint and yellow.
    static let aberration = 0.012
}
