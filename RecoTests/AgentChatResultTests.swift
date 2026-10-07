//
//  AgentChatResultTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentChatResultTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let movie = URL(fileURLWithPath: "/Users/x/Movies/Reco/Reco_Web_1.mov")

    @Test func aMadeTodaySaysTodayWithTheFolder() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 20, minute: 30)))

        let subtitle = AgentChatResult.subtitle(for: movie, created: now, now: now, calendar: calendar)

        #expect(subtitle.hasPrefix("Reco • Today "))
    }

    @Test func anEarlierDayNamesTheDate() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 20, minute: 30)))
        let earlier = try #require(calendar.date(byAdding: .day, value: -3, to: now))

        let subtitle = AgentChatResult.subtitle(for: movie, created: earlier, now: now, calendar: calendar)

        #expect(subtitle.hasPrefix("Reco • ") && !subtitle.contains("Today"))
    }
}
