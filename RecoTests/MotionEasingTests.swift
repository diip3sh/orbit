//
//  MotionEasingTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct MotionEasingTests {

    @Test func linearAndHold() {
        #expect(MotionEasing.linear.progress(0.3, duration: 1) == 0.3)
        #expect(MotionEasing.hold.progress(0.99, duration: 1) == 0)
        #expect(MotionEasing.hold.progress(1, duration: 1) == 1)
    }

    @Test func cubicBezierMatchesCSS() {
        // CSS ease-in at half time, and the symmetric ease-in-out
        #expect(abs(MotionEasing.cubicBezier(0.42, 0, 1, 1).progress(0.5, duration: 1) - 0.3153) < 1e-3)
        #expect(abs(MotionEasing.cubicBezier(0.42, 0, 0.58, 1).progress(0.5, duration: 1) - 0.5) < 1e-6)
    }

    @Test func springStartsAndLandsExactlyWithoutOvershoot() {
        let spring = MotionEasing.spring(response: 0.4)
        #expect(spring.progress(0, duration: 0.6) == 0)
        #expect(abs(spring.progress(1, duration: 0.6) - 1) < 1e-12)
        let samples = stride(from: 0.0, through: 1, by: 0.01).map { spring.progress($0, duration: 0.6) }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func codesAsAPersonWritesIt() throws {
        let json = #"["linear", "hold", [0.33, 1, 0.68, 1], {"spring": 0.4}]"#
        let easings = try JSONDecoder().decode([MotionEasing].self, from: Data(json.utf8))
        #expect(easings == [.linear, .hold, .cubicBezier(0.33, 1, 0.68, 1), .spring(response: 0.4)])
        #expect(try JSONDecoder().decode([MotionEasing].self, from: JSONEncoder().encode(easings)) == easings)
    }

    @Test(arguments: [#""bounce""#, "[0.2, 1]", "[1.5, 0, 0.5, 1]", #"{"spring": 0}"#])
    func refusesWhatIsNotAnEasing(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MotionEasing.self, from: Data(json.utf8))
        }
    }
}
