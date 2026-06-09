//
//  GestureClassifier.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import Combine
import CoreML
import Foundation
import Vision

// A common interface ("contract") for any class that can recognize hand signs.
// This allows us to swap between the real model and a mock model for testing.
nonisolated protocol GestureClassifying: AnyObject {
    // Publisher that sends each new guess to anyone listening.
    var resultPublisher: PassthroughSubject<GestureResult, Never> { get }
    // Tries to recognize a sign from a set of hand landmarks.
    func classify(landmarks: HandLandmarks)
}

/// Uses the trained ML model `MyHandPoseClassifier.mlmodel` to recognize signs.
///
/// The model expects:
///   - a 3D table of size [1, 3, 21] containing decimal numbers
///   - 1 frame, 3 values (x, y, confidence) for each of the 21 hand points
///
/// The model returns:
///   - `label`: the most likely sign (e.g. "A")
///   - `labelProbabilities`: a confidence score for every possible sign
nonisolated final class GestureClassifier: GestureClassifying, @unchecked Sendable {
    // Predictions with a confidence below this value are returned as "unknown".
    static let confidenceThreshold: Float = 0.5

    let resultPublisher = PassthroughSubject<GestureResult, Never>()

    // The Core ML model (loaded from disk). Optional in case loading failed.
    private let model: MLModel?
    // Background queue used to run the ML model without blocking the UI.
    private let inferenceQueue = DispatchQueue(
        label: "com.signlens.ml",
        qos: .userInitiated
    )
    // True while a prediction is being computed (to avoid running two at the same time).
    private var isRunning = false

    init() {
        self.model = Self.loadCompiledModel()
    }

    // Runs the ML model on the given hand landmarks (asynchronously).
    func classify(landmarks: HandLandmarks) {
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            // If a prediction is already running, skip this one.
            if self.isRunning { return }
            self.isRunning = true
            defer { self.isRunning = false }

            let result = self.runInference(landmarks: landmarks)
            // If the confidence is too low, return "unknown" instead of the guessed sign.
            let gated: GestureResult
            if result.confidence >= Self.confidenceThreshold {
                gated = result
            } else {
                gated = GestureResult(label: .unknown, confidence: result.confidence)
            }
            self.resultPublisher.send(gated)
        }
    }

    // MARK: - Inference

    // Prepares the input, runs the model, and converts the output to a `GestureResult`.
    private func runInference(landmarks: HandLandmarks) -> GestureResult {
        guard let model else {
            return GestureResult(label: .unknown, confidence: 0)
        }
        // Convert the hand landmarks into the table format the model expects.
        guard let input = Self.makePosesMultiArray(from: landmarks) else {
            return GestureResult(label: .unknown, confidence: 0)
        }
        // Wrap the input in the structure Core ML expects.
        let provider: MLFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(
                dictionary: ["poses": MLFeatureValue(multiArray: input)]
            )
        } catch {
            return GestureResult(label: .unknown, confidence: 0)
        }
        // Ask the model to make a prediction.
        guard let output = try? model.prediction(from: provider) else {
            return GestureResult(label: .unknown, confidence: 0)
        }
        // Parse the model's answer.
        return Self.interpret(output: output)
    }

    // Reads the model's output and turns it into a `GestureResult`.
    private static func interpret(output: MLFeatureProvider) -> GestureResult {
        // Get the most-likely sign (e.g. "A").
        guard let labelString = output.featureValue(for: "label")?.stringValue else {
            return GestureResult(label: .unknown, confidence: 0)
        }
        // Get the confidence score for that sign.
        var confidence: Float = 0
        if let dict = output.featureValue(for: "labelProbabilities")?
            .dictionaryValue as? [String: Double] {
            confidence = Float(dict[labelString] ?? 0)
        }
        // Map the model's string ("A") to our enum (`GestureLabel.a`).
        let label = GestureLabel(rawValue: labelString) ?? .unknown
        return GestureResult(label: label, confidence: confidence)
    }

    /// Converts the 21 detected hand points into the [1, 3, 21] table the model needs.
    /// Position in memory: ptr[c * 21 + j] where c is 0 (x), 1 (y) or 2 (confidence)
    /// and j is the index of the joint.
    private static func makePosesMultiArray(from landmarks: HandLandmarks) -> MLMultiArray? {
        let jointCount = HandPoseDetector.jointOrder.count
        guard landmarks.points.count == jointCount else { return nil }
        guard let array = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: jointCount)],
            dataType: .float32
        ) else { return nil }

        // Get a direct pointer to the array memory to fill it quickly.
        let ptr = array.dataPointer.bindMemory(
            to: Float.self,
            capacity: 3 * jointCount
        )
        // Fill in: x for all joints, then y for all joints, then confidence.
        for (j, point) in landmarks.points.enumerated() {
            ptr[0 * jointCount + j] = Float(point.location.x)
            ptr[1 * jointCount + j] = Float(point.location.y)
            ptr[2 * jointCount + j] = Float(point.confidence)
        }
        return array
    }

    // Loads the trained ML model from the app bundle.
    private static func loadCompiledModel() -> MLModel? {
        // Try the already-compiled model first (faster).
        if let url = Bundle.main.url(forResource: "MyHandPoseClassifier", withExtension: "mlmodelc"),
           let model = try? MLModel(contentsOf: url) {
            return model
        }
        // Otherwise, compile the raw .mlmodel file on first launch.
        if let url = Bundle.main.url(forResource: "MyHandPoseClassifier", withExtension: "mlmodel"),
           let compiledURL = try? MLModel.compileModel(at: url),
           let model = try? MLModel(contentsOf: compiledURL) {
            return model
        }
        return nil
    }
}

// MARK: - Mock classifier

// A fake classifier used for development.
// It cycles through every sign in turn, so we can test the UI without the camera.
nonisolated final class MockGestureClassifier: GestureClassifying, @unchecked Sendable {
    let resultPublisher = PassthroughSubject<GestureResult, Never>()

    private let cases = GestureLabel.trainableCases
    private let cycleDuration: TimeInterval = 2.0
    private let startTime = Date()

    func classify(landmarks: HandLandmarks) {
        // Pick a sign based on how much time has passed since we started.
        let elapsed = Date().timeIntervalSince(startTime)
        let index = Int(elapsed / cycleDuration) % max(cases.count, 1)
        let label = cases.indices.contains(index) ? cases[index] : .unknown

        // Make the confidence go up and down between 0.5 and 0.9 to feel realistic.
        let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        let confidence = Float(0.5 + 0.4 * sin(phase * .pi))
        resultPublisher.send(GestureResult(label: label, confidence: confidence))
    }
}

// MARK: - Active classifier selector

// Chooses the right classifier at build time.
// When the `MOCK_MODEL` flag is set, we use the fake one; otherwise the real one.
enum GestureClassifierFactory {
    static func make() -> GestureClassifying {
        #if MOCK_MODEL
        return MockGestureClassifier()
        #else
        return GestureClassifier()
        #endif
    }
}
