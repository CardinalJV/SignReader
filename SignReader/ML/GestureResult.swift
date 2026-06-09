//
//  GestureResult.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import Foundation

// Represents one guess from the ML model:
// which sign it thinks it sees, how sure it is, and when it was made.
nonisolated struct GestureResult: Equatable, Sendable {
    let label: GestureLabel    // The recognized sign (or "unknown").
    let confidence: Float       // From 0 (not sure) to 1 (very sure).
    let timestamp: Date         // When the guess was made.

    init(label: GestureLabel, confidence: Float, timestamp: Date = Date()) {
        self.label = label
        self.confidence = confidence
        self.timestamp = timestamp
    }

    // Considered confident when the score is 75% or higher.
    var isConfident: Bool { confidence >= 0.75 }

    // Default "no result" value used when nothing is detected.
    static let unknown = GestureResult(label: .unknown, confidence: 0)
}
