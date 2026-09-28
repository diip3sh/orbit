//
//  TestRecording.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation
import Testing

/// Short synthetic recordings for editor tests.
enum TestRecording {

    static let sampleRate = 48_000.0

    /// The tone's peak, as a share of full scale.
    static let toneAmplitude = 0.5

    /// Writes an H.264 recording of flat grey frames, frame `n` at level `level(n)` in every channel,
    /// with a 440 Hz tone on one 16-bit PCM audio track when `withTone` is set.
    static func write(
        to url: URL, size: CGSize, frameCount: Int, frameRate: Int32, withTone: Bool = false, level: (Int) -> UInt8 = { _ in 0 }
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height
        ])
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        let tone = withTone ? try toneBuffer(duration: Double(frameCount) / Double(frameRate)) : nil
        let audioInput = tone.map { AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: $0.formatDescription) }
        if let audioInput {
            writer.add(audioInput)
        }
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        // All the audio first, so the writer never waits for it to interleave with the video
        if let audioInput, let tone {
            audioInput.append(tone)
            audioInput.markAsFinished()
        }
        for index in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(try frame(size: size, level: level(index)), withPresentationTime: CMTime(value: CMTimeValue(index), timescale: frameRate))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: frameRate))
        await writer.finishWriting()
        #expect(writer.status == .completed, "\(String(describing: writer.error))")
    }

    private static func frame(size: CGSize, level: UInt8) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let frame = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(frame, [])
        memset(CVPixelBufferGetBaseAddress(frame), Int32(level), CVPixelBufferGetDataSize(frame))
        CVPixelBufferUnlockBaseAddress(frame, [])
        return frame
    }

    /// `duration` seconds of the tone, 48 kHz mono, in one sample buffer.
    private static func toneBuffer(duration: Double) throws -> CMSampleBuffer {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true))
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        pcm.frameLength = frameCount
        let samples = try #require(pcm.int16ChannelData)[0]
        for index in 0..<Int(frameCount) {
            samples[index] = Int16(toneAmplitude * Double(Int16.max) * sin(2 * .pi * 440 * Double(index) / sampleRate))
        }

        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        // Written as is, so each sample's size is needed
        var sampleSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        var buffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil,
            formatDescription: format.formatDescription, sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &buffer
        )
        let sampleBuffer = try #require(buffer)
        let status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, bufferList: pcm.audioBufferList
        )
        #expect(status == noErr)
        return sampleBuffer
    }
}
