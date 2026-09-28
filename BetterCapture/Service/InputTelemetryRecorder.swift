//
//  InputTelemetryRecorder.swift
//  BetterCapture
//
//  Created by Diip3sh on 25.09.26.
//

import AppKit
import AVFoundation
import OSLog
import ScreenCaptureKit

/// Records cursor, cursor shape, click, scroll and keystroke telemetry during a recording and
/// writes it as a JSON sidecar next to the video.
///
/// Events are buffered with raw host-clock times because the video's time zero is only known once
/// its first sample arrives. `writeSidecar(for:sessionStart:)` moves them onto the video timeline.
@MainActor
final class InputTelemetryRecorder {

    private var telemetry: InputTelemetry?
    private var primaryScreenHeight: CGFloat = 0
    private var cursorTask: Task<Void, Never>?
    private var mouseMonitor: Any?
    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    private var cursorShapes = CursorShapeTracker()
    private var nextShapeSampleTime: Double = 0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "InputTelemetryRecorder")

    // MARK: - Recording

    /// Starts recording input for a capture that has just started.
    /// - Parameters:
    ///   - filter: The content filter being recorded.
    ///   - sourceRect: The area selection, if any.
    ///   - videoSize: The video's dimensions in pixels.
    ///   - cursorInVideo: Whether the capture draws the system cursor into the video.
    ///   - frameRate: The recording's frame rate; the cursor is polled at this rate, capped to 60 Hz.
    func start(filter: SCContentFilter, sourceRect: CGRect?, videoSize: CGSize, cursorInVideo: Bool, frameRate: Double) {
        // AppKit locations have a bottom-left origin on the primary display, so flip against it
        primaryScreenHeight = CGDisplayBounds(CGMainDisplayID()).height

        let keystrokesAvailable = startKeyTap()
        telemetry = InputTelemetry(
            capture: .init(kind: Self.kind(filter: filter, sourceRect: sourceRect), videoSize: videoSize, cursorInVideo: cursorInVideo),
            keystrokesAvailable: keystrokesAvailable
        )

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel]
        ) { [weak self] event in
            self?.record(event)
        }

        cursorShapes = CursorShapeTracker(standardCursors: StandardCursors.fingerprints)
        nextShapeSampleTime = 0

        let interval = Duration.seconds(1 / min(frameRate, 60))
        cursorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sampleCursor()
                try? await Task.sleep(for: interval)
            }
        }

        logger.info("Input telemetry started (keystrokes: \(keystrokesAvailable))")
    }

    /// Stops listening for input. The buffer is kept for `writeSidecar(for:sessionStart:)`.
    func stop() {
        cursorTask?.cancel()
        cursorTask = nil

        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }

        if let keyTap {
            CGEvent.tapEnable(tap: keyTap, enable: false)
            CFMachPortInvalidate(keyTap)
            self.keyTap = nil
        }

        if let keyTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), keyTapSource, .commonModes)
            self.keyTapSource = nil
        }
    }

    /// Writes the buffered telemetry next to `videoURL`, moved onto the video's timeline.
    ///
    /// Does nothing when no telemetry was recorded. Failures are only logged: the recording
    /// itself has already been saved.
    /// - Parameters:
    ///   - videoURL: The finished recording. Its folder must still be accessible.
    ///   - sessionStart: The host-clock time of the video's first frame.
    ///   - pauses: The recording's paused intervals in host-clock seconds, cut from the video.
    ///   - geometry: The capture geometry track, timed on the host clock.
    /// - Returns: Whether the saved sidecar records the cursor as left out of the video, for the
    ///   editor to draw.
    func writeSidecar(for videoURL: URL, sessionStart: CMTime, pauses: [Range<Double>], geometry: [InputTelemetry.Geometry]) async -> Bool {
        guard var telemetry, sessionStart.isNumeric else { return false }
        self.telemetry = nil
        telemetry.geometry = geometry
        telemetry.cursorSprites = cursorShapes.sprites
        telemetry.cursorShapes = cursorShapes.shapes

        // The file ends at its last video frame, which is before stop if the screen was static
        let duration = (try? await AVURLAsset(url: videoURL).load(.duration).seconds) ?? .infinity
        let url = InputTelemetry.sidecarURL(for: videoURL)

        do {
            let data = try JSONEncoder().encode(telemetry.rebased(anchor: sessionStart.seconds, duration: duration, pauses: pauses))
            try data.write(to: url, options: .atomic)
            logger.info("Input telemetry saved to: \(url.lastPathComponent)")
            return !telemetry.capture.cursorInVideo
        } catch {
            logger.error("Failed to write input telemetry: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Event Handling

    private func sampleCursor() {
        let now = currentHostTime()

        // Reading the cursor image costs ~0.3 ms, so its shape is checked at most 15 times a second
        if now >= nextShapeSampleTime {
            nextShapeSampleTime = now + 1.0 / 15
            sampleCursorShape(at: now)
        }

        let location = InputTelemetry.topLeft(NSEvent.mouseLocation, primaryScreenHeight: primaryScreenHeight)
        guard location != telemetry?.cursor.last?.location else { return }
        telemetry?.cursor.append(.init(time: now, location: location))
    }

    /// Records the cursor image shown system-wide, whichever app is frontmost.
    ///
    /// `NSCursor.current` is only this app's cursor. `currentSystem` is slated for deprecation
    /// and may return `nil` in a future macOS; then no shapes are recorded.
    private func sampleCursorShape(at time: Double) {
        // Fingerprinted like the standard cursors, so a match identifies its kind
        guard let cursor = NSCursor.currentSystem, let fingerprint = StandardCursors.fingerprint(of: cursor) else { return }

        cursorShapes.record(fingerprint, time: time) { StandardCursors.png(of: cursor) }
    }

    private func record(_ event: NSEvent) {
        // Global monitor events have no window, so this is a screen location
        let location = InputTelemetry.topLeft(event.locationInWindow, primaryScreenHeight: primaryScreenHeight)

        switch event.type {
        case .scrollWheel:
            let delta = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
            telemetry?.scrolls.append(.init(time: event.timestamp, location: location, delta: delta))
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            recordClick(event, at: location, isDown: true)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            recordClick(event, at: location, isDown: false)
        default:
            break
        }
    }

    private func recordClick(_ event: NSEvent, at location: CGPoint, isDown: Bool) {
        let button: InputTelemetry.MouseButton = switch event.buttonNumber {
        case 0: .left
        case 1: .right
        default: .other
        }

        telemetry?.clicks.append(.init(
            time: event.timestamp,
            location: location,
            button: button,
            isDown: isDown,
            clickCount: event.clickCount
        ))
    }

    /// Handles the key tap callback, which runs on the main thread.
    fileprivate func handleKeyTap(type: CGEventType, key: InputTelemetry.Key?) {
        if let key {
            telemetry?.keys.append(key)
        } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let keyTap {
            // The system disables taps that are slow or interrupted; keep listening
            CGEvent.tapEnable(tap: keyTap, enable: true)
        }
    }

    // MARK: - Setup

    /// Starts a listen-only tap for key presses and returns whether keystrokes will be recorded.
    ///
    /// `NSEvent` global monitors never receive key events in the sandbox, so this needs Input
    /// Monitoring. A permission granted during this launch only takes effect after a relaunch.
    private func startKeyTap() -> Bool {
        guard CGPreflightListenEventAccess() else { return false }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
            callback: keyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.warning("Could not create key event tap; keystrokes will not be recorded")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        // keyTapCallback relies on running on the main thread
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        keyTap = tap
        keyTapSource = source
        return true
    }

    /// What the recording captures. Area selections are display captures with a source rect.
    private static func kind(filter: SCContentFilter, sourceRect: CGRect?) -> InputTelemetry.CaptureKind {
        if sourceRect != nil { return .area }
        return filter.style == .window ? .window : .display
    }
}

// MARK: - Clock

/// Seconds on the host clock that ScreenCaptureKit timestamps samples with.
nonisolated private func currentHostTime() -> Double {
    CMClockGetTime(CMClockGetHostTimeClock()).seconds
}

// MARK: - Key Tap Callback

/// C callback for the key event tap. Runs on the main thread, where the tap's run loop source lives.
///
/// Reads only the key code, modifier flags and repeat flag - never the typed characters.
/// ponytail: stamped with the host clock on arrival rather than converting `CGEvent.timestamp`;
/// main-thread latency is well under a frame.
nonisolated private func keyTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let recorder = Unmanaged<InputTelemetryRecorder>.fromOpaque(userInfo).takeUnretainedValue()
    let key = type == .keyDown
        ? InputTelemetry.Key(
            time: currentHostTime(),
            keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode)),
            modifiers: InputTelemetry.modifierNames(event.flags),
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )
        : nil

    MainActor.assumeIsolated {
        recorder.handleKeyTap(type: type, key: key)
    }
    return Unmanaged.passUnretained(event)
}
