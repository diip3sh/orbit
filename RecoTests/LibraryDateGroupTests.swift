//
//  LibraryDateGroupTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct LibraryDateGroupTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Thursday 2026-10-01 12:00 UTC; the week began Monday 09-28, the last on 09-21
    private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func item(_ name: String, _ date: Date) -> LibraryItem {
        LibraryItem(url: URL(filePath: "/r/\(name).png"), kind: .screenshot, date: date)
    }

    @Test func itemsFallIntoTheirGroupsNewestFirst() {
        let now = date(10, 1, hour: 12)
        let items = [
            item("august", date(8, 3)), item("last-week", date(9, 23)), item("today-early", date(10, 1, hour: 0)),
            item("yesterday", date(9, 30, hour: 23)), item("earlier", date(9, 28)), item("today", date(10, 1)),
            item("sept", date(9, 12)), item("last-year", date(12, 31, year: 2025))
        ]

        let groups = LibraryDateGroup.groups(of: items, now: now, calendar: calendar)

        #expect(groups.map(\.title) == ["Today", "Yesterday", "Earlier This Week", "Last Week", "September 2026", "August 2026", "December 2025"])
        #expect(groups.map { $0.items.map(\.name) } == [
            ["today", "today-early"], ["yesterday"], ["earlier"], ["last-week"], ["sept"], ["august"], ["last-year"]
        ])
    }

    @Test func emptyGroupsAreLeftOut() {
        let groups = LibraryDateGroup.groups(of: [item("a", date(10, 1))], now: date(10, 1, hour: 12), calendar: calendar)
        #expect(groups.map(\.title) == ["Today"])
        #expect(LibraryDateGroup.groups(of: [], now: .now, calendar: calendar).isEmpty)
    }

    @Test func onAMondayYesterdayIsLastWeeksSunday() {
        // Monday 2026-09-28: Sunday the 27th is yesterday, the 23rd last week, so no "Earlier This Week"
        let groups = LibraryDateGroup.groups(
            of: [item("sunday", date(9, 27)), item("wednesday", date(9, 23)), item("today", date(9, 28))],
            now: date(9, 28, hour: 12), calendar: calendar
        )
        #expect(groups.map(\.title) == ["Today", "Yesterday", "Last Week"])
    }

    @Test func theDateBeingReadIsTheLastOnePastTheTopOfTheGrid() {
        let groups = LibraryDateGroup.groups(
            of: [item("today", date(10, 1)), item("sept", date(9, 12)), item("august", date(8, 3))],
            now: date(10, 1, hour: 12), calendar: calendar
        )
        #expect(groups.map(\.title) == ["Today", "September 2026", "August 2026"])
        // 16 pt is where a header counts as read, the grid's own top padding
        let tops: [String: CGFloat] = ["Today": -300, "September 2026": -40, "August 2026": 260]

        #expect(LibraryDateGroup.active(in: groups, headerTops: tops, topLine: 16) == "September 2026")
        // At the top of the grid, before anything has scrolled
        #expect(LibraryDateGroup.active(in: groups, headerTops: ["Today": 16, "September 2026": 700], topLine: 16) == "Today")
        // The last group's header at the line
        #expect(LibraryDateGroup.active(in: groups, headerTops: tops, topLine: 300) == "August 2026")
    }

    @Test func aDateTheGridHasntBuiltYetIsSkipped() {
        let groups = LibraryDateGroup.groups(
            of: [item("today", date(10, 1)), item("sept", date(9, 12)), item("august", date(8, 3))],
            now: date(10, 1, hour: 12), calendar: calendar
        )

        // Nothing measured yet: the first date
        #expect(LibraryDateGroup.active(in: groups, headerTops: [:], topLine: 16) == "Today")
        // Only the ones below the fold are up: the first of those
        #expect(LibraryDateGroup.active(in: groups, headerTops: ["September 2026": 400, "August 2026": 900], topLine: 16) == "September 2026")
        // A section with nothing in it has no date
        #expect(LibraryDateGroup.active(in: [], headerTops: [:], topLine: 16) == nil)
    }
}
