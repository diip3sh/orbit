//
//  SpeedRange.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

/// A part of the recording played faster: `rate` source seconds per output second. Times are source seconds.
nonisolated struct SpeedRange: Codable, Equatable, Sendable {
    var range: Range<Double>
    var rate: Double

    /// The speeds the transport's menu offers.
    static let rates = [1, 1.5, 2, 3, 4, 8]

    /// "4×", "1.5×".
    static func label(for rate: Double) -> String {
        "\(rate.formatted(.number.precision(.fractionLength(0...1))))×"
    }
}
