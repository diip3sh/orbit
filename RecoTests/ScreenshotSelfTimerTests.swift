//
//  ScreenshotSelfTimerTests.swift
//  RecoTests
//

import Testing
@testable import Reco

@MainActor
struct ScreenshotSelfTimerTests {

    private let defaults = TemporaryDefaults()

    /// A controller whose timer's seconds pass at once, after `tick` runs for each
    private func makeController(timer seconds: CountdownDuration, tick: @escaping @MainActor () -> Void = {}) -> ScreenshotController {
        let settings = SettingsStore(defaults: defaults.make())
        settings.screenshotTimer = seconds
        return ScreenshotController(
            settings: settings,
            notificationService: NotificationService(settings: settings),
            timer: RecordingCountdown { tick() }
        )
    }

    @Test func capturesAtOnceWhenTheTimerIsOff() async {
        var captured = false
        await makeController(timer: .off).afterSelfTimer { captured = true }
        #expect(captured)
    }

    @Test func capturesOnceTheTimerHasCountedDown() async {
        var ticks = 0
        var captured = false
        let controller = makeController(timer: .three) { ticks += 1 }
        await controller.afterSelfTimer { captured = true }
        #expect(ticks == 3)
        #expect(captured)
        #expect(!controller.timer.isRunning)
    }

    @Test func cancellingTheTimerCapturesNothing() async {
        var captured = false
        var controller: ScreenshotController?
        controller = makeController(timer: .five) { controller?.cancelSelfTimer() }
        await controller?.afterSelfTimer { captured = true }
        #expect(!captured)
        #expect(controller?.timer.isRunning == false)
    }
}
