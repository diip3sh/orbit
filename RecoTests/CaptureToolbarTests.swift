//
//  CaptureToolbarTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

@MainActor
struct CaptureToolbarTests {

    private let defaults = TemporaryDefaults()

    private func makeViewModel() -> CaptureToolbarViewModel {
        let recorder = RecorderViewModel()
        let screenshots = ScreenshotController(settings: recorder.settings, notificationService: recorder.notificationService)
        return CaptureToolbarViewModel(recorder: recorder, screenshots: screenshots, defaults: defaults.make())
    }

    @Test func modesAreInTheSystemToolbarsOrder() {
        #expect(CaptureToolbarMode.allCases == [.captureScreen, .captureWindow, .captureArea, .recordScreen, .recordWindow, .recordArea])
        #expect(CaptureToolbarMode.allCases.map(\.records) == [false, false, false, true, true, true])
    }

    @Test func theActionSaysWhatItDoes() {
        #expect(CaptureToolbarMode.captureWindow.actionTitle == "Capture")
        #expect(CaptureToolbarMode.recordArea.actionTitle == "Record")
    }

    @Test func aSelectionMadeElsewhereShowsAsItsRecordingMode() {
        #expect(CaptureToolbarMode.recording(isArea: true, isDisplay: true) == .recordArea)
        #expect(CaptureToolbarMode.recording(isArea: false, isDisplay: true) == .recordScreen)
        #expect(CaptureToolbarMode.recording(isArea: false, isDisplay: false) == .recordWindow)
    }

    @Test func startsOnRecordAreaAndRemembersTheMode() {
        let suite = defaults.make()
        let recorder = RecorderViewModel()
        let screenshots = ScreenshotController(settings: recorder.settings, notificationService: recorder.notificationService)

        let first = CaptureToolbarViewModel(recorder: recorder, screenshots: screenshots, defaults: suite)
        #expect(first.mode == .recordArea)
        first.select(.recordWindow)
        first.select(.captureScreen)

        let second = CaptureToolbarViewModel(recorder: recorder, screenshots: screenshots, defaults: suite)
        #expect(second.mode == .recordWindow)
        second.open(records: false)
        #expect(second.mode == .captureScreen)
    }

    @Test func screenshotsAndRecordingsOpenTheirOwnToolbar() {
        let viewModel = makeViewModel()
        viewModel.open(records: false)
        #expect(viewModel.mode == .captureArea)
        viewModel.select(.captureWindow)
        viewModel.open(records: true)
        #expect(viewModel.mode == .recordArea)
        viewModel.open(records: false)
        #expect(viewModel.mode == .captureWindow)
    }

    @Test func eitherKindOfActionCanRunWhenIdle() {
        let viewModel = makeViewModel()
        #expect(viewModel.canPerformAction)
        viewModel.select(.captureScreen)
        #expect(viewModel.canPerformAction)
    }

    // MARK: - Cancelling

    /// Esc and the close control reach the innermost thing open, so a picker goes on its own and the
    /// toolbar only with the next press
    @Test func theCloseControlClosesWhatIsOpenFirst() async {
        let viewModel = makeViewModel()
        var hides: [Bool] = []
        viewModel.onHide = { hides.append($0) }

        await viewModel.pick(.recordWindow)
        #expect(viewModel.sources.isOpen)
        await viewModel.cancel()

        #expect(!viewModel.sources.isOpen)
        #expect(hides.isEmpty)

        // Nothing left open: the toolbar goes
        await viewModel.cancel()
        #expect(hides == [true])
    }

    /// Choosing a mode on the bar opens what records it, so Record isn't a step on the way to the picker
    @Test func choosingARecordingModeOpensWhatRecordsIt() async {
        let viewModel = makeViewModel()

        await viewModel.pick(.recordWindow)
        #expect(viewModel.sources.kind == .window)

        await viewModel.pick(.recordScreen)
        #expect(viewModel.sources.kind == .display)

        // A screenshot only switches: Capture commits, so nothing opens
        await viewModel.pick(.captureWindow)
        #expect(!viewModel.sources.isOpen)
        #expect(viewModel.mode == .captureWindow)
    }

    // MARK: - Placement

    private let visibleFrame = CGRect(x: 0, y: 80, width: 1440, height: 795)
    private let bar = CGSize(width: 600, height: 52)

    /// The window is centred on the bar and reaches `margin` below it, however much taller it is with the
    /// picker drawn above the bar in it
    @Test func theBarSitsCentredAtTheBottomOfItsWindow() {
        let window = CGSize(width: 920, height: 480)
        let barOrigin = CGPoint(x: 400, y: 96)
        let origin = CaptureToolbarPlacement.windowOrigin(for: barOrigin, windowSize: window, barSize: bar, margin: 12)

        #expect(origin == CGPoint(x: 240, y: 84))
        #expect(origin.x + window.width / 2 == barOrigin.x + bar.width / 2)
        #expect(CaptureToolbarPlacement.barOrigin(inWindow: CGRect(origin: origin, size: window), barSize: bar, margin: 12) == barOrigin)
    }

