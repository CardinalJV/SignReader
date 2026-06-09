//
//  GestureRecognitionViewModel.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI
import Vision

// Holds the user preferences for sound, haptics and the landmark overlay.
struct AppSettings: Equatable {
    var speechEnabled: Bool = false
    var hapticsEnabled: Bool = true
    var landmarkOverlayEnabled: Bool = true
}

// The "brain" of the app.
// It connects the camera, the hand detector, the ML model, and the UI together.
@MainActor
final class GestureRecognitionViewModel: ObservableObject {
    // A letter is added to the captured text only if the same sign is held
    // for `commitDuration` seconds and the confidence stays above `commitConfidence`.
    static let commitDuration: TimeInterval = 2.0
    static let commitConfidence: Float = 0.5

    // Values shown by the UI. `@Published` means: "the UI updates when this changes".
    @Published private(set) var currentResult: GestureResult = .unknown
    @Published private(set) var landmarks: [VNRecognizedPoint]? = nil
    @Published private(set) var isCameraAuthorized = false
    @Published private(set) var typedText: String = ""
    /// A number from 0 to 1 showing how close we are to validating the current sign.
    @Published private(set) var commitProgress: Double = 0
    @Published var settings = AppSettings()

    // Subsystems used by the app.
    let cameraSession = CameraSession()      // Manages the iPhone camera.
    let dataCollector: DataCollector         // Saves training samples to a CSV file.

    private let detector = HandPoseDetector()    // Finds the hand on each camera frame.
    private let buffer = PoseBuffer()            // Keeps the last 30 frames in memory.
    private let classifier: GestureClassifying   // The ML model that guesses the sign.
    private let haptics = HapticEngine()         // Plays vibrations.
    private let speech = SpeechEngine()          // Reads the letters out loud.
    // Stores the subscriptions so they stay alive (Combine framework).
    private var cancellables = Set<AnyCancellable>()

    // Variables used to know when to validate a letter.
    private var candidateLabel: GestureLabel?   // The sign we are currently watching.
    private var candidateStart: Date?            // When the user started showing it.
    /// The last letter we just added.
    /// We remember it so the user has to "release" before showing the same letter again.
    private var lastCommitted: GestureLabel?
    /// A background task that plays a small vibration every 0.25s during the countdown.
    private var tickTask: Task<Void, Never>?

    // Called once when the view model is created.
    init() {
        self.dataCollector = DataCollector()
        // Picks the real ML model (or a mock one for tests).
        self.classifier = GestureClassifierFactory.make()
        // Connects all the pipes together.
        wireUp()
    }

    // MARK: - Lifecycle

    // Asks for camera permission and starts the camera if allowed.
    func start() async {
        let authorized = await cameraSession.requestAuthorizationIfNeeded()
        isCameraAuthorized = authorized
        guard authorized else { return }
        cameraSession.start()
    }

    // Stops the camera and any current speech.
    func stop() {
        cameraSession.stop()
        speech.stop()
    }

    // MARK: - Pipeline

    // Connects all the components together using Combine "publishers" (event streams).
    // Think of it like plugging cables: camera → hand detector → ML model → UI.
    private func wireUp() {
        // Each new camera frame is sent to the hand detector.
        cameraSession.sampleBufferPublisher
            .sink { [detector] sampleBuffer in
                detector.process(sampleBuffer: sampleBuffer)
            }
            .store(in: &cancellables)

        // When the hand detector finds (or loses) the hand, update the UI overlay.
        // If the hand leaves the frame, we reset the countdown.
        detector.landmarksPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                self.landmarks = result?.points
                if result == nil { self.resetForRelease() }
            }
            .store(in: &cancellables)

        // Each set of detected hand points is sent to the ML model to guess the sign.
        detector.landmarksPublisher
            .compactMap { $0 }
            .sink { [classifier] landmarks in
                classifier.classify(landmarks: landmarks)
            }
            .store(in: &cancellables)

