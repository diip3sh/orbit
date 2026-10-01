//
//  PermissionService.swift
//  Reco
//
//  Created by Joshua Sattler on 07.02.26.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import OSLog
import CoreGraphics
import AppKit

/// Service responsible for checking and requesting system permissions
@MainActor
@Observable
final class PermissionService {

    // MARK: - Permission States

    enum PermissionState {
        case unknown
        case granted
        case denied
    }

    private(set) var screenRecordingState: PermissionState = .unknown
    private(set) var microphoneState: PermissionState = .unknown
    private(set) var cameraState: PermissionState = .unknown

    var allPermissionsGranted: Bool {
        screenRecordingState == .granted && microphoneState == .granted
    }

    var hasAnyPermissionDenied: Bool {
        screenRecordingState == .denied || microphoneState == .denied
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Reco",
        category: "PermissionService"
    )

    // MARK: - Initialization

    init() {
        updatePermissionStates()
    }

    // MARK: - Permission Checking

    /// Updates all permission states
    func updatePermissionStates() {
        screenRecordingState = checkScreenRecordingPermission()
        microphoneState = checkMicrophonePermission()
        cameraState = checkCameraPermission()

        let screen = String(describing: screenRecordingState)
        let microphone = String(describing: microphoneState)
        let camera = String(describing: cameraState)
        logger.info("Permission states - Screen: \(screen), Microphone: \(microphone), Camera: \(camera)")
    }

    private func checkScreenRecordingPermission() -> PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    private func checkMicrophonePermission() -> PermissionState {
        state(for: .audio)
    }

    private func checkCameraPermission() -> PermissionState {
        state(for: .video)
    }

    private func state(for mediaType: AVMediaType) -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .unknown
        }
    }

    // MARK: - Permission Requests

    /// Requests required permissions on app launch
    /// - Parameters:
    ///   - includeMicrophone: Whether to also request microphone permission
    ///   - includeCamera: Whether to also request camera permission
    func requestPermissions(includeMicrophone: Bool, includeCamera: Bool) async {
        logger.info("Requesting permissions (includeMicrophone: \(includeMicrophone), includeCamera: \(includeCamera))...")

        // Request screen recording permission first (synchronous)
        requestScreenRecordingPermission()

        // Request microphone permission only if needed (asynchronous)
        if includeMicrophone {
            await requestMicrophonePermission()
        }

        // Camera is only used by Presenter Overlay, so it is only requested when that is on
        if includeCamera {
            await requestCameraPermission()
        }

        // Update states after requests
        updatePermissionStates()
    }

    /// Requests screen recording permission
    /// - Note: This will open System Settings if permission was previously denied
    func requestScreenRecordingPermission() {
        let wasGranted = CGRequestScreenCaptureAccess()
        screenRecordingState = wasGranted ? .granted : .denied
        logger.info("Screen recording permission request result: \(wasGranted)")
    }

    /// Requests microphone permission
    func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            microphoneState = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneState = granted ? .granted : .denied
            logger.info("Microphone permission request result: \(granted)")
        case .denied, .restricted:
            microphoneState = .denied
        @unknown default:
            microphoneState = .unknown
        }
    }

    /// Requests camera permission, used by Presenter Overlay
    /// - Returns: true if permission is granted
    @discardableResult
    func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraState = granted ? .granted : .denied
            logger.info("Camera permission request result: \(granted)")
        case .denied, .restricted:
            cameraState = .denied
        @unknown default:
            cameraState = .unknown
        }

        return cameraState == .granted
    }

    /// Opens System Settings to the Screen Recording preferences pane
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings to the Microphone preferences pane
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings to the Camera preferences pane
    func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
