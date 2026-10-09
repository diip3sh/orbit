//
//  BeatScoreTests.swift
//  RecoTests
//

import Accelerate
import Foundation
import Testing
@testable import Reco

/// Beat scores (spec 0015): a grid fitted to the cuts, a form read from the scenes (Lovable's intro, drop, break and
/// outro; the Spotify Jam's beat from the first frame with one dip), drums only where the form plays them, effects
/// lower and on the grid, mastered louder; ambient films as before.
struct BeatScoreTests {

    private let beat = 60 / 170.0

    /// Scenes of `beats` each at 170 BPM from 0, of the given kinds: `ui` (a box and its label), `big` (type alone),
    /// `type` (kinetic type alone) or `words` (an end word or the logo).
    private func document(_ scenes: [(beats: Double, kind: String)], style: MotionSound.Style) throws -> MotionDocument {
        let middle = ##""transform": {"position": [960, 540, 0]}"##
        let layers = scenes.enumerated().map { index, scene in
            switch scene.kind {
            case "ui":
                ##"[{"id": "box\##(index)", "content": {"shape": {"size": [900, 260], "cornerRadius": 40, "color": "#1b1b1f"}}, "##
                    + ##"\##(middle), "moves": [{"move": "pop", "start": 0.2}]}, "##
                    + ##"{"id": "t\##(index)", "content": {"text": {"text": "Make a moodboard", "size": 48}}, \##(middle)}]"##
            case "type":
                ##"[{"id": "k\##(index)", "content": {"text": {"text": "sauna hats", "size": 110}}, \##(middle), "##
                    + ##""moves": [{"move": "kinetic", "start": 0.1}]}]"##
            default: ##"[{"id": "w\##(index)", "content": {"text": {"text": "Ready to build?", "size": 120}}, \##(middle)}]"##
            }
        }
        let json = zip(scenes, layers).enumerated().map { index, pair in
            ##"{"id": "s\##(index)", "duration": \##(pair.0.beats * beat), "layers": \##(pair.1)}"##
        }
        let document = ##"{"version": 1, "canvas": {"size": [1920, 1080], "frameRate": 30, "field": "plain"}, "##
            + ##""sound": {"style": "\##(style.rawValue)"}, "scenes": [\##(json.joined(separator: ","))]}"##
        return try JSONDecoder().decode(MotionDocument.self, from: Data(document.utf8))
    }

    /// 40 s: a kinetic opening, UI, big type at about 70 %, two end words and the logo.
    private var story: [(beats: Double, kind: String)] {
        [(8, "type"), (8, "ui"), (6, "ui"), (8, "ui"), (8, "ui"), (6, "ui"), (8, "ui"), (8, "ui"), (8, "ui"), (8, "ui"), (10, "big"), (8, "ui"),
         (4, "words"), (4, "words"), (8, "words")]
    }

    private func isDrum(_ cue: SoundCue, _ drum: SoundCue.Drum) -> Bool {
        if case .drum(let played) = cue.voice { played == drum } else { false }
    }

    // MARK: - The grid

    @Test func fitsTheGridToTheCuts() {
        let sixteen = 60 / 168.0
        let cuts = [5, 9, 16, 22, 30, 37].map { 0.1 + Double($0) * sixteen }
        let grid = BeatGrid.fitted(to: cuts, tempo: 170)
        #expect(abs(grid.tempo - 168) < 0.06)
        #expect(cuts.allSatisfy { abs(grid.nearest($0) - $0) < 0.002 })
        // Without cuts, the style's tempo from the first frame
        #expect(BeatGrid.fitted(to: [], tempo: 125) == BeatGrid(beat: 0.48, phase: 0))
    }

    /// A cut or two fit many tempos: the style's own wins unless another lands them much closer.
    @Test func keepsTheStylesTempoBetweenEquals() {
        let grid = BeatGrid.fitted(to: [8 * beat, 20 * beat + 0.004], tempo: 170)
        #expect(abs(grid.tempo - 170) < 0.3)
    }

    // MARK: - The form

    private func shots(_ scenes: [(Double, Bool)]) -> [BeatForm.Shot] {
        var start = 0.0
        return scenes.map { beats, words in
            defer { start += beats * beat }
            return BeatForm.Shot(start: start, end: start + beats * beat, isWords: words)
        }
    }

