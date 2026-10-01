//
//  ContentFilterRulesTests.swift
//  RecoTests
//
//  Created by Joshua Sattler on 30.08.26.
//

import Testing
import CoreGraphics
@testable import Reco

/// Tests for the pure window classification rules behind the content filters.
@MainActor
struct ContentFilterRulesTests {

    // MARK: - Fixtures

    private static let ownBundleID = "com.diip3sh.Reco"

    private func visibility(
        wallpaper: Bool = true,
        dock: Bool = true,
        reco: Bool = true
    ) -> ContentVisibility {
        ContentVisibility(
            showWallpaper: wallpaper,
            showDock: dock,
            showReco: reco,
            ownBundleID: Self.ownBundleID
        )
    }

    private let wallpaper = CapturableWindow(id: 1, bundleID: "com.apple.dock", title: "Wallpaper-1")
    private let dock = CapturableWindow(id: 2, bundleID: "com.apple.dock", title: "Dock")
    private let backstop = CapturableWindow(id: 3, bundleID: "com.apple.WindowManager", title: "Backstop Window")
    private let ownWindow = CapturableWindow(id: 4, bundleID: ContentFilterRulesTests.ownBundleID, title: "Reco")
    private let otherApp = CapturableWindow(id: 5, bundleID: "com.apple.Safari", title: "Safari")

    private var allWindows: [CapturableWindow] {
        [wallpaper, dock, backstop, ownWindow, otherApp]
    }

    private func excluded(_ visibility: ContentVisibility) -> Set<CGWindowID> {
        Set(ContentFilterRules.excludedWindowIDs(from: allWindows, visibility: visibility))
    }

    private func excepted(_ visibility: ContentVisibility) -> Set<CGWindowID> {
        Set(ContentFilterRules.dockExceptionWindowIDs(from: allWindows, visibility: visibility))
    }

    // MARK: - requiresRebuild

    @Test func requiresNoRebuildWhenEverythingIsShown() {
        #expect(ContentFilterRules.requiresRebuild(visibility: visibility()) == false)
    }

    @Test(arguments: [
        (false, true, true),
        (true, false, true),
        (true, true, false),
        (false, false, false)
    ])
    func requiresRebuildWhenAnythingIsHidden(wallpaper: Bool, dock: Bool, reco: Bool) {
        let hidden = visibility(wallpaper: wallpaper, dock: dock, reco: reco)
        #expect(ContentFilterRules.requiresRebuild(visibility: hidden))
    }

    // MARK: - Display Capture

    @Test func displayExcludesNothingWhenEverythingIsShown() {
        #expect(excluded(visibility()).isEmpty)
    }

    @Test func displayExcludesWallpaperAndBackstopWhenWallpaperIsHidden() {
        #expect(excluded(visibility(wallpaper: false)) == [wallpaper.id, backstop.id])
    }

    @Test func displayExcludesDockOnlyWhenDockIsHidden() {
        #expect(excluded(visibility(dock: false)) == [dock.id])
    }

    @Test func displayExcludesOwnWindowsWhenRecoIsHidden() {
        #expect(excluded(visibility(reco: false)) == [ownWindow.id])
    }

    @Test func displayExcludesWallpaperAndDockTogether() {
        #expect(excluded(visibility(wallpaper: false, dock: false)) == [wallpaper.id, dock.id, backstop.id])
    }

    @Test func displayExcludesWallpaperAndOwnWindows() {
        #expect(excluded(visibility(wallpaper: false, reco: false)) == [wallpaper.id, backstop.id, ownWindow.id])
    }

    @Test func displayExcludesDockAndOwnWindows() {
        #expect(excluded(visibility(dock: false, reco: false)) == [dock.id, ownWindow.id])
    }

    @Test func displayExcludesEverythingHidden() {
        let ids = excluded(visibility(wallpaper: false, dock: false, reco: false))
        #expect(ids == [wallpaper.id, dock.id, backstop.id, ownWindow.id])
    }

    @Test func displayNeverExcludesOtherApplications() {
        let ids = excluded(visibility(wallpaper: false, dock: false, reco: false))
        #expect(ids.contains(otherApp.id) == false)
    }

    // MARK: - Backstop

    @Test func backstopIsExcludedRegardlessOfOwner() {
        let windows = [
            CapturableWindow(id: 10, bundleID: "com.apple.dock", title: "Backstop"),
            CapturableWindow(id: 11, bundleID: "com.apple.WindowServer", title: "Backstop"),
            CapturableWindow(id: 12, bundleID: "", title: "Some Backstop Layer")
        ]

        let ids = ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(wallpaper: false))
        #expect(Set(ids) == [10, 11, 12])
    }

    @Test func backstopIsKeptWhenWallpaperIsShown() {
        let ids = ContentFilterRules.excludedWindowIDs(from: [backstop], visibility: visibility(dock: false))
        #expect(ids.isEmpty)
    }

    // MARK: - Wallpaper vs. Dock Split

    @Test func dockOwnedWindowsAreSplitByTitlePrefix() {
        let windows = [
            CapturableWindow(id: 20, bundleID: "com.apple.dock", title: "Wallpaper-2"),
            CapturableWindow(id: 21, bundleID: "com.apple.dock", title: "Dock")
        ]

        #expect(ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(wallpaper: false)) == [20])
        #expect(ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(dock: false)) == [21])
    }

    // MARK: - Application Capture

    @Test func applicationIncludesDockWhenAnySurfaceIsShown() {
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility()))
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility(wallpaper: false)))
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility(dock: false)))
    }

    @Test func applicationOmitsDockWhenBothSurfacesAreHidden() {
        let onBlack = visibility(wallpaper: false, dock: false)
        #expect(ContentFilterRules.includesDockApplication(visibility: onBlack) == false)
        #expect(excepted(onBlack).isEmpty)
    }

    @Test func applicationExceptsNothingWhenEverythingIsShown() {
        #expect(excepted(visibility()).isEmpty)
    }

    @Test func applicationExceptsWallpaperAndBackstopWhenWallpaperIsHidden() {
        #expect(excepted(visibility(wallpaper: false)) == [wallpaper.id, backstop.id])
    }

    @Test func applicationExceptsDockOnlyWhenDockIsHidden() {
        #expect(excepted(visibility(dock: false)) == [dock.id])
    }

    /// `showReco` is a display-capture concern: the picker excludes Reco
    /// from application selections, so it never reaches the exception list.
    @Test func applicationIgnoresRecoVisibility() {
        #expect(excepted(visibility(reco: false)).isEmpty)
        #expect(excepted(visibility(wallpaper: false, reco: false)) == [wallpaper.id, backstop.id])
        #expect(excepted(visibility(dock: false, reco: false)) == [dock.id])
    }

    @Test func applicationNeverExceptsTheCapturedApplication() {
        let ids = excepted(visibility(wallpaper: false))
        #expect(ids.contains(otherApp.id) == false)
    }
}
