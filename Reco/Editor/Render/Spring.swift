//
//  Spring.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// One axis of a critically damped spring, stepped exactly at a fixed rate: it reaches its goal as
/// fast as it can without overshooting.
nonisolated struct Spring {
    private(set) var position: Double
    private var velocity = 0.0

    private let frequency: Double
    private let step: Double
    private let decay: Double

    /// - Parameters:
    ///   - frequency: The natural frequency, in radians per second. A move is 96% done after
    ///     5 / `frequency` seconds.
    ///   - rate: Steps per second.
    init(position: Double, frequency: Double, rate: Double) {
        self.position = position
        self.frequency = frequency
        step = 1 / rate
        decay = exp(-frequency * step)
    }

    /// Moves one step towards `goal`, and stops there once within 1e-5 of it and nearly still.
    mutating func advance(to goal: Double) {
        let offset = position - goal
        let blend = (velocity + frequency * offset) * step
        position = goal + (offset + blend) * decay
        velocity = (velocity - frequency * blend) * decay
        if abs(position - goal) < 1e-5, abs(velocity) < 1e-4 {
            position = goal
            velocity = 0
        }
    }
}