    @Test func aGrooveDropsBreaksAndEndsOnTheLogo() {
        let grid = BeatGrid(beat: beat, phase: 0)
        // Cuts at 6, 14, …: the first at least 1.75 bars in is at 14 beats; big type at 70 %; two end words, the logo
        let scenes = shots([(6, false), (8, false), (8, false), (8, false), (8, false), (8, false), (10, true), (8, false), (4, true), (4, true),
                            (8, true)])
        let form = BeatForm.groove(scenes, grid: grid, closing: nil)
        let near = { (range: Range<Double>, start: Double, end: Double) in abs(range.lowerBound - start) < 1e-6 && abs(range.upperBound - end) < 1e-6 }
        #expect(abs(form.drop - 14 * beat) < 1e-6)
        #expect(form.breaks.count == 1 && near(form.breaks[0], scenes[6].start, scenes[6].end))
        #expect(form.outro == scenes[8].start && form.lastHit == scenes[10].start)
        // The drums play between them
        let segments = form.segments
        #expect(segments.count == 2 && near(segments[0], form.drop, scenes[6].start) && near(segments[1], scenes[6].end, scenes[8].start))
    }

    /// A film ending on a statement, a tagline and its end words: drums out for the last four bars at most, the statement
    /// a break before them (as Lovable's, out 3.7 bars before its end).
    @Test func anOutroIsFourBarsAtMost() {
        let grid = BeatGrid(beat: beat, phase: 0)
        let scenes = shots([(8, false), (8, false), (8, false), (8, false), (8, false), (4, true), (5, true), (2, true), (2, true), (8, true)])
        let form = BeatForm.groove(scenes, grid: grid, closing: nil)
        let end = scenes.last?.end ?? 0
        #expect(form.outro == scenes[7].start && end - (form.outro ?? end) <= 4 * grid.bar + 1e-6)
        #expect(form.breaks.count == 1 && abs(form.breaks[0].lowerBound - scenes[5].start) < 1e-6)
    }

    @Test func aDropPrefersACutOnABar() {
        let grid = BeatGrid(beat: beat, phase: 0)
        // Cuts at 7 and 12 beats: 12 is on a bar
        let form = BeatForm.groove(shots([(7, false), (5, false), (40, false)]), grid: grid, closing: nil)
        #expect(abs(form.drop - 12 * beat) < 1e-6)
        // A film under four bars plays its drums from the first beat
        #expect(BeatForm.groove(shots([(6, false), (6, false)]), grid: grid, closing: nil).drop == 0)
    }

    @Test func houseDipsForABeatBeforeTheMiddleCut() {
        let grid = BeatGrid(beat: 0.48, phase: 0)
        var start = 0.0
        let scenes = [(16, false), (16, false), (16, false), (16, false), (8, true)].map { beats, words in
            defer { start += Double(beats) * 0.48 }
            return BeatForm.Shot(start: start, end: start + Double(beats) * 0.48, isWords: words)
        }
        let form = BeatForm.house(scenes, grid: grid, closing: nil)
        #expect(form.drop == 0 && form.outro == nil)
        let middle = scenes[2].start
        #expect(form.breaks.count == 1 && abs(form.breaks[0].upperBound - middle) < 1e-9 && abs(form.breaks[0].lowerBound - (middle - 0.48)) < 1e-9)
        #expect(abs((form.lastHit ?? 0) - scenes[4].start) < 1e-9)
    }

    // MARK: - The cue sheet

    @Test func aGrooveScoresTheFilmsForm() async throws {
        let plan = await MotionPlan.build(try document(story, style: .groove), bundle: URL.temporaryDirectory)
        let sheet = plan.sound
        let shots = SoundCueSheet.shots(of: plan, document: try document(story, style: .groove))
        #expect(shots.map(\.isWords) == story.map { $0.kind != "ui" })
        #expect(sheet.finish == SoundRules.beatFinish && sheet.air == nil && sheet.roomStop == nil)

        let grid = BeatGrid.fitted(to: shots.dropFirst().map(\.start), tempo: 170)
        let form = BeatForm.groove(shots, grid: grid, closing: nil)
        let kicks = sheet.cues.filter { isDrum($0, .kick) }.map(\.time)
        let outro = try #require(form.outro)
        #expect(kicks.min() ?? 0 >= form.drop - 1e-6 && kicks.max() ?? .infinity < outro)
        #expect(!kicks.contains { time in form.breaks.contains { $0.contains(time) } })
        // Every kick on a sixteenth of the grid, not on a frame
        #expect(kicks.allSatisfy { abs(grid.nearestSixteenth($0) - $0) < 1e-6 })
        // A pad pumping in the body, held still in the intro
        #expect(sheet.chords.contains { $0.pump != nil } && sheet.chords.filter { $0.start < form.drop }.allSatisfy { $0.pump == nil })
        // The music carries the kinetic opening: no keys
        #expect(!sheet.cues.contains { $0.voice == .key(.letter) })
        // No glass hit as in the ambient score
        #expect(!sheet.cues.contains { if case .glass = $0.voice { $0.part == .score } else { false } })
    }