    @Test func homeIsBottomCentreAboveTheDock() {
        let home = CaptureToolbarPlacement.home(size: bar, in: visibleFrame)
        #expect(home == CGPoint(x: 420, y: 80 + CaptureToolbarPlacement.bottomMargin))
    }

    @Test func aDragFollowsInsideAndResistsPastTheEdge() {
        let inside = CGPoint(x: 300, y: 400)
        #expect(CaptureToolbarPlacement.dragged(inside, size: bar, in: visibleFrame) == inside)

        let past = CaptureToolbarPlacement.dragged(CGPoint(x: -200, y: 400), size: bar, in: visibleFrame)
        #expect(past.x < CaptureToolbarPlacement.edgeMargin)
        #expect(past.x > -200)
    }

    @Test func aSlowReleaseStaysWhereDropped() {
        let dropped = CGPoint(x: 100, y: 500)
        #expect(CaptureToolbarPlacement.resting(dropped, velocity: .zero, size: bar, in: visibleFrame) == dropped)
    }

    @Test func aReleaseNearHomeGoesHome() {
        let home = CaptureToolbarPlacement.home(size: bar, in: visibleFrame)
        let near = CGPoint(x: home.x + 30, y: home.y + 20)
        #expect(CaptureToolbarPlacement.resting(near, velocity: .zero, size: bar, in: visibleFrame) == home)
    }

    @Test func aFlickComesToRestInsideTheScreen() {
        let rest = CaptureToolbarPlacement.resting(CGPoint(x: 100, y: 500), velocity: CGVector(dx: 0, dy: 4000), size: bar, in: visibleFrame)
        #expect(rest.y == visibleFrame.maxY - CaptureToolbarPlacement.edgeMargin - bar.height)
    }

    @Test func aCancelledSelectionLeavesTheModeAlone() {
        let viewModel = makeViewModel()
        viewModel.select(.recordWindow)
        viewModel.selectionDidChange()
        #expect(viewModel.mode == .recordWindow)
    }

    // MARK: - Tooltip placement

    @Test func aTooltipSitsAboveTheBarCentredOnTheControl() {
        let bar = CGRect(x: 100, y: 80, width: 600, height: 76)
        let rect = CaptureToolbarPlacement.rectAbove(
            barFrame: bar, size: CGSize(width: 100, height: 24), midX: 400, in: visibleFrame
        )
        #expect(rect.midX == 400)
        #expect(rect.minY == bar.maxY + CaptureToolbarPlacement.tooltipGap)
    }

    @Test func aTooltipDropsBelowTheBarWhenNoRoomAbove() {
        let bar = CGRect(x: 100, y: visibleFrame.maxY - 76, width: 600, height: 76)
        let rect = CaptureToolbarPlacement.rectAbove(
            barFrame: bar, size: CGSize(width: 100, height: 24), midX: 400, in: visibleFrame
        )
        #expect(rect.maxY == bar.minY - CaptureToolbarPlacement.tooltipGap)
    }

    @Test func aTooltipStaysInsideTheScreensEdges() {
        let bar = CGRect(x: 0, y: 80, width: 600, height: 76)
        let size = CGSize(width: 200, height: 24)
        let left = CaptureToolbarPlacement.rectAbove(barFrame: bar, size: size, midX: visibleFrame.minX, in: visibleFrame)
        #expect(left.minX == visibleFrame.minX + CaptureToolbarPlacement.edgeMargin)
        let right = CaptureToolbarPlacement.rectAbove(barFrame: bar, size: size, midX: visibleFrame.maxX, in: visibleFrame)
        #expect(right.maxX == visibleFrame.maxX - CaptureToolbarPlacement.edgeMargin)
    }

    // MARK: - Source picker

