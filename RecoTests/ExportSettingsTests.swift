//
//  ExportSettingsTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import AppKit
import AVFoundation
import Testing
@testable import Reco

@MainActor
struct ExportSettingsTests {

    @Test func aTransparentCanvasStartsInProResAndOthersInMP4() {
        #expect(ExportSettings.initial(transparentCanvas: true).format == .proRes)
        #expect(ExportSettings.initial(transparentCanvas: false).format == .mp4)
        #expect(ExportSettings.initial(transparentCanvas: false).quality == .socialMedia)
        #expect(ExportSettings.initial(transparentCanvas: false).resolution == nil)
        #expect(ExportSettings.initial(transparentCanvas: false).frameRate == nil)
    }

    @Test func onlyProResOfATransparentCanvasKeepsItAndOnlyAGIFLosesHDR() {
        #expect(ExportSettings(format: .proRes, transparentCanvas: true).keepsTransparency)
        #expect(!ExportSettings(format: .proRes, transparentCanvas: false).keepsTransparency)
        #expect(!ExportSettings(format: .mp4, transparentCanvas: true).keepsTransparency)
        #expect(ExportSettings(format: .mp4).keepsHDR && ExportSettings(format: .proRes).keepsHDR)
        #expect(!ExportSettings(format: .gif).keepsHDR)
    }

    @Test func proResFlavoursFollowTheQualityUnlessTheCanvasIsTransparent() {
        let flavours = ExportQuality.allCases.map { ExportSettings(format: .proRes, quality: $0).proResCodec }
        #expect(flavours == [.proRes422HQ, .proRes422, .proRes422LT, .proRes422Proxy])
        #expect(ExportSettings(format: .proRes, quality: .web, transparentCanvas: true).proResCodec == .proRes4444)
    }

    @Test func aSizeIsOfferedOnlyBelowTheCanvas() {
        #expect(ExportSettings.isAvailable(resolution: 1080, below: 2160))
        #expect(!ExportSettings.isAvailable(resolution: 1080, below: 1080))
        #expect(!ExportSettings.isAvailable(resolution: 2160, below: 1080))
        #expect(ExportSettings.resolutions == [720, 1080, 2160])
    }

    @Test func aFrameRateIsOfferedUpToTheRecordings() {
        let settings = ExportSettings()
        #expect(ExportSettings.frameRates.map { settings.isAvailable(frameRate: $0, recordingRate: 60) } == [true, true, true])
        #expect(ExportSettings.frameRates.map { settings.isAvailable(frameRate: $0, recordingRate: 30) } == [true, true, false])
        #expect(ExportSettings.frameRates.map { settings.isAvailable(frameRate: $0, recordingRate: 29.97) } == [true, true, false])
    }

    @Test func theRecordingsOwnRateIsSelectedAndChoosingItFollowsTheRecording() {
        var settings = ExportSettings()
        #expect(settings.selectedFrameRate(recordingRate: 60) == 60)
        settings.choose(frameRate: 30, recordingRate: 60)
        #expect(settings.frameRate == 30)
        #expect(settings.selectedFrameRate(recordingRate: 60) == 30)
        settings.choose(frameRate: 60, recordingRate: 60)
        #expect(settings.frameRate == nil)
        // Not one of the three
        #expect(settings.selectedFrameRate(recordingRate: 24) == nil)
    }

    @Test func aGIFIsAtMost30FramesPerSecond() {
        var settings = ExportSettings(format: .gif)
        #expect(settings.outputFrameRate(recordingRate: 60) == 30)
        #expect(settings.selectedFrameRate(recordingRate: 60) == 30)
        #expect(!settings.isAvailable(frameRate: 60, recordingRate: 60))
        #expect(settings.isAvailable(frameRate: 30, recordingRate: 60))
        settings.choose(frameRate: 15, recordingRate: 60)
        #expect(settings.outputFrameRate(recordingRate: 60) == 15)
        // Back to MP4 it's the recording's again
        settings = ExportSettings(format: .mp4)
        #expect(settings.outputFrameRate(recordingRate: 60) == 60)
    }

