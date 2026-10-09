//
//  ClickSoundTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import AVFoundation
import Testing
@testable import Reco

struct ClickSoundTests {

    private func click(at time: Double, isDown: Bool = true, button: InputTelemetry.MouseButton = .left) -> InputTelemetry.Click {
        .init(time: time, location: .zero, button: button, isDown: isDown, clickCount: 1)
    }

    @Test func soundsAtEveryPressButNotItsRelease() {
        let clicks = [click(at: 1), click(at: 1.1, isDown: false), click(at: 2.5, button: .right), click(at: 0.00001)]

        #expect(ClickSound.onsets(of: clicks.sorted { $0.time < $1.time }) == [0, 48_000, 120_000])
    }

    @Test func isTwentyMillisecondsOfSound() {
        #expect(ClickSound.samples.count == 960)
        #expect(ClickSound.samples[0] == 0)
        #expect((ClickSound.samples.map(abs).max() ?? 0) > 0.3)
        // Decayed to nothing by its end
        #expect(abs(ClickSound.samples[959]) < 0.01)
    }

    @Test func mixingInPiecesGivesTheSameSamplesAsAtOnce() {
        // A click straddling the pieces' edge at 100, and one in the second piece, apart
        let onsets = [60, 1_200]
        var whole = [Float](repeating: 0, count: 2_500)
        whole.withUnsafeMutableBufferPointer { ClickSound.mix(onsets: onsets, into: $0, startingAt: 0) }

        var first = [Float](repeating: 0, count: 100)
        var second = [Float](repeating: 0, count: 2_400)
        first.withUnsafeMutableBufferPointer { ClickSound.mix(onsets: onsets, into: $0, startingAt: 0) }
        second.withUnsafeMutableBufferPointer { ClickSound.mix(onsets: onsets, into: $0, startingAt: 100) }

        #expect(first + second == whole)
        #expect(whole[60 + 1] == ClickSound.samples[1])
        #expect(whole[1_200 + 959] == ClickSound.samples[959])
        #expect(whole[..<60].allSatisfy { $0 == 0 } && whole[1_020..<1_200].allSatisfy { $0 == 0 })
    }

    @Test func clicksOnTopOfEachOtherAddUpAndStayWithinFullScale() {
        var buffer = [Float](repeating: 0, count: 1_000)

        buffer.withUnsafeMutableBufferPointer { ClickSound.mix(onsets: [10, 10], into: $0, startingAt: 0) }
        #expect(buffer[11] == ClickSound.samples[1] * 2)

        // Three of them are past full scale at their peak
        buffer.withUnsafeMutableBufferPointer { ClickSound.mix(onsets: [10, 10, 10], into: $0, startingAt: 0) }
        #expect(buffer.max() == 1 && (buffer.min() ?? 0) >= -1)
    }

    @Test func theFileHasEachClickAtItsSampleAndSilenceBetween() async throws {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        // Over a chunk's edge (a chunk is a second) and at the very start
        let lastOnset = 3 * 48_000 + 123
        let onsets = [0, 47_990, lastOnset]

        try await ClickSoundWriter.write(onsets: onsets, frameCount: 4 * 48_000, to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.length == 4 * 48_000)
        #expect(file.fileFormat.sampleRate == 48_000)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = try #require(buffer.floatChannelData).pointee
        let all = UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))
        for onset in onsets {
            let first = try #require(all.indices.first { all[$0] != 0 && $0 >= onset })
            #expect(first <= onset + 1)
        }
        // Silent between the first click's end and the second's start, and after the last
        #expect(all[961..<47_990].allSatisfy { $0 == 0 })
        #expect(all[(lastOnset + 960)...].allSatisfy { $0 == 0 })
        // Lossless to 16 bits
        let difference: Float = abs(all[lastOnset + 5] - ClickSound.samples[5])
        #expect(difference < 1.0 / 32_768)
    }
}