    @Test func onlyOrdinaryWindowsOfOtherAppsAreOffered() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        func offers(layer: Int = 0, frame: CGRect = frame, bundleID: String? = "com.apple.Safari", isOnScreen: Bool = true) -> Bool {
            CaptureSource.offers(layer: layer, frame: frame, bundleID: bundleID, isOnScreen: isOnScreen, ownBundleID: "com.diip3sh.Reco")
        }
        #expect(offers())
        #expect(!offers(layer: 25))
        #expect(!offers(frame: CGRect(x: 0, y: 0, width: 30, height: 600)))
        #expect(!offers(bundleID: "com.diip3sh.Reco"))
        #expect(!offers(bundleID: nil))
        #expect(!offers(isOnScreen: false))
    }

    @Test func anUntitledWindowIsNamedByItsApp() {
        #expect(CaptureSource.title(windowTitle: "Inbox", appName: "Mail") == "Inbox")
        #expect(CaptureSource.title(windowTitle: " ", appName: "Mail") == "Mail")
        #expect(CaptureSource.title(windowTitle: nil, appName: "Mail") == "Mail")
    }

    @Test func theGridShowsFourAcrossAndTwoRows() {
        let one = CaptureSourceGrid.size(for: 1)
        let four = CaptureSourceGrid.size(for: 4)
        let five = CaptureSourceGrid.size(for: 5)
        let twenty = CaptureSourceGrid.size(for: 20)
        #expect(one.width < four.width)
        #expect(four.width == five.width)
        #expect(five.height > four.height)
        #expect(twenty == five)
        #expect(one.height == four.height)
        #expect(CaptureSourceGrid.messageSize.width == CaptureSourceGrid.size(for: 2).width)
    }

    @Test func aClosedPickerHoldsNothing() {
        let viewModel = makeViewModel()
        viewModel.select(.recordWindow)
        viewModel.sources.open(.window)
        #expect(viewModel.sources.isOpen)
        viewModel.sources.cancel()
        #expect(!viewModel.sources.isOpen)
        #expect(viewModel.sources.sources == nil)
    }

    /// The panel is held back until there is something to put in it, so a warm open presents the
    /// finished tiles instead of a spinner that is replaced a moment later
    @Test func aPickerWaitsForItsSourcesBeforeItShowsAnything() {
        let viewModel = makeViewModel()
        viewModel.select(.recordWindow)

        viewModel.sources.open(.window)
        #expect(!viewModel.sources.hasSomethingToShow)

        viewModel.sources.cancel()
        #expect(!viewModel.sources.hasSomethingToShow)
    }

    // MARK: - Tooltips

    @Test func aTooltipFollowsWhatItsControlDoes() {
        let tooltips = CaptureToolbarTooltips()
        #expect(!tooltips.isShown)

        tooltips.hover("Pause Recording", at: 300)
        #expect(tooltips.target == CaptureToolbarTooltips.Target(text: "Pause Recording", midX: 300))
        #expect(tooltips.isShown)

        tooltips.retext("Resume Recording")
        #expect(tooltips.target == CaptureToolbarTooltips.Target(text: "Resume Recording", midX: 300))

        tooltips.unhover(immediately: true)
        #expect(!tooltips.isShown)
    }

    @Test func movingToANeighbourSwapsTheTooltipInPlace() async throws {
        let tooltips = CaptureToolbarTooltips()
        tooltips.hover("Microphone: On", at: 300)
        tooltips.unhover()
        // Still up while the pointer crosses to the next control, which shows at once
        #expect(tooltips.isShown)
        #expect(tooltips.appearDelay() == .zero)
        tooltips.hover("Camera: Off", at: 340)

        try await Task.sleep(for: CaptureToolbarTooltips.switchGrace * 3)
        #expect(tooltips.isShown)
        #expect(tooltips.target == CaptureToolbarTooltips.Target(text: "Camera: Off", midX: 340))
    }

    @Test func leavingTheBarHidesTheTooltipAfterTheGrace() async throws {
        let tooltips = CaptureToolbarTooltips()
        tooltips.hover("Close", at: 30)
        tooltips.unhover()
        #expect(tooltips.isShown)
        // The main actor runs late under a parallel test run, so wait for the hide rather than a fixed time
        let deadline = ContinuousClock.now + .seconds(5)
        while tooltips.isShown, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!tooltips.isShown)
    }

    @Test func theFirstTooltipWaitsForARestAndTheNextShortlyAfterDoesnt() {
        let tooltips = CaptureToolbarTooltips()
        #expect(tooltips.appearDelay() == CaptureToolbarTooltips.restDelay)

        tooltips.hover("Close", at: 30)
        tooltips.unhover(immediately: true)
        #expect(tooltips.appearDelay() == .zero)
        #expect(tooltips.appearDelay(now: .now + CaptureToolbarTooltips.warmPeriod * 2) == CaptureToolbarTooltips.restDelay)
    }

    @Test func aRetextIsIgnoredWithNothingHovered() {
        let tooltips = CaptureToolbarTooltips()
        tooltips.retext("Something")
        #expect(tooltips.target == nil)
        #expect(!tooltips.isShown)
    }

    @Test func aDragHidesTheTooltipAndKeepsItAway() {
        let tooltips = CaptureToolbarTooltips()
        tooltips.hover("Pause Recording", at: 300)
        #expect(tooltips.isShown)

        tooltips.setDragging(true)
        #expect(!tooltips.isShown)

        tooltips.hover("Resume Recording", at: 300)
        #expect(!tooltips.isShown)

        tooltips.setDragging(false)
        tooltips.hover("Pause Recording", at: 300)
        #expect(tooltips.isShown)
    }
}
