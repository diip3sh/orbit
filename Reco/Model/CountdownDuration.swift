//
//  CountdownDuration.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// How long to count down before a user-started recording
enum CountdownDuration: Int, CaseIterable, Identifiable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var displayName: String {
        self == .off ? "Off" : "\(rawValue) seconds"
    }
}