    @Test func effectsSitLowerUnderABeat() async throws {
        let ambient = await MotionPlan.build(try document(story, style: .ambient), bundle: URL.temporaryDirectory).sound
        let house = await MotionPlan.build(try document(story, style: .house), bundle: URL.temporaryDirectory).sound
        let swishes = { (sheet: SoundCueSheet) in sheet.cues.filter { $0.part == .effects && { if case .swish = $0 { true } else { false } }($0.voice) } }
        #expect(!swishes(ambient).isEmpty && swishes(house).map(\.level) == swishes(ambient).map { $0.level + SoundRules.effectsUnderBeat })
        // House keeps kinetic type's keys; its drums play from the first beat
        #expect(house.cues.contains { $0.voice == .key(.letter) })
        let kicks = house.cues.filter { isDrum($0, .houseKick) }.map(\.time)
        #expect((kicks.min() ?? 1) < 0.48)
    }

    @Test func aBeatIsFinishedLouderTheSameEveryTime() async throws {
        let plan = await MotionPlan.build(try document(Array(story.prefix(6)), style: .groove), bundle: URL.temporaryDirectory)
        let sound = ScoreRenderer.render(plan.sound)
        #expect(sound == ScoreRenderer.render(plan.sound))
        #expect(abs(Loudness.integrated(sound) - SoundRules.beatFinish.loudness) < 0.5)
        #expect(Loudness.truePeak(sound) <= SoundRules.beatFinish.ceiling + 0.05)
    }

    /// Chords, claps and open hats are wide (two takes, the second as the side), the middle whole; hats sit to either side;
    /// a groove's intro has no synthesized voice.
    @Test func aGrooveIsWideWithoutAVoice() async throws {
        var random = SeededRandom(seed: 1)
        for voice in [SoundCue.Voice.keys(notes: [54, 58, 61, 64], length: 1), .stab(notes: [54, 58, 61], length: 0.3), .drum(.clap)] {
            guard case .stereo(let wide) = SoundVoices.beat(voice, random: &random) else {
                Issue.record("\(voice) is mono")
                continue
            }
            let (middle, side) = (vDSP.add(wide.left, wide.right), vDSP.subtract(wide.left, wide.right))
            let width = vDSP.rootMeanSquare(side) / vDSP.rootMeanSquare(middle)
            #expect(width > 0.25 && width < 1)
        }
        let sheet = await MotionPlan.build(try document(story, style: .groove), bundle: URL.temporaryDirectory).sound
        #expect(!sheet.cues.contains { if case .vox = $0.voice { true } else { false } })
        #expect(Set(sheet.cues.filter { isDrum($0, .hat) }.map(\.pan)) == [-SoundRules.hatPan, SoundRules.hatPan])
    }

    @Test func theStyleIsTheDocumentsAndAmbientByDefault() throws {
        #expect(MotionSound().style == .ambient)
        let old = try JSONDecoder().decode(MotionDocument.self, from: Data(
            #"{"version": 1, "sound": {"effects": false}, "scenes": [{"id": "a", "duration": 1}]}"#.utf8))
        #expect(old.sound.style == .ambient)
        var document = old
        let edits = try JSONDecoder().decode([MotionEdit].self, from: Data(#"[{"op": "set_sound", "sound": {"style": "groove"}}]"#.utf8))
        try edits[0].apply(to: &document)
        #expect(document.sound == MotionSound(score: true, effects: false, style: .groove))
        // An ambient sheet codes as it did before styles: no finish, no pump
        let sheet = SoundCueSheet(length: 1, chords: [SoundCueSheet.Chord(notes: [50], bass: nil, start: 0, end: 1, level: -30)])
        let coded = try #require(String(bytes: try JSONEncoder().encode(sheet), encoding: .utf8))
        #expect(!coded.contains("finish") && !coded.contains("pump"))
    }
}
