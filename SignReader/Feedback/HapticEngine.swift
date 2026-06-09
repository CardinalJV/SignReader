//
//  HapticEngine.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import CoreHaptics
import Foundation
import UIKit

// Plays vibrations on the iPhone using Apple's Core Haptics framework.
// Different patterns give the user feedback during the recognition.
nonisolated final class HapticEngine {
    // Apple's haptic engine. Optional because not all devices support haptics.
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    init() {
        // Check that the device supports haptics (iPhone 8+).
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            startEngine()
        }
    }

    // Strong single tap played when a letter is validated.
    func playConfirm() {
        playPattern(intensity: 0.8, sharpness: 0.9, pulses: 1, spacing: 0)
    }

    // Two soft taps played when the recognition is uncertain.
    func playUncertain() {
        playPattern(intensity: 0.4, sharpness: 0.5, pulses: 2, spacing: 0.08)
    }

    /// Double tap to mark the start of the validation countdown.
    func playStart() {
        playPattern(intensity: 0.55, sharpness: 1.0, pulses: 2, spacing: 0.05)
    }

    /// Very light tap played repeatedly during the countdown to guide the user.
    func playTick() {
        playPattern(intensity: 0.22, sharpness: 0.35, pulses: 1, spacing: 0)
    }

    // No vibration when the sign is unknown.
    func playUnknown() {
        // No haptic by design.
    }

    // MARK: - Internals

    // Creates the Apple haptic engine and starts it.
    private func startEngine() {
        do {
            let engine = try CHHapticEngine()
            // If the engine resets or stops, we automatically restart it.
            engine.resetHandler = { [weak self] in
                self?.restartEngine()
            }
            engine.stoppedHandler = { [weak self] _ in
                self?.restartEngine()
            }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    // Restarts the engine if it was paused for any reason.
    private func restartEngine() {
        do {
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    // Plays a vibration pattern.
    // - intensity: how strong the vibration is (0 to 1).
    // - sharpness: how "sharp" it feels (0 = soft, 1 = sharp).
    // - pulses: how many taps in the pattern.
    // - spacing: time between two taps (in seconds).
    private func playPattern(intensity: Float, sharpness: Float, pulses: Int, spacing: TimeInterval) {
        guard supportsHaptics, let engine else { return }

        // Build the list of taps that make up the pattern.
        var events: [CHHapticEvent] = []
        for i in 0..<max(pulses, 1) {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: spacing * TimeInterval(i)
            )
            events.append(event)
        }

        // Build a pattern and play it now.
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // If playing failed, the engine may need to be restarted.
            restartEngine()
        }
    }
}