    @Test func aGIFsDelaysAddUpWithoutDrifting() {
        let delays = { (count: Int, rate: Double) in (0..<count).map { GIFEncoder.delay(ofFrame: $0, frameRate: rate) } }

        #expect(delays(6, 30) == [3, 4, 3, 3, 4, 3])
        #expect(delays(30, 30).reduce(0, +) == 100)
        #expect(delays(15, 15).reduce(0, +) == 100)
        #expect(delays(4, 15) == [7, 6, 7, 7])
    }

    @Test func aFrameOfSomethingThatIsntAGIFIsRefused() {
        #expect(GIFMuxer.frame(from: Data("not a gif at all".utf8), delay: 3) == nil)
        #expect(GIFMuxer.frame(from: Data(), delay: 3) == nil)
        #expect(GIFMuxer.header(width: 320, height: 240).starts(with: Data("GIF89a".utf8)))
    }

    @Test func anMP4SizeIsTheTargetBitrateOverTheDuration() throws {
        let size = CGSize(width: 1920, height: 1080)
        let settings = ExportSettings(format: .mp4, quality: .socialMedia)

        // 0.1 bit per pixel at 30 fps, and AAC at 128 kbit/s, for 10 s
        #expect(try #require(settings.videoBitRate(size: size, frameRate: 30)) == 6_220_800)
        #expect(settings.estimatedBytes(size: size, frameRate: 30, duration: 10, hasAudio: true) == 7_936_000)
        #expect(settings.estimatedBytes(size: size, frameRate: 30, duration: 10, hasAudio: false) == 7_776_000)
    }

    @Test func qualitiesAreSmallerDownTheList() throws {
        let size = CGSize(width: 2880, height: 1800)
        for format in [ExportFormat.mp4, .proRes] {
            let bytes = try ExportQuality.allCases.map {
                try #require(ExportSettings(format: format, quality: $0).estimatedBytes(size: size, frameRate: 60, duration: 20, hasAudio: true))
            }
            #expect(bytes == bytes.sorted(by: >), "\(format)")
            #expect(Set(bytes).count == 4, "\(format)")
        }
    }

    @Test func proResScalesAppleTargetRateToTheSizeAndFrameRate() throws {
        let fullHD = CGSize(width: 1920, height: 1080)
        let rate = { (settings: ExportSettings, size: CGSize, frameRate: Double) in
            try #require(settings.videoBitRate(size: size, frameRate: frameRate))
        }

        #expect(abs(try rate(ExportSettings(format: .proRes, quality: .socialMedia), fullHD, 29.97) - 147_000_000) < 1)
        #expect(abs(try rate(ExportSettings(format: .proRes, quality: .studio), fullHD, 29.97) - 220_000_000) < 1)
        #expect(abs(try rate(ExportSettings(format: .proRes, transparentCanvas: true), fullHD, 29.97) - 330_000_000) < 1)
        // Four times the pixels at twice the rate is eight times the data
        #expect(abs(try rate(ExportSettings(format: .proRes), CGSize(width: 3840, height: 2160), 59.94) - 8 * 147_000_000) < 1)
        // Uncompressed audio
        #expect(ExportSettings(format: .proRes).audioBitRate(hasAudio: true) == 1_536_000)
    }

    @Test func aGIFHasNoEstimate() {
        #expect(ExportSettings(format: .gif).estimatedBytes(size: CGSize(width: 640, height: 480), frameRate: 30, duration: 5, hasAudio: true) == nil)
        #expect(ExportSettings(format: .gif).audioBitRate(hasAudio: true) == 0)
    }

    @Test func aFileOnThePasteboardIsItsURLAndForAGIFItsData() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let gif = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).gif")
        let data = Data("GIF89a".utf8)
        try data.write(to: gif)
        defer { try? FileManager.default.removeItem(at: gif) }

        FilePasteboard.copy(file: gif, to: pasteboard)

        let urls = try #require(pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])
        #expect(urls == [gif])
        #expect(pasteboard.data(forType: FilePasteboard.gifType) == data)

        let movie = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        FilePasteboard.copy(file: movie, to: pasteboard)
        #expect(pasteboard.data(forType: FilePasteboard.gifType) == nil)
        #expect(try #require(pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]) == [movie])
    }
}
