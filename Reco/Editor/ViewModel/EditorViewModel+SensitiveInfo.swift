//
//  EditorViewModel+SensitiveInfo.swift
//  Reco
//

import Foundation

// MARK: - Finding sensitive info

extension EditorViewModel {

    /// Reads the kept parts' frames for emails, phone numbers, card numbers and API keys, then masks them in one undo
    /// step, joining masks already there that overlap in time, and selects the first new one.
    func findSensitiveInfo() {
        guard let source, sensitiveInfoSearch == nil else { return }
        let times = SensitiveInfoScanner.times(in: timeMap.keptRanges)
        let crop = VideoCrop.pixels(of: project.crop, in: source.naturalSize)
        sensitiveInfoProgress = 0
        sensitiveInfoFound = nil
        sensitiveInfoSearch = Task {
            let samples = await SensitiveInfoScanner.samples(of: source, at: times, crop: crop) { [weak self] progress in
                self?.sensitiveInfoProgress = progress
            }
            defer {
                sensitiveInfoProgress = nil
                sensitiveInfoSearch = nil
            }
            guard !Task.isCancelled else { return }
            let found = SensitiveMasks.masks(from: samples, interval: SensitiveInfoScanner.interval, duration: source.duration)
            sensitiveInfoFound = found.reduce(0) { $0 + $1.rects.count }
            guard !found.isEmpty else { return }
            edit("Find Sensitive Info") { $0.masks = SensitiveMasks.merging(found, into: $0.masks) }
            if let first = project.masks.first(where: { mask in found.contains { $0.range.overlaps(mask.range) } }) {
                selection = .mask(first.id)
            }
        }
    }

    func cancelFindingSensitiveInfo() {
        sensitiveInfoSearch?.cancel()
    }
}
