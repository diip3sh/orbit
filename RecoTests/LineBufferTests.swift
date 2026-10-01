//
//  LineBufferTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct LineBufferTests {

    private func strings(_ lines: [Data]) -> [String] {
        lines.compactMap { String(data: $0, encoding: .utf8) }
    }

    @Test func aLineSplitAcrossChunksComesOutWhole() {
        var buffer = LineBuffer()

        #expect(buffer.append(Data("{\"a\":".utf8)).isEmpty)
        #expect(strings(buffer.append(Data("1}\n".utf8))) == ["{\"a\":1}"])
    }

    @Test func severalLinesInOneChunkComeOutInOrder() {
        var buffer = LineBuffer()

        #expect(strings(buffer.append(Data("one\ntwo\nthree\n".utf8))) == ["one", "two", "three"])
    }

    @Test func carriageReturnsAreDropped() {
        var buffer = LineBuffer()

        #expect(strings(buffer.append(Data("one\r\ntwo\r\n".utf8))) == ["one", "two"])
    }

    @Test func emptyLinesAreSkipped() {
        var buffer = LineBuffer()

        #expect(strings(buffer.append(Data("\n\none\n\r\n\ntwo\n".utf8))) == ["one", "two"])
    }

    @Test func aPartialTailWaitsForItsEnd() {
        var buffer = LineBuffer()

        #expect(strings(buffer.append(Data("one\ntw".utf8))) == ["one"])
        #expect(strings(buffer.append(Data("o\nthr".utf8))) == ["two"])
        #expect(strings(buffer.append(Data("ee\n".utf8))) == ["three"])
    }

    @Test func multibyteCharactersSplitAcrossChunksSurvive() {
        var buffer = LineBuffer()
        let bytes = Array("é\n".utf8)

        #expect(buffer.append(Data(bytes[..<1])).isEmpty)
        #expect(strings(buffer.append(Data(bytes[1...]))) == ["é"])
    }
}
