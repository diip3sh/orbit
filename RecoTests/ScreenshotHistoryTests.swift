//
//  ScreenshotHistoryTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

@MainActor
struct ScreenshotHistoryTests {

    private let root = URL.temporaryDirectory.appending(path: "ScreenshotHistoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let defaults = TemporaryDefaults()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    @Test(arguments: [
        (ScreenshotHistoryRetention.week, 7), (.month, 30), (.threeMonths, 90)
    ])
    func aFileExpiresJustAfterTheRetention(retention: ScreenshotHistoryRetention, days: Int) {
        let age = TimeInterval(days) * day
        #expect(!ScreenshotHistory.isExpired(created: now - age + 1, now: now, retention: retention))
        #expect(!ScreenshotHistory.isExpired(created: now - age, now: now, retention: retention))
        #expect(ScreenshotHistory.isExpired(created: now - age - 1, now: now, retention: retention))
    }

    @Test func offExpiresEverything() {
        #expect(ScreenshotHistory.isExpired(created: now, now: now, retention: .off))
        #expect(ScreenshotHistory.isExpired(created: now + day, now: now, retention: .off))
    }

    private func populate() throws -> URL {
        let folder = root.appending(path: "History", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, days) in [("Reco_Screenshot_old.png", 40.0), ("Reco_Screenshot_new.png", 2), ("notes.txt", 400)] {
            let url = folder.appending(path: name)
            try Data().write(to: url)
            try FileManager.default.setAttributes([.creationDate: now - days * day], ofItemAtPath: url.path)
        }
        return folder
    }

    private func names(in folder: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
    }

    @Test func pruningDeletesOldScreenshotsOnlyAndLeavesOtherFiles() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try populate()

        await ScreenshotHistory.prune(retention: .month, now: now, in: folder)

        #expect(try names(in: folder) == ["Reco_Screenshot_new.png", "notes.txt"])
    }

    @Test func pruningWithHistoryOffDeletesEveryScreenshot() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try populate()

        await ScreenshotHistory.prune(retention: .off, now: now, in: folder)

        #expect(try names(in: folder) == ["notes.txt"])
    }

    @Test func pruningAFolderThatDoesntExistDoesNothing() async {
        await ScreenshotHistory.prune(retention: .week, in: root.appending(path: "none"))
    }

    @Test func clearingEmptiesTheFolderAndRemovingDeletesOne() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try populate()

        await ScreenshotHistory.remove(named: "Reco_Screenshot_new.png", in: folder)
        await ScreenshotHistory.remove(named: "Reco_Screenshot_missing.png", in: folder)
        #expect(try names(in: folder) == ["Reco_Screenshot_old.png", "notes.txt"])

        await ScreenshotHistory.clear(in: folder)
        #expect(try names(in: folder).isEmpty)
    }

    @Test func retentionDefaultsToAMonthAndIsRemembered() {
        let suite = defaults.make()
        let settings = SettingsStore(defaults: suite)
        #expect(settings.screenshotHistoryRetention == .month)

        settings.screenshotHistoryRetention = .threeMonths
        #expect(SettingsStore(defaults: suite).screenshotHistoryRetention == .threeMonths)
        #expect(suite.string(forKey: "screenshotHistoryRetention") == "threeMonths")
    }
}
