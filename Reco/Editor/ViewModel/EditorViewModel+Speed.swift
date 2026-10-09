//
//  EditorViewModel+Speed.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

// MARK: - Speed

extension EditorViewModel {

    /// The selected part's speed, for the transport's menu; 1 without a part selected. Set, it's one edit.
    var selectedSpeed: Double {
        get {
            guard case .segment(let range) = selection else { return 1 }
            return timeMap.rate(atSource: (range.lowerBound + range.upperBound) / 2)
        }
        set { setSpeed(newValue) }
    }

    var canChangeSpeed: Bool {
        if case .segment = selection { true } else { false }
    }

    /// Plays the selected part at `rate`. Its ends become splits, so it stays a part of its own when a cut beside
    /// it is restored. It stays selected.
    func setSpeed(_ rate: Double) {
        guard case .segment(let range) = selection else { return }
        edit("Speed") {
            $0.speeds = timeMap.speeds(setting: rate, for: range)
            $0.splits = splits(adding: [range])
        }
        if segments.contains(range) {
            selection = .segment(range)
        }
    }

    /// The typing stretches Speed Up Typing would change: those with something kept and no speed of their own yet.
    var typingSpeedUps: [SpeedRange] {
        guard let keys = source?.telemetry?.keys else { return [] }
        return TypingStretches.speedUps(for: keys).filter { stretch in
            timeMap.keptRanges.contains { $0.overlaps(stretch.range) } && !timeMap.speeds.contains { $0.range.overlaps(stretch.range) }
        }
    }

    /// Plays every stretch in ``typingSpeedUps`` faster, as one edit, each a part of its own.
    func speedUpTyping() {
        let speedUps = typingSpeedUps
        guard !speedUps.isEmpty else { return }
        edit("Speed Up Typing") {
            $0.speeds = timeMap.speeds(adding: speedUps)
            $0.splits = splits(adding: speedUps.map(\.range))
        }
    }

    /// The project's splits with the ends of `ranges`, snapped to frames, sorted.
    private func splits(adding ranges: [Range<Double>]) -> [Double] {
        let ends = ranges.flatMap { [timeMap.snapped($0.lowerBound), timeMap.snapped($0.upperBound)] }
        return Set(project.splits + ends).sorted()
    }
}
