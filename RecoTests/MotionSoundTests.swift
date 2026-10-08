//
//  MotionSoundTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

/// A video's cue sheet (spec 0013): every sound from the plan's own times, on the frame that shows it; the
/// closing scored as Raycast's, with no effect between its first word and its end; the document's switches.
struct MotionSoundTests {

    /// The typing fixture ("ab" from 0.5 s, presses at 2, 2.5 and 2.8 s, 3 s), a 2 s scene cut in after it
    /// and a closing of two words with a line under them, at 60 fps.
    private func film() async throws -> (plan: MotionPlan, field: TypedField) {
        let (bundle, typed) = try MotionTestBundle.makeTyping()
        var document = typed
        let more = try JSONDecoder().decode([MotionScene].self, from: Data(#"""
            [{"id": "title", "duration": 2},
             {"id": "closing", "duration": 4.5, "shot": {"shot": "closing", "text": "Reco", "items": [{"text": "Sound"}, {"text": "Music"}],
              "detail": "Made for the picture"}}]
            """#.utf8))
        document.scenes += more
        let plan = await MotionPlan.build(document, bundle: bundle)
        return (plan, try #require(plan.scenes[0].layers.first?.typing))
    }

    private func frame(_ time: Double) -> Double {
        SoundRules.frame(time, frameRate: 60)
    }

    private func times(of cues: [SoundCue], _ matches: (SoundCue.Voice) -> Bool) -> [Double] {
        cues.filter { matches($0.voice) }.map(\.time)
    }

    @Test func everyCueSitsOnTheFrameThatShowsIt() async throws {
        let (plan, field) = try await film()
        let cues = plan.sound.cues
        #expect(cues.allSatisfy { abs(($0.time * 60).rounded() - $0.time * 60) < 1e-6 })
        // The first UI shows from the start: its hit is there
        #expect(times(of: cues) { if case .glass = $0 { true } else { false } }.first == 0)
        #expect(times(of: cues) { $0 == .key(.letter) } == field.keys.map(frame))
        #expect(times(of: cues) { if case .blip(_, 0.4) = $0 { true } else { false } } == [frame(field.states[1].time)])
        #expect(times(of: cues) { $0 == .key(.arrow) } == [2, 2.5, 2.8])
        // A selection chosen, then a cut to what it opens
        #expect(times(of: cues) { $0 == .key(.enter) } == [frame(3 - SoundRules.enterLead)])
        #expect(times(of: cues) { if case .swish = $0 { true } else { false } } == [0, 3])
    }

    /// A prompt that never grows shows no results: its words settle without a sound.
    @Test func aPromptWithoutResultsDoesntPop() async throws {
        let (bundle, document) = try MotionTestBundle.makeTyping(results: false)
        let plan = await MotionPlan.build(document, bundle: bundle)
        let cues = plan.sound.cues
        #expect(times(of: cues) { $0 == .key(.letter) }.count == 2)
        #expect(!cues.contains { if case .blip(_, 0.4) = $0.voice { true } else { false } })
    }

    @Test func theClosingIsScoredAsRaycastsIs() async throws {
        let (plan, _) = try await film()
        let sheet = plan.sound
        let start = 5.0
        #expect(sheet.roomStop == start)
        #expect(times(of: sheet.cues) { if case .riser = $0 { true } else { false } } == [start])
        #expect(times(of: sheet.cues) { if case .thump(66, _, _, _) = $0 { true } else { false } } == [start])
        // No effect at all from the cut to black on
        #expect(!sheet.cues.contains { $0.part == .effects && $0.time >= start })
        // An arpeggio note on each word's frame
        let words = ShotLayout.ClosingTimes(words: 2).words.map { frame(start + $0) }
        let felt = sheet.cues.filter { if case .felt = $0.voice { true } else { false } }
        #expect(Set(words).isSubset(of: felt.filter { $0.offset == 0 }.map(\.time)))
        // IV under the words, then I and vi, each quieter
        let closing = sheet.chords.filter { $0.start >= start }
        #expect(closing.map(\.notes.first) == [43, 50, 47])
        #expect(closing.map(\.level) == closing.map(\.level).sorted(by: >))
        // The last chord before it rises into black and stops dead
        let last = try #require(sheet.chords.last { $0.start < start })
        #expect(last.notes == SoundRules.progression[0].notes && last.swell > 0 && last.release < 0.01)
    }

    @Test func theDocumentTurnsEitherPartOffOrMovesIt() async throws {
        let (plan, _) = try await film()
        let sheet = plan.sound
        var sound = MotionSound()
        sound.effects = false
        #expect(sheet.following(sound).cues.allSatisfy { $0.part == .score })
        sound = MotionSound()
        sound.score = false
        let effects = sheet.following(sound)
        #expect(effects.chords.isEmpty && effects.air == nil && effects.cues.allSatisfy { $0.part == .effects })
        sound = MotionSound()
        sound.scoreLevel = -6
        #expect(sheet.following(sound).chords.map(\.level) == sheet.chords.map { $0.level - 6 })
        sound.score = false
        sound.effects = false
        #expect(sheet.following(sound).isSilent)
    }

    /// A whip move and a whip seam, found from the camera's speed: the seam's crosses its cut, the move's
    /// lands where it ends.
    @Test func findsTheCamerasWhips() async throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
            {"version": 1, "canvas": {"field": "satin", "frameRate": 30},
             "assets": [{"id": "card", "url": "https://example.com", "selector": "#card", "glass": true}],
             "scenes": [{"id": "open", "duration": 3, "shot": {"shot": "macro", "ui": "card"}},
                        {"id": "tour", "duration": 4, "seam": "whip", "shot": {"shot": "macro", "items": [
                          {"ui": "card", "view": [[0, 0], [320, 180]]}, {"ui": "card", "view": [[400, 300], [160, 90]]}]}}]}
            """#.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        let whips = SoundCueSheet.cameraWhips(in: plan, until: plan.duration)
        try #require(whips.count == 2)
        #expect(whips[0].crossesCut && abs(whips[0].peak - 3) < 0.02)
        let hold = (4 - MoveExpansion.whipDuration) / 2
        #expect(!whips[1].crossesCut)
        #expect(abs(whips[1].start - (3 + hold)) < 0.03 && abs(whips[1].landing - (3 + hold + MoveExpansion.whipDuration)) < 0.03)
        // The tour's chord changes as the move lands, not as the seam's does
        let chords = plan.sound.chords
        #expect(chords.map(\.start).contains(SoundRules.frame(whips[1].landing, frameRate: 30)))
    }

    @Test func setSoundChangesOnlyWhatItNames() throws {
        var document = MotionDocument()
        document.sound.scoreLevel = -3
        let edits = try JSONDecoder().decode([MotionEdit].self, from: Data(#"[{"op": "set_sound", "sound": {"effects": false}}]"#.utf8))
        try edits[0].apply(to: &document)
        #expect(document.sound == MotionSound(score: true, effects: false, scoreLevel: -3, effectsLevel: 0))
    }

    @Test func aDocumentWithoutSoundHasBoth() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
            {"version": 1, "sound": {"effects": false}, "scenes": [{"id": "a", "duration": 1}]}
            """#.utf8))
        #expect(document.sound == MotionSound(score: true, effects: false))
        var loud = document
        loud.sound.scoreLevel = 20
        #expect(throws: MotionDocumentError.invalidSound) { try loud.validate() }
    }
}
