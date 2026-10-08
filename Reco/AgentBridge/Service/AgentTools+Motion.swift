//
//  AgentTools+Motion.swift
//  Reco
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Motion videos

/// The motion tools (spec 0011, *Agent*): the agent writes no motion code; it edits a document with
/// operations the grammar validates, captures the UI it shows, and looks at what it made.
extension AgentTools {

    /// The document of `bundle` as its open window has it, else as saved.
    func motionDocument(at bundle: URL) async throws -> MotionDocument {
        if let document = motionEditor(bundle)?.document {
            return document
        }
        return try await MotionStore.read(bundle)
    }

    /// Applies the operations, all or none, through the bundle's window if one is open, and
    /// describes the result; without operations, only describes the video.
    func editMotion(_ arguments: Data) async throws -> MotionSummary {
        let request = try Self.decode(EditMotionRequest.self, from: arguments)
        let existing = try request.existingBundle()
        let bundle = existing ?? EditMotionRequest.newBundle(named: request.name, in: settings.outputDirectory)
        let document = if let existing { try await motionDocument(at: existing) } else { MotionDocument() }
        if let existing, request.operations.isEmpty {
            return MotionSummary(document, bundle: existing, sizes: UILiftCache.sizes(of: document, in: existing))
        }
        let edited = try request.edited(document)
        let actionName = request.operations.count == 1 ? request.operations[0].actionName : "Agent Edit"
        if let editor = motionEditor(bundle) {
            try await editor.apply(edited, actionName: actionName)
        } else {
            try await MotionStore.write(edited, to: bundle)
        }
        motionEdits += 1
        lastMotionBundle = bundle
        onMotionEdited(bundle)
        return MotionSummary(edited, bundle: bundle, sizes: UILiftCache.sizes(of: edited, in: bundle))
    }

    /// The size a launch video is exported at (the playbook's 4K), which its UI is captured for.
    static let exportShorterSide: CGFloat = 2160

    /// Lifts and bakes the UI the video shows, sharp enough for its 4K export, so the export captures
    /// nothing: captured at the preview's size, a Linear film's export baked its live take again at 6×
    /// for 20 minutes and failed.
    func captureUI(_ arguments: Data) async throws -> Reply {
        let bundle = try Self.decode(MotionBundleRequest.self, from: arguments).validated()
        return await motionJob(key: "capture \(bundle.path(percentEncoded: false))", activity: "Capturing the UI…") { [self] in
            let document = try await motionDocument(at: bundle)
            let side = min(Self.exportShorterSide, 2 * min(document.canvas.size.width, document.canvas.size.height))
            _ = try await UICapture.plan(for: document, bundle: bundle, shorterSide: side)
            let summary = MotionSummary(document, bundle: bundle, sizes: UILiftCache.sizes(of: document, in: bundle))
            return (MotionToolStatus(status: .done, assets: summary.assets, lint: summary.findings), nil)
        }
    }

    /// A contact sheet of the video's beats, and what the design check and the rules find.
    func previewMotion(_ arguments: Data) async throws -> Reply {
        let bundle = try Self.decode(MotionBundleRequest.self, from: arguments).validated()
        return await motionJob(key: "preview \(bundle.path(percentEncoded: false))", activity: "Checking the video…") { [self] in
            let document = try await motionDocument(at: bundle)
            let plan = try await UICapture.plan(for: document, bundle: bundle, shorterSide: ContactSheet.frameShorterSide)
            // Every scene is checked; the sheet shows at most twelve of them
            let moments = ContactSheet.moments(in: MotionSummary(document, bundle: bundle, sizes: [:]))
            let frames = try await ContactSheet.frames(of: plan, at: moments)
            let shown = ContactSheet.picked(moments)
            let sheetFrames = shown.compactMap { moment in moments.firstIndex(of: moment).map { frames[$0] } }
            guard let sheet = ContactSheet.sheet(of: sheetFrames), let image = Self.jpegData(of: sheet) else { throw WebRenderError.snapshotFailed }
            let summary = MotionSummary(document, bundle: bundle, sizes: UILiftCache.sizes(of: document, in: bundle))
            let findings = DesignCheck.findings(in: frames, at: moments, accent: document.style.accent)
                + DesignCheck.bareOpenings(in: plan, scenes: document.scenes.map(\.id))
            var status = MotionToolStatus(
                status: .done, frames: shown.map { MotionToolStatus.Frame(scene: $0.scene, time: $0.time) }, findings: findings, lint: summary.findings
            )
            if let sound = try await SoundCache.sound(for: plan.sound, in: bundle) {
                status.sound = MotionToolStatus.Sound(cues: plan.sound.cues.count, loudness: (try await SoundCache.loudness(of: sound) * 10).rounded() / 10)
            }
            return (status, image)
        }
    }

    /// Runs `work` as the one capture or preview, or follows it when it's the one already running
    /// with the same `key`, for up to ``waitLimit``; after that the agent calls again.
    private func motionJob(
        key: String, activity: String, _ work: @escaping @MainActor () async throws -> (MotionToolStatus, Data?)
    ) async -> Reply {
        if let job = motionJob, job.key != key, !job.isDone {
            return Reply(text: "Reco is still busy with another capture_ui or preview_motion: call that one again until it's done.", isError: true)
        }
        let task: Task<Reply, Never>
        if let job = motionJob, job.key == key {
            task = job.task
        } else {
            motionActivity = activity
            task = Task { [weak self] in
                let reply: Reply
                do {
                    let (status, image) = try await work()
                    reply = Reply(text: (try? Self.encode(status)) ?? "", image: image, isError: false)
                } catch {
                    let status = MotionToolStatus(status: .failed, error: error.localizedDescription)
                    reply = Reply(text: (try? Self.encode(status)) ?? error.localizedDescription, isError: true)
                }
                if self?.motionJob?.key == key {
                    self?.motionJob?.isDone = true
                    self?.motionActivity = nil
                }
                return reply
            }
            motionJob = MotionJob(key: key, task: task)
        }
        // Polled, as a render is: awaiting the task in a group beside a timer waited for the task anyway,
        // since a group ends only once its children have, and a capture that hung held the agent's call
        let deadline = ContinuousClock.now + Self.waitLimit
        let isOver = { [self] in motionJob?.key != key || motionJob?.isDone == true }
        while !isOver(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.pollInterval)
        }
        guard isOver() else {
            let status = MotionToolStatus(status: .working, error: "Still working: call this tool again with the same arguments.")
            return Reply(text: (try? Self.encode(status)) ?? "", isError: false)
        }
        let reply = await task.value
        if motionJob?.key == key {
            motionJob = nil
        }
        return reply
    }

    /// A JPEG of the sheet: the grammar fixture's 8 frames come to 89 KB (M5, `MotionAgentTests`).
    nonisolated private static func jpegData(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
