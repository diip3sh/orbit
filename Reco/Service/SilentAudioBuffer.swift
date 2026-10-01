//
//  SilentAudioBuffer.swift
//  Reco
//

import AVFoundation
import CoreMedia
import Foundation

/// Creates buffers of silence used to pad the start of an audio track.
///
/// Audio devices do not begin delivering samples the instant a capture starts.
/// System audio typically arrives a few tens of milliseconds late and a
/// microphone can take several hundred milliseconds to spin up. Writing those
/// samples at their natural offset leaves the track starting after the video,
/// which QuickTime resolves through the track's edit list but tools that ignore
/// edit lists - `ffmpeg`'s concat demuxer among them - do not. Padding the head
/// of the track with silence keeps every track starting at time zero.
nonisolated enum SilentAudioBuffer {

    /// Builds a silent sample buffer matching an existing audio format.
    ///
    /// - Parameters:
    ///   - formatDescription: The format description of a real sample buffer from
    ///     the same source. The silence matches its sample rate, channel layout
    ///     and sample format so the writer can append both without a format change.
    ///   - duration: How much silence to generate. Must be positive.
    ///   - presentationTime: The presentation timestamp for the returned buffer.
    /// - Returns: A ready sample buffer of silence, or `nil` if the format is not
    ///   uncompressed PCM or the duration rounds to less than one frame.
    static func make(
        matching formatDescription: CMFormatDescription,
        duration: CMTime,
        at presentationTime: CMTime
    ) -> CMSampleBuffer? {
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        guard duration.isNumeric, duration > .zero, format.sampleRate > 0 else { return nil }

        let frameCount = AVAudioFrameCount((duration.seconds * format.sampleRate).rounded())
        guard frameCount > 0,
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            return nil
        }

        pcmBuffer.frameLength = frameCount
        zeroSamples(in: pcmBuffer)

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(format.sampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr, let buffer = sampleBuffer else { return nil }

        let attachStatus = CMSampleBufferSetDataBufferFromAudioBufferList(
            buffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: pcmBuffer.mutableAudioBufferList
        )

        guard attachStatus == noErr else { return nil }
        return buffer
    }

    /// `AVAudioPCMBuffer` does not guarantee zeroed memory, so clear it explicitly.
    private static func zeroSamples(in pcmBuffer: AVAudioPCMBuffer) {
        let bufferList = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
        for buffer in bufferList {
            guard let data = buffer.mData else { continue }
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}
