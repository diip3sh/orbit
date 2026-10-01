//
//  NotificationService.swift
//  Reco
//
//  Created by Joshua Sattler on 06.02.26.
//

import Foundation
import UserNotifications
import AppKit
import OSLog

/// Service responsible for managing user notifications
@MainActor
@Observable
final class NotificationService: NSObject {

    // MARK: - Constants

    nonisolated private enum NotificationIdentifier {
        static let categoryRecordingSaved = "RECORDING_SAVED"
        static let categoryRecordingEditable = "RECORDING_EDITABLE"
        static let categoryRecordingFailed = "RECORDING_FAILED"
        static let categoryAgentRecordingFailed = "AGENT_RECORDING_FAILED"
        static let actionShowInFinder = "SHOW_IN_FINDER"
        static let actionEdit = "EDIT"
        static let actionRetryAgent = "RETRY_AGENT"
    }

    nonisolated private enum UserInfoKey {
        static let folderURL = "folderURL"
        static let fileURL = "fileURL"
        static let opensEditor = "opensEditor"
    }

    // MARK: - Properties

    /// Opens a recording in the editor, from the notification's Edit action. Set by the app delegate.
    @ObservationIgnored var editRecording: ((URL) -> Void)?

    /// Runs the last agent recording again, from the failure notification's Retry. Set by the app delegate.
    @ObservationIgnored var retryAgentRecording: (() -> Void)?

    /// Opens the Record with AI Agent panel, from tapping the failure notification. Set by the app delegate.
    @ObservationIgnored var showAgentRecording: (() -> Void)?

