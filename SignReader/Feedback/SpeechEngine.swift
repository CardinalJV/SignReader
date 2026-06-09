//
//  SpeechEngine.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import AVFoundation
import Foundation

// Reads text out loud using Apple's text-to-speech.
// Also avoids speaking the same word twice in a row too quickly.
@MainActor
final class SpeechEngine {
    // Apple's speech synthesizer.
    private let synthesizer = AVSpeechSynthesizer()
    // Voice language (US English).
    private let voiceLanguage = "en-US"
    // If the same text is spoken again within this delay, we skip it.
    private let debounceInterval: TimeInterval = 1.5
    private var lastSpokenText: String?
    private var lastSpokenAt: Date?

    // Quick on/off switch (not currently wired to the settings UI).
    var isEnabled: Bool = true

    // Speak the given text out loud.
    func speak(_ text: String) {
        guard isEnabled else { return }
        guard !text.isEmpty else { return }

        // Skip if the same text was just spoken recently.
        let now = Date()
        if let lastSpokenText, lastSpokenText == text,
           let lastSpokenAt, now.timeIntervalSince(lastSpokenAt) < debounceInterval {
            return
        }

        // Prepare the audio system for speaking.
        configureAudioSession()

        // Build the speech "utterance" (the thing to say) with a slightly slower rate.
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
            ?? AVSpeechSynthesisVoice(language: "en-US")

        // If we're already speaking something else, cut it off and start the new one.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)

        lastSpokenText = text
        lastSpokenAt = now
    }

    // Stop speaking immediately.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // Sets the audio session so the speech can play and mix with other sounds.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true, options: [])
    }
}
