//
//  CameraFileWriter.swift
//  Reco
//

import AVFoundation
import os

/// Writes camera frames to a movie, cutting pauses the way the screen's ``AssetWriter`` does.
///
/// A video data output and an asset writer rather than `AVCaptureMovieFileOutput`: every frame's timestamp is in hand,
/// so the file's start is known exactly on the host clock, and pauses cut at the same instants as the screen's. A movie
/// file output only says when recording started by calling back at some later moment, and pauses when it gets to it,
/// which would leave the camera tens of milliseconds off the screen, a different amount at every pause.
///
/// `@unchecked` because the writer's state is guarded by `lock`.
nonisolated final class CameraFileWriter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private let url: URL
    private let onFailure: @Sendable (any Error) -> Void

    private let lock = OSAllocatedUnfairLock()
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pauses = RecordingPauses()

    /// The first frame written on the host clock, and the time paused before it.
    private var firstFrame: CMTime?
    private var pausedBeforeFirstFrame = CMTime.zero
    private var lastFileTime = CMTime.negativeInfinity
    private var hasEnded = false

    /// What the capture session timestamps with, read from it once it's running. Without one, a frame's time is taken
    /// to be on the host clock already, as a built-in camera's is.
    private weak var session: AVCaptureSession?
    private var clock: CMClock?

    /// - Parameter onFailure: Called once, from any thread, when writing stops working.
    init(url: URL, session: AVCaptureSession? = nil, onFailure: @escaping @Sendable (any Error) -> Void) {
        self.url = url
        self.session = session
        self.onFailure = onFailure
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let clock = lock.withLockUnchecked {
            self.clock = self.clock ?? session?.synchronizationClock
            return self.clock
        }
        // Converted per frame, so a camera on its own clock doesn't drift from the screen over a long take
        append(image, at: clock.map { CMSyncConvertTime(time, from: $0, to: CMClockGetHostTimeClock()) } ?? time)
    }

    /// Writes a frame captured at `time` on the host clock, unless it's in a pause or the writer is behind, when it's
    /// dropped: the frame before it shows longer.
    func append(_ image: CVImageBuffer, at time: CMTime) {
        let failure: (any Error)? = lock.withLockUnchecked {
            guard !hasEnded, let paused = pauses.pausedTime(start: time, end: time) else { return nil }
            do {
                try appendLocked(image, at: time, paused: paused)
                return nil
            } catch {
                hasEnded = true
                return error
            }
        }
        if let failure {
            onFailure(failure)
        }
    }

    /// Drops every frame captured from `time` on until ``resume(at:)``.
    func pause(at time: CMTime) {
        lock.withLockUnchecked { pauses.pause(at: time) }
    }

    func resume(at time: CMTime) {
        lock.withLockUnchecked { pauses.resume(at: time) }
    }

    /// Finishes the file. `nil`, with nothing left on disk, when no frame was written or writing failed.
    func finish() async -> CameraTake? {
        let (writer, input, firstFrame, pauses) = lock.withLockUnchecked {
            hasEnded = true
            return (self.writer, self.input, self.firstFrame, self.pauses.finished)
        }
        guard let writer, let firstFrame else { return nil }
        if writer.status == .writing {
            input?.markAsFinished()
            await writer.finishWritingWithoutAsyncImport()
        }
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return CameraTake(movie: url, firstFrame: firstFrame, pauses: pauses)
    }

    /// Stops writing and removes the file.
    func cancel() {
        let writer = lock.withLockUnchecked {
            hasEnded = true
            return self.writer
        }
        if writer?.status == .writing {
            writer?.cancelWriting()
        }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func appendLocked(_ image: CVImageBuffer, at time: CMTime, paused: CMTime) throws {
        if writer == nil {
            try startWriting(size: CVImageBufferGetDisplaySize(image))
            firstFrame = time
            pausedBeforeFirstFrame = paused
        }
        guard let writer, let input, let adaptor, let firstFrame else { return }
        guard writer.status == .writing else { throw writer.error ?? AVError(.unknown) }
        let fileTime = time - firstFrame - (paused - pausedBeforeFirstFrame)
        guard fileTime > lastFileTime, input.isReadyForMoreMediaData else { return }
        guard adaptor.append(image, withPresentationTime: fileTime) else { throw writer.error ?? AVError(.unknown) }
        lastFileTime = fileTime
    }

    /// Opened on the first frame, which gives the size; a camera that never delivers leaves no file.
    private func startWriting(size: CGSize) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height
        ])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.startWriting() else { throw writer.error ?? AVError(.unknown) }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
    }
}
