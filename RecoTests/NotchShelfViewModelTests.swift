//
//  NotchShelfViewModelTests.swift
//  RecoTests
//

import AppKit
import SwiftUI
import Testing
@testable import Reco

@MainActor
struct NotchShelfViewModelTests {

    private let root = URL.temporaryDirectory.appending(path: "NotchShelfTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), leftArea: nil, rightArea: nil)

    /// Waits for nothing, but ends when cancelled like a real sleep, and keeps what it was asked for
    @MainActor
    private final class Sleeps {
        var durations: [Duration] = []
        var onSleep: (() -> Void)?

        func sleep(_ duration: Duration) async throws {
            durations.append(duration)
            onSleep?()
            await Task.yield()
            try Task.checkCancellation()
        }
    }

    private func folder(_ name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ names: [(String, Double)], in folder: URL, contents: Data = Data()) throws {
        for (name, age) in names {
            let url = folder.appending(path: name)
            try contents.write(to: url)
            try FileManager.default.setAttributes([.creationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        }
    }

    private func model(
        screenshots: URL? = nil, history: URL? = nil, pasteboard: NSPasteboard = .general, sleeps: Sleeps = Sleeps()
    ) -> NotchShelfViewModel {
        let none = root.appending(path: "none")
        return NotchShelfViewModel(
            geometry: geometry, folders: { (screenshots ?? none, history ?? none) }, pasteboard: pasteboard, sleep: sleeps.sleep
        )
    }

    @Test func restingOnTheShelfOpensItAfterTheDelay() async {
        let sleeps = Sleeps()
        let viewModel = model(sleeps: sleeps)

        let opening = viewModel.pointerEntered()
        #expect(!viewModel.isExpanded)
        await opening.value

        #expect(viewModel.isExpanded)
        #expect(sleeps.durations == [NotchMotion.openDelay])
    }

    @Test func theDelaysAreThreeHundredAndFiveHundredMilliseconds() {
        #expect(NotchMotion.openDelay == .milliseconds(300))
        #expect(NotchMotion.closeDelay == .milliseconds(500))
    }

    @Test func thePointerPeeksAtOnceUntilItOpensOrLeaves() async {
        let viewModel = model()
        #expect(!viewModel.isPeeking)

        let opening = viewModel.pointerEntered()
        #expect(viewModel.isPeeking)
        #expect(!viewModel.isExpanded)

        viewModel.pointerExited()
        #expect(!viewModel.isPeeking)
        await opening.value
        #expect(!viewModel.isExpanded)

        await viewModel.pointerEntered().value
        #expect(viewModel.isExpanded)
        #expect(!viewModel.isPeeking)
    }

    @Test func collapsingEndsThePeekToo() {
        let viewModel = model()
        viewModel.pointerEntered()
        viewModel.collapse()
        #expect(!viewModel.isPeeking)
        #expect(!viewModel.isHovering)
    }

    @Test func leavingBeforeTheDelayEndsKeepsItClosed() async {
        let viewModel = model()

        let opening = viewModel.pointerEntered()
        viewModel.pointerExited()
        await opening.value

        #expect(!viewModel.isExpanded)
    }

    @Test func enteringAgainWhileWaitingDoesntRestartTheDelay() async {
        let sleeps = Sleeps()
        let viewModel = model(sleeps: sleeps)

        let first = viewModel.pointerEntered()
        let second = viewModel.pointerEntered()
        await first.value
        await second.value

        #expect(sleeps.durations.count == 1)
        #expect(viewModel.isExpanded)
    }

    @Test func leavingClosesItAfterAGraceWhichComingBackCancels() async {
        let sleeps = Sleeps()
        let viewModel = model(sleeps: sleeps)
        await viewModel.pointerEntered().value

        let closing = viewModel.pointerExited()
        viewModel.pointerEntered()
        await closing.value
        #expect(viewModel.isExpanded)

        await viewModel.pointerExited().value
        #expect(!viewModel.isExpanded)
        // The cancelled close slept too
        #expect(sleeps.durations == [NotchMotion.openDelay, NotchMotion.closeDelay, NotchMotion.closeDelay])
    }

    @Test func collapsingClosesAtOnceAndDropsAPendingOpen() async {
        let viewModel = model()
        await viewModel.pointerEntered().value
        viewModel.collapse()
        #expect(!viewModel.isExpanded)

        let opening = viewModel.pointerEntered()
        viewModel.collapse()
        await opening.value
        #expect(!viewModel.isExpanded)
    }

    @Test func listsOnlyScreenshotsNewestFirstFromBothFoldersAndCapsThem() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = try folder("Desktop")
        let history = try folder("History")
        try write([("Reco_Screenshot_saved.png", 50), ("Screenshot 2026.png", 1), ("Reco_1.mov", 2), ("notes.txt", 3)], in: desktop)
        try write([("Reco_Screenshot_kept.png", 10), ("Reco_Screenshot_new.png", 5)], in: history)
        let viewModel = model(screenshots: desktop, history: history)
        #expect(viewModel.items == nil)

        await viewModel.reload()

        #expect(viewModel.items?.map(\.name) == ["Reco_Screenshot_new", "Reco_Screenshot_kept", "Reco_Screenshot_saved"])

        let many = try folder("Many")
        try write((0..<30).map { ("Reco_Screenshot_\($0).png", Double($0)) }, in: many)
        let capped = model(screenshots: many)
        await capped.reload()
        #expect(capped.items?.count == NotchShelfViewModel.maximumItems)
        #expect(capped.items?.first?.name == "Reco_Screenshot_0")
    }

    @Test func openingReadsTheScreenshots() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = try folder("Desktop")
        try write([("Reco_Screenshot_a.png", 1)], in: desktop)
        let viewModel = model(screenshots: desktop)

        await viewModel.pointerEntered().value

        #expect(viewModel.items?.count == 1)
    }

    private func png() throws -> Data {
        try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
                                      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .representation(using: .png, properties: [:]))
    }