        // For data collection: normalize hand points, group them in a window of 30 frames,
        // and pass that window to the data collector to save as CSV.
        detector.landmarksPublisher
            .compactMap { PoseNormalizer.normalize($0) }
            .receive(on: DispatchQueue.main)
            .compactMap { [buffer] vec -> [[Float]]? in
                buffer.append(vec)
            }
            .sink { [weak self] window in
                self?.dataCollector.capture(window: window)
            }
            .store(in: &cancellables)

        // Each guess from the ML model is sent to `handle(result:)` to update UI.
        classifier.resultPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handle(result: result)
            }
            .store(in: &cancellables)

        // If the camera is interrupted (phone call, etc), clear the old frames.
        cameraSession.interruptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interrupted in
                if interrupted { self?.buffer.reset() }
            }
            .store(in: &cancellables)
    }

    // Called every time the ML model gives a new guess.
    // It updates the UI, optionally says the letter out loud, and tracks the countdown.
    private func handle(result: GestureResult) {
        currentResult = result

        // Speak the letter only if it's a real, confident letter and speech is enabled.
        if result.label != .unknown,
           result.label != .nothing,
           result.isConfident,
           settings.speechEnabled {
            speech.speak(result.label.displayName)
        }

        trackForCommit(result: result)
    }

    // MARK: - Typing

    // Erases everything the user has captured so far.
    func clearTypedText() {
        typedText = ""
        resetForRelease()
    }

    // Adds a ready-made phrase (from the phrases picker) to the captured text.
    func insertPhrase(_ phrase: String) {
        typedText += phrase
        resetForRelease()
    }

    // Reads the captured text out loud.
    func speakTypedText() {
        guard !typedText.isEmpty else { return }
        speech.speak(typedText)
    }

    // The countdown logic that decides if a sign is held long enough to validate.
    private func trackForCommit(result: GestureResult) {
        // If the confidence is too low, or the sign is "unknown"/"nothing",
        // we cancel the countdown.
        guard result.confidence >= Self.commitConfidence,
              result.label != .unknown,
              result.label != .nothing else {
            resetForRelease()
            return
        }

        // If the user is still showing the same letter we just validated,
        // they need to release the sign first before retyping it.
        if result.label == lastCommitted {
            commitProgress = 0
            return
        }

        if result.label == candidateLabel, let start = candidateStart {
            // Same sign as before: update how much time has passed.
            let elapsed = Date().timeIntervalSince(start)
            commitProgress = min(elapsed / Self.commitDuration, 1)
            // If the user held it long enough, validate the letter.
            if elapsed >= Self.commitDuration {
                stopCountdownTicks()
                commit(label: result.label)
                lastCommitted = result.label
                candidateLabel = nil
                candidateStart = nil
                commitProgress = 0
            }
        } else {
            // A new sign appeared. Start the countdown from zero.
            // We play a small "start" vibration and begin ticking.
            candidateLabel = result.label
            candidateStart = Date()
            commitProgress = 0
            if settings.hapticsEnabled { haptics.playStart() }
            startCountdownTicks()
        }
    }

    // Plays a tiny vibration every 0.25s during the countdown to guide the user.
    private func startCountdownTicks() {
        stopCountdownTicks()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                if Task.isCancelled { return }
                // Stop ticking if the countdown was cancelled.
                guard self.candidateStart != nil else { return }
                if self.settings.hapticsEnabled { self.haptics.playTick() }
            }
        }
    }

    // Stops the small ticking vibration.
    private func stopCountdownTicks() {
        tickTask?.cancel()
        tickTask = nil
    }

    // Adds the validated sign to the captured text.
    // Special signs do special things: space adds a " ", del erases the last letter.
    private func commit(label: GestureLabel) {
        switch label {
        case .space:
            typedText.append(" ")
        case .del:
            if !typedText.isEmpty { typedText.removeLast() }
        default:
            typedText.append(label.rawValue)
        }
        if settings.hapticsEnabled { haptics.playConfirm() }
    }

    // Resets the countdown variables. Called when the user "releases" the sign.
    private func resetForRelease() {
        stopCountdownTicks()
        candidateLabel = nil
        candidateStart = nil
        lastCommitted = nil
        commitProgress = 0
    }
}
