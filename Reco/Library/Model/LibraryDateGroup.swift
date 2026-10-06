//
//  LibraryDateGroup.swift
//  Reco
//

import Foundation

/// Library items under one date header (spec 0012): Today, Yesterday, Earlier This Week, Last Week,
/// then a month each, newest first.
nonisolated struct LibraryDateGroup: Identifiable, Equatable, Sendable {

    /// Unique: the named ones appear once, and each month has its own title
    let title: String
    let items: [LibraryItem]

    var id: String { title }

    /// `items` by date, newest first and without empty groups. `now` and `calendar` are given so the week's
    /// first day, the time zone and the language are the caller's.
    static func groups(of items: [LibraryItem], now: Date, calendar: Calendar) -> [LibraryDateGroup] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek) ?? thisWeek
        let monthStyle = Date.FormatStyle(date: .omitted, time: .omitted, locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
            .month(.wide).year()

        func groupTitle(of date: Date) -> String {
            switch date {
            case today...: "Today"
            case yesterday...: "Yesterday"
            case thisWeek...: "Earlier This Week"
            case lastWeek...: "Last Week"
            default: date.formatted(monthStyle)
            }
        }

        var groups: [(title: String, items: [LibraryItem])] = []
        for item in items.sorted(by: { $0.date > $1.date }) {
            let title = groupTitle(of: item.date)
            if groups.last?.title == title {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append((title, [item]))
            }
        }
        return groups.map { LibraryDateGroup(title: $0.title, items: $0.items) }
    }

    /// The group being read, by ``id``, from where each header sits below the top of the grid: the last
    /// one that has passed `topLine`, or the first measured one, or the first group.
    ///
    /// A lazy grid measures only the headers it has built, so a group with no entry is one that has
    /// never been on screen and is skipped. A header scrolled off the top keeps the last place it was
    /// measured, which stays in order, so the group at the top is still the last one past the line.
    static func active(in groups: [LibraryDateGroup], headerTops: [String: CGFloat], topLine: CGFloat) -> String? {
        let measured = groups.compactMap { group in headerTops[group.id].map { (id: group.id, top: $0) } }
        return measured.last { $0.top <= topLine }?.id ?? measured.first?.id ?? groups.first?.id
    }
}
