//
//  ConfidenceMeterView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// Small round meter that shows the recognition confidence (0% to 100%).
// The ring fills proportionally and turns green above 50%, red below.
struct ConfidenceMeterView: View {
    // The confidence score from the ML model (0 to 1).
    let confidence: Float

    var body: some View {
        // Force the value between 0 and 1 to avoid drawing outside the ring.
        let clamped = CGFloat(max(0, min(confidence, 1)))
        ZStack {
            // The gray "track" behind the colored ring.
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 4)
            // The colored part of the ring that fills with the confidence.
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))   // start from the top, not the right
                .animation(.easeOut(duration: 0.15), value: clamped)

            // Percentage text in the center.
            Text("\(Int(round(confidence * 100)))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        // VoiceOver labels for accessibility.
        .accessibilityLabel(Text("Confidence"))
        .accessibilityValue(Text("\(Int(confidence * 100)) percent"))
    }

    // Green when confident, red when not.
    private var color: Color {
        confidence >= 0.5 ? .green : .red
    }
}
