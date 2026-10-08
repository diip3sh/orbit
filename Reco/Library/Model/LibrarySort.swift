//
//  LibrarySort.swift
//  Reco
//

import Foundation

/// The order of the Library's grid.
nonisolated enum LibrarySort: CaseIterable, Hashable, Sendable {
    case newestFirst
    case oldestFirst
    case name

    func sorted(_ items: [LibraryItem]) -> [LibraryItem] {
        switch self {
        case .newestFirst: items.sorted { $0.date > $1.date }
        case .oldestFirst: items.sorted { $0.date < $1.date }
        case .name: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// Whether the grid sits under date headers: in name order each date's items are scattered.
    var groupsByDate: Bool {
        self != .name
    }
}
