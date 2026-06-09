//
//  PhrasesPIckerView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// Small pop-up screen that lets the user pick a ready-made phrase to insert.
// The dots ("...") inside each phrase are meant to be completed by signing letters.
struct PhrasesPickerView: View {
    // Closure called when the user picks a phrase.
    let onPick: (String) -> Void
    // System value used to close this pop-up.
    @Environment(\.dismiss) private var dismiss

    // English phrases shown in the first section.
    private let englishPhrases: [String] = [
        "Hey, my name is ...",
        "I am ... years old.",
        "I am from ..."
    ]

    // Italian phrases shown in the second section.
    private let italianPhrases: [String] = [
        "Ciao, mi chiamo ...",
        "Ho ... anni.",
        "Sono di ..."
    ]

    var body: some View {
        NavigationStack {
            // List with two sections: English and Italian.
            List {
                Section("English") {
                    ForEach(englishPhrases, id: \.self) { phrase in
                        phraseRow(phrase)
                    }
                }

                Section("Italiano") {
                    ForEach(italianPhrases, id: \.self) { phrase in
                        phraseRow(phrase)
                    }
                }
            }
            .navigationTitle("Phrases")
            .navigationBarTitleDisplayMode(.inline)
            // Cancel button at the top-left to close the pop-up.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // Builds one tappable row containing a single phrase.
    // Tapping the row sends the phrase back and closes the pop-up.
    private func phraseRow(_ phrase: String) -> some View {
        Button {
            onPick(phrase)
            dismiss()
        } label: {
            Text(phrase)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
