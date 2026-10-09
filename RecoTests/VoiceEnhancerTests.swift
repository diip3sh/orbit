//
//  VoiceEnhancerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation
import Testing
@testable import Reco

struct VoiceEnhancerTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private static let sampleRate = 48_000.0

    /// The noise's peak, as a share of full scale.
    private static let noise: Float = 0.05

    /// The system voice saying `text`, mono at the test rate, with a second of silence before it.
    private func speech(_ text: String) async throws -> [Float] {
        let url = folder.appending(path: "speech.caf")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/say")
        process.arguments = ["-o", url.path, "--data-format=LEI16@48000", text]
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
        return Array(repeating: 0, count: Int(Self.sampleRate)) + (try samples(of: url))
    }

    /// Writes `voice` under white noise, on every one of `channels`, to a CAF file.
    private func writeNoisy(_ voice: [Float], channels: UInt32) throws -> URL {
        let url = folder.appending(path: "source.caf")
        let file = try AVAudioFile(
            forWriting: url,
            settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Self.sampleRate, AVNumberOfChannelsKey: channels],
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(voice.count)))
        buffer.frameLength = AVAudioFrameCount(voice.count)
        let samples = try #require(buffer.floatChannelData)
        for channel in 0..<Int(channels) {
            for index in voice.indices {
                samples[channel][index] = voice[index] + Float.random(in: -Self.noise...Self.noise)
            }
        }
        try file.write(from: buffer)
        return url
    }

    /// The first channel of the file at `url`.
    private func samples(of url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        return Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData)[0], count: Int(buffer.frameLength)))
    }

    private func rms(of samples: ArraySlice<Float>) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
    }

    /// The first time a 10 ms window's RMS of `samples` is above `level`.
    private func onset(of samples: [Float], above level: Float) -> Double? {
        let window = Int(0.01 * Self.sampleRate)
        return stride(from: 0, to: samples.count - window, by: window / 2)
            .first { rms(of: samples[$0..<$0 + window]) > level }
            .map { Double($0) / Self.sampleRate }
    }

    /// The sound isolation's latency differs between mono and stereo (see `VoiceEnhancer.latency(channels:)`).
    @Test(arguments: [UInt32(1), 2]) func takesTheNoiseFromAroundTheVoiceAndKeepsItsTime(channels: UInt32) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let voice = try await speech("Enhance the voice and keep its time.")
        let source = try writeNoisy(voice, channels: channels)
        let output = folder.appending(path: "enhanced.caf")

        try await VoiceEnhancer.render(trackID: 1, from: source, to: output)

        let enhanced = try samples(of: output)
        #expect(enhanced.count == voice.count)
        // The first second is noise alone: most of it goes
        let before = rms(of: try samples(of: source)[Int(0.2 * Self.sampleRate)..<Int(0.9 * Self.sampleRate)])
        let after = rms(of: enhanced[Int(0.2 * Self.sampleRate)..<Int(0.9 * Self.sampleRate)])
        #expect(before > 0.02)
        #expect(after < before / 4)
        // The voice stays, where it was
        let speechRange = Int(1.1 * Self.sampleRate)..<min(Int(2.5 * Self.sampleRate), voice.count)
        #expect(rms(of: enhanced[speechRange]) > rms(of: voice[speechRange]) / 2)
        let spoken = try #require(onset(of: voice, above: 0.05))
        let heard = try #require(onset(of: enhanced, above: 0.05))
        #expect(abs(heard - spoken) < 0.015, "spoken at \(spoken), heard at \(heard)")
    }
}