    private let settings: SettingsStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Reco",
        category: "NotificationService"
    )

    // MARK: - Initialization

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        setupNotificationDelegate()
        registerNotificationCategories()
        requestNotificationPermission()
    }

    // MARK: - Setup

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    private func registerNotificationCategories() {
        // Action to show recording in Finder
        let showInFinderAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionShowInFinder,
            title: "Show in Finder",
            options: [.foreground]
        )

        // Action to open the recording in the editor
        let editAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionEdit,
            title: "Edit",
            options: [.foreground]
        )

        // Category for successful recording with action
        let recordingSavedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryRecordingSaved,
            actions: [showInFinderAction],
            intentIdentifiers: []
        )

        // Category for a recording with video, which the editor can open
        let recordingEditableCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryRecordingEditable,
            actions: [editAction, showInFinderAction],
            intentIdentifiers: []
        )

        // Category for failed recording (no actions needed)
        let recordingFailedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryRecordingFailed,
            actions: [],
            intentIdentifiers: []
        )

        // Category for a failed agent recording, which can run again
        let agentRecordingFailedCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryAgentRecordingFailed,
            actions: [UNNotificationAction(identifier: NotificationIdentifier.actionRetryAgent, title: "Retry", options: [])],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            recordingSavedCategory,
            recordingEditableCategory,
            recordingFailedCategory,
            agentRecordingFailedCategory
        ])
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                if granted {
                    logger.info("Notification permission granted")
                } else {
                    logger.warning("Notification permission denied")
                }
            } catch {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public Methods

    /// Sends a notification for a successfully saved recording, with an Edit action
    /// - Parameters:
    ///   - fileURL: The URL of the saved recording file
    ///   - opensEditor: Whether clicking the notification opens the editor instead of the folder
    func sendRecordingSavedNotification(fileURL: URL, opensEditor: Bool) {
        send(
            title: "Recording Saved",
            body: "Your recording has been saved to \(fileURL.lastPathComponent)",
            category: NotificationIdentifier.categoryRecordingEditable,
            folderURL: fileURL.deletingLastPathComponent(),
            fileURL: fileURL,
            opensEditor: opensEditor
        )
    }

    /// Sends a notification for a recording that was saved without any video frames
    /// - Parameter fileURL: The URL of the saved recording file
    func sendRecordingMissingVideoNotification(fileURL: URL) {
        send(
            title: "Recording Saved Without Video",
            body: "No video was captured. Only audio was saved to \(fileURL.lastPathComponent)",
            category: NotificationIdentifier.categoryRecordingSaved,
            folderURL: fileURL.deletingLastPathComponent()
        )
    }

    /// Sends a notification for a recording that could not be started
    ///
    /// Start failures leave nothing on disk, so they are reported separately from
    /// failures that lose an in-progress recording.
    /// - Parameter error: The error that prevented the recording from starting
    func sendRecordingStartFailedNotification(error: Error) {
        send(
            title: "Can't Start Recording",
            body: error.localizedDescription,
            category: NotificationIdentifier.categoryRecordingFailed
        )
    }

    /// Sends a notification for a failed recording
    /// - Parameter error: The error that caused the recording to fail
    func sendRecordingFailedNotification(error: Error) {
        send(
            title: "Recording Failed",
            body: "Your recording could not be saved: \(error.localizedDescription)",
            category: NotificationIdentifier.categoryRecordingFailed
        )
    }

    /// Sends a notification when system audio could not be captured
    ///
    /// The video recording continues, so this is reported without stopping anything.
    /// - Parameter error: The error that prevented system audio capture, if any
    func sendSystemAudioFailedNotification(error: Error?) {
        let reason = error.map { ": \($0.localizedDescription)" } ?? ""

        send(
            title: "System Audio Not Recorded",
            body: "Recording continues without system audio\(reason)",
            category: NotificationIdentifier.categoryRecordingFailed
        )
    }

    /// Sends a notification when recording stopped unexpectedly
    /// - Parameter error: Optional error that caused the stop
    func sendRecordingStoppedNotification(error: Error?) {
        let reason = error.map { ": \($0.localizedDescription)" } ?? ""

        send(
            title: "Recording Stopped",
            body: "Recording stopped unexpectedly\(reason)",
            category: NotificationIdentifier.categoryRecordingFailed
        )
    }

    /// Sends a notification for a screenshot that could not be taken or saved
    /// - Parameter error: The error that stopped the screenshot
    func sendScreenshotFailedNotification(error: Error) {
        send(
            title: "Screenshot Failed",
            body: error.localizedDescription,
            category: NotificationIdentifier.categoryRecordingFailed
        )
    }

    /// Sends a notification for an agent recording that failed, with a Retry action
    /// - Parameter reason: Why it failed, with secrets already removed
    func sendAgentRecordingFailedNotification(reason: String) {
        send(
            title: "Agent Recording Failed",
            body: reason,
            category: NotificationIdentifier.categoryAgentRecordingFailed
        )
    }

    // MARK: - Private Methods

    /// Builds and delivers a notification request
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - category: The category identifier determining the available actions
    ///   - folderURL: Folder to reveal when the notification is clicked, if any
    ///   - fileURL: Recording to open with the Edit action, if any
    ///   - opensEditor: Whether clicking the notification opens `fileURL` in the editor instead of revealing the folder
    private func send(title: String, body: String, category: String, folderURL: URL? = nil, fileURL: URL? = nil, opensEditor: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        // Store the folder URL for opening when notification is clicked
        if let folderURL {
            content.userInfo[UserInfoKey.folderURL] = folderURL.path()
        }
        if let fileURL {
            content.userInfo[UserInfoKey.fileURL] = fileURL.path()
            content.userInfo[UserInfoKey.opensEditor] = opensEditor
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                logger.info("Notification sent: \(title)")
            } catch {
                logger.error("Failed to send notification '\(title)': \(error.localizedDescription)")
            }
        }
    }

    private func openFolderInFinder(path: String) {
        _ = settings.startAccessingOutputDirectory()
        defer { settings.stopAccessingOutputDirectory() }
        let url = URL(filePath: path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let folderPath = userInfo[UserInfoKey.folderURL] as? String
        let filePath = userInfo[UserInfoKey.fileURL] as? String
        let opensEditor = userInfo[UserInfoKey.opensEditor] as? Bool ?? false

        switch response.actionIdentifier {
        case NotificationIdentifier.actionRetryAgent:
            await MainActor.run {
                retryAgentRecording?()
            }

        case UNNotificationDefaultActionIdentifier
            where response.notification.request.content.categoryIdentifier == NotificationIdentifier.categoryAgentRecordingFailed:
            // Tapped a failed agent recording: the panel shows why, with Retry
            await MainActor.run {
                showAgentRecording?()
            }

        case NotificationIdentifier.actionEdit,
            UNNotificationDefaultActionIdentifier where opensEditor:
            // User chose "Edit", or tapped a notification for a recording that needs the editor
            if let filePath {
                await MainActor.run {
                    editRecording?(URL(filePath: filePath))
                }
            }

        case NotificationIdentifier.actionShowInFinder,
            UNNotificationDefaultActionIdentifier:
            // User tapped the notification or the "Show in Finder" action; only saved recordings have a folder
            if let folderPath {
                await MainActor.run {
                    openFolderInFinder(path: folderPath)
                }
            }

        default:
            break
        }
    }
}
