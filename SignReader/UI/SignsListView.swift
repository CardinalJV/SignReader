//
//  SignsListView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// Screen that shows the picture of every sign the user can perform.
// Letters are shown two by two, followed by "space" and "delete".
struct SignsListView: View {
    // All the letters from A to Z, sorted alphabetically.
    private var letters: [GestureLabel] {
        GestureLabel.trainableCases
            .filter { $0.isLetter }
            .sorted { $0.rawValue < $1.rawValue }
    }

    // Splits the letters into pairs so we can show two per row.
    // Example: [A, B, C, D, ...] becomes [[A, B], [C, D], ...]
    private var letterPairs: [[GestureLabel]] {
        stride(from: 0, to: letters.count, by: 2).map {
            Array(letters[$0..<min($0 + 2, letters.count)])
        }
    }

    var body: some View {
        // Scrollable area in case there are more rows than fit on screen.
        ScrollView {
            // LazyVStack builds rows only when they appear on screen (better performance).
            LazyVStack(spacing: 16) {
                // One row per pair of letters.
                ForEach(Array(letterPairs.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 16) {
                        ForEach(pair) { label in
                            SignCard(label: label)
                        }
                        // Empty space if the row has only one card (keeps alignment).
                        if pair.count == 1 {
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Last row with the two special signs.
                HStack(spacing: 16) {
                    SignCard(label: .space)
                    SignCard(label: .del)
                }
            }
            .padding(16)
        }
        .navigationTitle("Signs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// One card showing the picture of a sign and its name.
private struct SignCard: View {
    let label: GestureLabel

    var body: some View {
        VStack(spacing: 8) {
            // Picture of the sign, loaded from the Assets catalog.
            Image(label.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            // The name of the sign below the picture.
            Text(label.displayName)
                .font(.headline)
        }
        .padding(12)
        // Soft rounded background around the card.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Small helpers added only inside this file.
private extension GestureLabel {
    // True if the sign is a letter (A-Z).
    var isLetter: Bool {
        switch self {
        case .space, .del, .nothing, .unknown: return false
        default: return true
        }
    }

    // The image name inside the Assets catalog.
    // For example, the asset for `.del` is named "delete", not "del".
    var assetName: String {
        switch self {
        case .del: return "delete"
        case .space: return "space"
        default: return rawValue
        }
    }
}