    @Test func readingTheScreenshotsDrawsTheirPicturesBeforeShowingThem() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = try folder("Desktop")
        let history = try folder("History")
        try write([("Reco_Screenshot_a.png", 2), ("Reco_Screenshot_b.png", 1)], in: desktop, contents: png())
        try write([("Reco_Screenshot_c.png", 3)], in: history, contents: png())
        let viewModel = model(screenshots: desktop, history: history)

        await viewModel.reload()

        let items = try #require(viewModel.items)
        #expect(items.count == 3)
        #expect(items.allSatisfy { viewModel.thumbnails[$0.url]?.width == 4 })
    }

    @Test func aSecondReadKeepsThePicturesItHasAndLetsGoOfTheRest() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = try folder("Desktop")
        try write([("Reco_Screenshot_a.png", 2), ("Reco_Screenshot_b.png", 1)], in: desktop, contents: png())
        let viewModel = model(screenshots: desktop)
        await viewModel.reload()
        let kept = try #require(viewModel.items?.first)
        let gone = try #require(viewModel.items?.last)
        let picture = try #require(viewModel.thumbnails[kept.url])

        try FileManager.default.removeItem(at: gone.url)
        try write([("Reco_Screenshot_new.png", 0)], in: desktop, contents: png())
        await viewModel.reload()

        #expect(viewModel.items?.count == 2)
        #expect(viewModel.thumbnails[kept.url] === picture)
        #expect(viewModel.thumbnails[gone.url] == nil)
        #expect(viewModel.thumbnails.count == 2)
    }

    @Test func thePointerCountsAsOnTheShapeThatIsThereNow() async {
        let viewModel = model()
        #expect(viewModel.activeRect == geometry.collapsed)

        let opening = viewModel.pointerEntered()
        #expect(viewModel.activeRect == geometry.peek)

        await opening.value
        #expect(viewModel.activeRect == geometry.expanded)

        // Away, but not yet closed: still the panel
        let closing = viewModel.pointerExited()
        #expect(viewModel.activeRect == geometry.expanded)
        await closing.value
        #expect(viewModel.activeRect == geometry.collapsed)
    }

    @Test func aFolderThatDoesntExistHasNoScreenshots() async {
        let viewModel = model()
        await viewModel.reload()
        #expect(viewModel.items?.isEmpty == true)
    }

    @Test func copyingPutsThePNGOnThePasteboardAndConfirmsOnTheTileMeanwhile() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = try folder("Desktop")
        let png = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
                                                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .representation(using: .png, properties: [:]))
        try write([("Reco_Screenshot_a.png", 1)], in: desktop, contents: png)
        let pasteboard = NSPasteboard(name: .init("NotchShelfTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let sleeps = Sleeps()
        let viewModel = model(screenshots: desktop, pasteboard: pasteboard, sleeps: sleeps)
        await viewModel.reload()
        let item = try #require(viewModel.items?.first)

        var confirmed: URL?
        sleeps.onSleep = { confirmed = viewModel.copiedURL }
        await viewModel.copy(item)

        #expect(pasteboard.data(forType: .png) == png)
        #expect(confirmed == item.url)
        #expect(sleeps.durations == [NotchShelfViewModel.confirmationDuration])
        #expect(viewModel.copiedURL == nil)
    }

    @Test func copyingAFileThatIsGoneChangesNothing() async {
        let pasteboard = NSPasteboard(name: .init("NotchShelfTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let viewModel = model(pasteboard: pasteboard)

        await viewModel.copy(LibraryItem(url: root.appending(path: "gone.png"), kind: .screenshot, date: .now))

        #expect(pasteboard.data(forType: .png) == nil)
        #expect(viewModel.copiedURL == nil)
    }

    @Test func theShapeFillsItsRectAndItsRadiiAnimateTogether() {
        let rect = CGRect(x: 0, y: 0, width: 560, height: 164)
        var shape = NotchShape(topRadius: NotchMotion.expandedTopRadius, bottomRadius: NotchMotion.expandedBottomRadius)
        #expect(shape.path(in: rect).boundingRect == rect)

        shape.animatableData = AnimatablePair(6, 14)
        #expect(shape.topRadius == 6)
        #expect(shape.bottomRadius == 14)
        #expect(shape.animatableData == AnimatablePair(6, 14))
    }

    @Test func theTopCornersCurveInwardAndTheBottomOnesOutward() {
        let path = NotchShape(topRadius: 19, bottomRadius: 24).path(in: CGRect(x: 0, y: 0, width: 560, height: 164))

        // The sides are inset by the top radius, so just outside them is empty and just inside is black
        #expect(!path.contains(CGPoint(x: 18, y: 80)))
        #expect(path.contains(CGPoint(x: 20, y: 80)))
        #expect(!path.contains(CGPoint(x: 542, y: 80)))
        #expect(path.contains(CGPoint(x: 540, y: 80)))
        // The ear: black along the very top, cut away inside the corner
        #expect(path.contains(CGPoint(x: 10, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 2, y: 10)))
        // The bottom corner is rounded off
        #expect(!path.contains(CGPoint(x: 21, y: 163)))
        #expect(path.contains(CGPoint(x: 60, y: 163)))
    }

    @Test func theRadiiAreClampedToFitThePill() {
        let shape = NotchShape(topRadius: NotchMotion.collapsedTopRadius, bottomRadius: NotchMotion.collapsedBottomRadius)
        let pill = CGRect(x: 0, y: 0, width: 120, height: 8)
        let radii = shape.fittedRadii(in: pill)

        #expect(radii.top == 4)
        #expect(radii.bottom == 4)
        #expect(shape.path(in: pill).boundingRect == pill)

        // The notch is tall enough for them as they are
        let notch = shape.fittedRadii(in: CGRect(x: 0, y: 0, width: 184, height: 32))
        #expect(notch.top == 6)
        #expect(notch.bottom == 14)
    }

    @Test func theNotchSettingIsOffUnlessTurnedOn() {
        let defaults = TemporaryDefaults()
        let suite = defaults.make()
        let settings = SettingsStore(defaults: suite)
        #expect(!settings.showsScreenshotsInNotch)

        settings.showsScreenshotsInNotch = true
        #expect(SettingsStore(defaults: suite).showsScreenshotsInNotch)
    }
}
