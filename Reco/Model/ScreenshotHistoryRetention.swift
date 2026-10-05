//
//  ScreenshotHistoryRetention.swift
//  Reco
//

import Foundation

/// How long screenshots nobody saved are kept in the history before they're deleted
nonisolated enum ScreenshotHistoryRetention: String, CaseIterable, Identifiable, Sendable {
    case off
    case week
    case month
    case threeMonths

    var id: String { rawValue }

    /// Nil when nothing is kept
    var days: Int? {
        switch self {
        case .off: nil
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        }
    }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .week: "1 Week"
        case .month: "1 Month"
        case .threeMonths: "3 Months"
        }
    }
}
