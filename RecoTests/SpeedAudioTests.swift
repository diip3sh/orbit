//
//  SpeedAudioTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation
import Testing
@testable import Reco

struct SpeedAudioTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private static let sampleRate = 48_000.0

    /// 2 s of mono audio: silent until 0.5 s, then a 440 Hz tone at half scale.
    private func writeSource() throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "source.caf")
        let file = try AVAudioFile(
            forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Self.sampleRate, AVNumberOfChannelsKey: 1],
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let count = Int(2 * Self.sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(count)))
        buffer.frameLength = AVAudioFrameCount(count)
        let samples = try #require(buffer.floatChannelData)[0]
        for index in 0..<count {
            let time = Double(index) / Self.sampleRate
            samples[index] = time < 0.5 ? 0 : Float(0.5 * sin(2 * .pi * 440 * time))
        }
        try file.write(from: buffer)
        return url
    }

    private func samples(of url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData)[0], count: Int(buffer.frameLength)))
    }

    @Test func listsEachTracksPartsAtAnotherSpeed() {
        let timeMap = TimeMap(cuts: [], speeds: [SpeedRange(range: 0.2..<0.6, rate: 4)], sourceDuration: 1, frameRate: 30)

        let parts = SpeedAudio.parts(of: timeMap, trackIDs: [2, 3])

        #expect(parts.map(\.trackID) == [2, 3])
        #expect(parts.allSatisfy { $0.rate == 4 && abs($0.range.lowerBound - 0.2) < 1e-9 && abs($0.range.upperBound - 0.6) < 1e-9 })
    }

    @Test func speedsUpAPartInTimeWithItsPitchKept() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try writeSource()
        let output = folder.appending(path: "fast.caf")
        let part = SpeedAudio.Part(trackID: 1, range: 0.2..<1.4, rate: 4)

        try await SpeedAudio.render(part, from: source, trackID: nil, to: output)

        // 1.2 s at 4×
        let samples = try samples(of: output)
        #expect(samples.count == Int(0.3 * Self.sampleRate))
        // The tone starts 0.3 s into the part: 75 ms in at 4×. The time-pitch spreads its onset over about 23 ms
        // (60–83 ms for 2% to 80% of its level), so it's timed at half its level: 73 ms measured
        let onset = try #require(samples.firstIndex { abs($0) > 0.25 })
        #expect(abs(Double(onset) / Self.sampleRate - 0.075) < 0.005)
        // Still 440 Hz: two zero crossings a cycle
        let steady = samples[Int(0.12 * Self.sampleRate)..<Int(0.28 * Self.sampleRate)]
        let crossings = zip(steady, steady.dropFirst()).count { ($0 < 0) != ($1 < 0) }
        let frequency = Double(crossings) / 2 / 0.16
        #expect(abs(frequency - 440) < 10)
        #expect(steady.map(abs).max() ?? 0 > 0.4)
    }
}
