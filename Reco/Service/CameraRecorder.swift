//
//  CameraRecorder.swift
//  Reco
//

import AVFoundation
import Foundation
import OSLog

/// Records the camera to its own movie alongside the screen. Capture work runs off the main actor; a failure is
/// reported through ``onFailure`` and never touches the screen recording.
@MainActor
final class CameraRecorder {

    nonisolated enum Failure: LocalizedError {
        case noCamera
        case cannotConfigure
        case notRunning
        case noFrames
        case disconnected

        var errorDescription: String? {
            switch self {
            case .noCamera: String(localized: "No camera is available.")
            case .cannotConfigure: String(localized: "The camera couldn't be set up.")
            case .notRunning: String(localized: "The camera didn't start.")
            case .noFrames: String(localized: "The camera delivered no video.")
            case .disconnected: String(localized: "The camera was disconnected.")
            }
        }
    }

    /// Called at most once per take, for what goes wrong after ``start(deviceID:movie:)`` returned.
    var onFailure: ((any Error) -> Void)?

    private var session: AVCaptureSession?
    private var fileWriter: CameraFileWriter?
    private var observers: [any NSObjectProtocol] = []
    private var hasFailed = false

    /// `startRunning` and `stopRunning` block and must not run on the main thread.
    private let sessionQueue = DispatchQueue(label: "com.diip3sh.reco.cameraRecorder")

    /// Kept apart from ``sessionQueue``, so stopping the session never waits on a queue it's blocking.
    private let frameQueue = DispatchQueue(label: "com.diip3sh.reco.cameraRecorder.frames")

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "CameraRecorder")

    /// Starts the camera and suspends until it's running, writing to `movie` from its first frame on.
    /// - Parameter deviceID: The camera to use; the system default when `nil` or no longer connected.
    func start(deviceID: String?, movie: URL) async throws {
        guard session == nil else { return }
        guard let device = deviceID.flatMap(AVCaptureDevice.init(uniqueID:)) ?? AVCaptureDevice.default(for: .video) else {
            throw Failure.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        let session = AVCaptureSession()
        let fileWriter = CameraFileWriter(url: movie, session: session) { [weak self] error in
            Task { @MainActor in self?.fail(error) }
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(fileWriter, queue: frameQueue)
        session.beginConfiguration()
        let canAdd = session.canAddInput(input) && session.canAddOutput(output)
        if canAdd {
            session.addInput(input)
            session.addOutput(output)
        }
        session.commitConfiguration()
        guard canAdd else { throw Failure.cannotConfigure }

        hasFailed = false
        self.session = session
        self.fileWriter = fileWriter
        observe(session, device: device)

        // AVCaptureSession is not Sendable, but it's fully configured above and from here only touched on the queue
        nonisolated(unsafe) let runnable = session
        let isRunning = await withCheckedContinuation { continuation in
            sessionQueue.async {
                runnable.startRunning()
                continuation.resume(returning: runnable.isRunning)
            }
        }
        guard isRunning else {
            await cancel()
            throw Failure.notRunning
        }
        logger.info("Camera recording to \(movie.lastPathComponent)")
    }

    func pause(at time: CMTime) {
        fileWriter?.pause(at: time)
    }

    func resume(at time: CMTime) {
        fileWriter?.resume(at: time)
    }

    /// Stops the camera and finishes its file. `nil` when it wasn't recording or left nothing to keep.
    func finish() async -> CameraTake? {
        guard let fileWriter else { return nil }
        await stopSession()
        self.fileWriter = nil
        let take = await fileWriter.finish()
        if take == nil {
            fail(Failure.noFrames)
        }
        return take
    }

    /// Stops the camera and removes its file. Does nothing when it isn't recording.
    func cancel() async {
        guard let fileWriter else { return }
        await stopSession()
        self.fileWriter = nil
        fileWriter.cancel()
    }

    // MARK: - Private

    private func stopSession() async {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let session else { return }
        self.session = nil
        // See start(deviceID:movie:) for why nonisolated(unsafe) is appropriate
        nonisolated(unsafe) let stoppable = session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                stoppable.stopRunning()
                continuation.resume()
            }
        }
    }

    private func observe(_ session: AVCaptureSession, device: AVCaptureDevice) {
        observers = [
            NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                MainActor.assumeIsolated { self?.fail(error ?? AVError(.unknown)) }
            },
            NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: device, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fail(Failure.disconnected) }
            }
        ]
    }

    /// Warns once. What's written so far is kept where it can be: the bubble hides once the footage ends.
    private func fail(_ error: any Error) {
        guard !hasFailed else { return }
        hasFailed = true
        onFailure?(error)
    }
}
