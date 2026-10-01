//
//  ContainerMigrationTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct ContainerMigrationTests {

    private let defaults = TemporaryDefaults()
    private let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    private let bundleID = "com.diip3sh.RecoTests.migration.\(UUID().uuidString)"

    private var destination: URL { home.appending(path: "Library/Application Support/\(bundleID)") }
    private var data: URL { home.appending(path: "Library/Containers/\(bundleID)/Data/Library") }

    private func makeContainer(preferences: [String: Any], files: [String: String] = [:]) throws {
        try FileManager.default.createDirectory(at: data.appending(path: "Preferences"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: data.appending(path: "Application Support"), withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0)
        try plist.write(to: data.appending(path: "Preferences/\(bundleID).plist"))
        for (name, text) in files {
            try Data(text.utf8).write(to: data.appending(path: "Application Support/\(name)"))
        }
    }

    private func run(_ suite: UserDefaults) {
        ContainerMigration.run(home: home, defaults: suite, bundleID: bundleID, domain: defaults.domains.last, destination: destination)
    }

    // MARK: - Pure rules

    @Test func preferencesAreCopiedOnlyWhenTheContainerHasSomeAndTheAppHasNone() {
        let container: [String: Any] = ["agentBridgeToken": "t"]

        #expect(ContainerMigration.preferencesToCopy(container: container, current: nil)?["agentBridgeToken"] as? String == "t")
        #expect(ContainerMigration.preferencesToCopy(container: container, current: [:]) != nil)
        #expect(ContainerMigration.preferencesToCopy(container: container, current: ["a": 1]) == nil)
        #expect(ContainerMigration.preferencesToCopy(container: [:], current: nil) == nil)
        #expect(ContainerMigration.preferencesToCopy(container: nil, current: nil) == nil)
    }

    @Test func filesAreCopiedOnlyWhereTheyAreMissing() {
        let existing: Set<String> = ["WebScript.json"]

        let names = ContainerMigration.filesToCopy(names: ["WebScript.json", "Other"]) { existing.contains($0) }

        #expect(names == ["Other"])
    }

    // MARK: - Run

    @Test func movesSettingsAndFilesOverOnce() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try makeContainer(preferences: ["agentBridgeToken": "secret", "frameRate": 30], files: ["WebScript.json": "{}"])
        let suite = defaults.make()

        run(suite)

        #expect(suite.string(forKey: "agentBridgeToken") == "secret")
        #expect(suite.integer(forKey: "frameRate") == 30)
        #expect(try String(contentsOf: destination.appending(path: "WebScript.json"), encoding: .utf8) == "{}")

        // The app now has settings of its own, so a later change in the container is ignored
        try makeContainer(preferences: ["agentBridgeToken": "other"], files: ["WebScript.json": "[]"])
        run(suite)
        #expect(suite.string(forKey: "agentBridgeToken") == "secret")
        #expect(try String(contentsOf: destination.appending(path: "WebScript.json"), encoding: .utf8) == "{}")
    }

    @Test func existingFilesAndSymbolicLinksAreLeftAlone() throws {
        defer { try? FileManager.default.removeItem(at: home) }
        try makeContainer(preferences: ["a": 1], files: ["Keep": "container", "New": "container"])
        try FileManager.default.createSymbolicLink(
            at: data.appending(path: "Application Support/Link"), withDestinationURL: URL(filePath: "/etc/hosts")
        )
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("mine".utf8).write(to: destination.appending(path: "Keep"))

        run(defaults.make())

        #expect(try String(contentsOf: destination.appending(path: "Keep"), encoding: .utf8) == "mine")
        #expect(try String(contentsOf: destination.appending(path: "New"), encoding: .utf8) == "container")
        #expect(!FileManager.default.fileExists(atPath: destination.appending(path: "Link").path(percentEncoded: false)))
    }

    @Test func doesNothingWithoutAContainer() {
        let suite = defaults.make()

        run(suite)

        #expect(suite.persistentDomain(forName: defaults.domains[0]) == nil)
        #expect(!FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)))
    }
}
