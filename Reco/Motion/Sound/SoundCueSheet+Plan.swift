//
//  SoundCueSheet+Plan.swift
//  Reco
//

import CoreGraphics

/// A plan's cue sheet, by ``SoundRules``: every time from the plan's own, each cue on the frame that shows
/// what it marks.
nonisolated extension SoundCueSheet {

    /// - Parameter document: The document the plan was built from, its shots laid out
    ///   (``DocumentExpansion/expanded(_:sizes:)``): a plan's layers are its flattened layers.
    static func make(plan: MotionPlan, document: MotionDocument) -> SoundCueSheet {
        var sheet = SoundCueSheet(length: Double(plan.frameCount) / Double(plan.frameRate))
        guard !document.sound.isSilent, !plan.scenes.isEmpty else { return sheet }
        let closing = ClosingCues(plan: plan, document: document)
        if let style = SoundRules.beat(document.sound.style) {
            sheet.scoreBeat(style, isHouse: document.sound.style == .house, plan: plan, document: document, closing: closing)
        } else {
            sheet.scoreAmbient(plan: plan, document: document, closing: closing)
        }
        sheet.chords = sheet.chords.filter { $0.start < sheet.length }
        return sheet.following(document.sound)
    }

    /// Spec 0013's score: a chord a shot, a hit as the first UI cuts in, Raycast's closing.
    private mutating func scoreAmbient(plan: MotionPlan, document: MotionDocument, closing: ClosingCues?) {
        let end = min(closing?.start ?? length, length)
        let whips = Self.cameraWhips(in: plan, until: end)
        var cues = SoundCueList(frameRate: plan.frameRate)
        // An opening arriving in the seam named on it has the seam's own landing
        let arrives = plan.scenes.first?.arrival != nil && document.scenes.first?.shot?.kind != .macro
        let opening = arrives ? nil : Self.firstUI(in: plan, document: document, before: end)
        if let opening {
            cues.opening(at: opening)
        }
        cues.cuts(of: plan, document: document, before: end, except: opening, soft: Self.isStory(document))
        cues.seams(of: plan, before: end)
        cues.typing(in: plan, document: document, before: end)
        cues.design(in: plan, document: document, before: end)
        cues.whips(whips)
        chords = Self.bodyChords(of: plan, whips: whips, until: end, closes: closing != nil)
        air = end > 0 ? Air(start: 0, end: end, level: SoundRules.airLevel) : nil
        if let closing {
            closing.add(to: &cues)
            chords += closing.chords(until: length)
            roomStop = closing.start
        }
        // Effects are refused inside a closing: a sound on a word read as noise at every level tried
        self.cues = cues.list.filter { $0.part == .score || $0.time < end }.sorted { $0.time < $1.time }
    }

    /// Spec 0015's: drums, bass and chords on a grid fitted to the cuts, in the parts the film's scenes lay out, the
    /// effects lower under them, mastered louder.
    private mutating func scoreBeat(_ style: BeatStyle, isHouse: Bool, plan: MotionPlan, document: MotionDocument, closing: ClosingCues?) {
        let shots = Self.shots(of: plan, document: document)
        // Drums from the first frame need a beat there
        let grid = BeatGrid.fitted(to: (style.intro.isEmpty ? [0] : []) + shots.dropFirst().map(\.start), tempo: style.tempo)
        let ending = closing.map { (start: $0.start, hit: $0.logo ?? $0.slide) }
        let form = isHouse ? BeatForm.house(shots, grid: grid, closing: ending) : BeatForm.groove(shots, grid: grid, closing: ending)
        let score = BeatScore(style: style, grid: grid, form: form)
        let end = min(closing?.start ?? length, length)
        var cues = SoundCueList(frameRate: plan.frameRate)
        cues.dropsKineticKeys = !isHouse
        cues.cuts(of: plan, document: document, before: end, except: nil)
        cues.seams(of: plan, before: end)
        cues.typing(in: plan, document: document, before: end)
        cues.design(in: plan, document: document, before: end)
        cues.whips(Self.cameraWhips(in: plan, until: end))
        let effects = cues.list.filter { $0.part == .effects && $0.time < end }.map { cue in
            var cue = cue
            cue.level += SoundRules.effectsUnderBeat
            // A pop within 20 ms of a sixteenth lands on it
            if case .blip = cue.voice, abs(grid.nearestSixteenth(cue.time) - cue.time) <= SoundRules.popSnap {
                cue.time = grid.nearestSixteenth(cue.time)
            }
            return cue
        }
        chords = score.chords
        self.cues = (effects + score.cues).sorted { $0.time < $1.time }
        finish = SoundRules.beatFinish
    }

    /// Whether `document` is a story film (spec 0015): someone's words are typed big in it.
    static func isStory(_ document: MotionDocument) -> Bool {
        func voiced(_ layers: [MotionLayer]) -> Bool {
            layers.contains { layer in
                if case .group(let children) = layer.content, voiced(children) { return true }
                return layer.moves.contains { $0.kind == .voice }
            }
        }
        return document.scenes.contains { voiced($0.layers) }
    }

    /// The scenes as a beat's form reads them: words alone are text or a logo (an image, UI or still shape no bigger than
    /// ``SoundRules/logoShare`` of the canvas).
    static func shots(of plan: MotionPlan, document: MotionDocument) -> [BeatForm.Shot] {
        plan.scenes.enumerated().map { index, scene in
            let contents = document.scenes.indices.contains(index) ? MotionPlan.contents(of: document.scenes[index].layers) : []
            let fits = { (layer: MotionPlan.Layer, share: Double) in
                layer.size.width <= share * plan.canvas.width && layer.size.height <= share * plan.canvas.height
            }
            let shown = contents.contains { if case .group = $0 { false } else if case .shape = $0 { false } else { true } }
            let words = contents.count == scene.layers.count && shown
                && zip(contents, scene.layers).allSatisfy { content, layer in
                    switch content {
                    case .text, .group: true
                    case .image, .lifted: fits(layer, SoundRules.logoShare)
                    // A logo's mark is often a shape: the rebuilt Lovable lockup's heart was 70 px, a 13th of the frame's height
                    case .shape: layer.morph == nil && fits(layer, SoundRules.logoShare)
                    }
                }
            return BeatForm.Shot(start: scene.start, end: scene.start + scene.duration, isWords: words)
        }
    }

    /// The sheet with the document's switches and levels applied.
    func following(_ sound: MotionSound) -> SoundCueSheet {
        var sheet = self
        if sound.score {
            sheet.chords = chords.map { chord in
                var chord = chord
                chord.level += sound.scoreLevel
                return chord
            }
            sheet.air?.level += sound.scoreLevel
        } else {
            sheet.chords = []
            sheet.air = nil
        }
        sheet.cues = cues.filter { $0.part == .score ? sound.score : sound.effects }.map { cue in
            var cue = cue
            cue.level += cue.part == .score ? sound.scoreLevel : sound.effectsLevel
            return cue
        }
        if sheet.isSilent {
            sheet.roomStop = nil
        }
        return sheet
    }

    // MARK: - Events

    /// When the first UI shows: the frame its layer first appears on.
    static func firstUI(in plan: MotionPlan, document: MotionDocument, before end: Double) -> Double? {
        let rate = Double(plan.frameRate)
        for (index, scene) in plan.scenes.enumerated() where scene.start < end && document.scenes.indices.contains(index) {
            let contents = MotionPlan.contents(of: document.scenes[index].layers)
            let lifted = Set(contents.indices.filter { if case .lifted = contents[$0] { true } else { false } })
            guard !lifted.isEmpty else { continue }
            let frames = Int((scene.start * rate - 1e-6).rounded(.up))..<Int(((scene.start + scene.duration) * rate - 1e-6).rounded(.up))
            for frame in frames {
                let time = Double(frame) / rate
                if plan.placements(of: scene, at: time - scene.start).contains(where: { lifted.contains($0.layer) }) {
                    return time
                }
            }
        }
        return nil
    }

    /// A pan of the camera faster than ``SoundRules/whipSpeed``: from where it starts speeding up, through its
    /// fastest moment, to where it lands, in seconds into the video.
    nonisolated struct CameraWhip: Equatable, Sendable {
        var start: Double
        var peak: Double
        var landing: Double

        /// A whip seam: the cut is inside it.
        var crossesCut = false
    }

    /// How often the camera's speed is sampled to find whips.
    static let whipSampleRate = 240.0

    /// The camera's whips before `end`, from its speed across the frame: a whip move, a whip seam or a camera
    /// keyed by hand alike.
    static func cameraWhips(in plan: MotionPlan, until end: Double) -> [CameraWhip] {
        let speeds = (0..<Int(end * whipSampleRate)).map { lateralSpeed(of: plan, at: Double($0) / whipSampleRate) }
        var whips: [CameraWhip] = []
        var index = 0
        while index < speeds.count {
            guard speeds[index] > SoundRules.whipSpeed else {
                index += 1
                continue
            }
            var (first, peak, last) = (index, index, index)
            while last + 1 < speeds.count, speeds[last + 1] > SoundRules.whipSpeed {
                last += 1
                peak = speeds[last] > speeds[peak] ? last : peak
            }
            // Out to where it has all but stopped either side: a hundredth of its peak
            let still = speeds[peak] * SoundRules.whipStill
            while first > 0, speeds[first - 1] >= still { first -= 1 }
            while last + 1 < speeds.count, speeds[last] >= still { last += 1 }
            var whip = CameraWhip(start: Double(first) / whipSampleRate, peak: Double(peak) / whipSampleRate, landing: Double(last) / whipSampleRate)
            whip.crossesCut = plan.scenes.contains { $0.start > whip.start && $0.start < whip.landing }
            whips.append(whip)
            index = last + 1
        }
        return whips
    }

    /// How fast what the camera sees moves across the frame at `time`, in frame widths a second.
    private static func lateralSpeed(of plan: MotionPlan, at time: Double) -> Double {
        let (scene, local) = plan.scene(at: time)
        let step = 0.5 / whipSampleRate
        let (before, after) = (max(local - step, 0), min(local + step, scene.duration))
        guard after > before else { return 0 }
        let (earlier, later) = (plan.camera(of: scene, at: before), plan.camera(of: scene, at: after))
        let shift = hypot(later.lookAt.x - earlier.lookAt.x, later.lookAt.y - earlier.lookAt.y) * (earlier.magnification + later.magnification) / 2
        return shift / plan.canvas.width / (after - before)
    }
}
