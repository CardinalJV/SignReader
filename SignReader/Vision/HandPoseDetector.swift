//
//  HandPoseDetector.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import AVFoundation
import Combine
import Vision

// Holds the 21 detected hand points and the time they were captured.
nonisolated struct HandLandmarks: @unchecked Sendable {
    /// Always 21 points in the same fixed order (see `HandPoseDetector.jointOrder`).
    let points: [VNRecognizedPoint]
    let timestamp: TimeInterval
}

// Uses Apple's Vision framework to find a hand on each camera frame.
// It returns 21 points (the joints of the hand) for each detected hand.
nonisolated final class HandPoseDetector: @unchecked Sendable {
    /// The fixed order of the 21 hand joints.
    /// Index 0 is the wrist, index 9 is the base of the middle finger (used to scale the hand).
    static let jointOrder: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]

    // Publisher that emits each new set of landmarks (or nil if no hand is found).
    let landmarksPublisher = PassthroughSubject<HandLandmarks?, Never>()

    // The Vision request that looks for one hand in an image.
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    /// Looks for a hand on the given camera frame and publishes the result.
    /// Called from the camera background queue, so we run the detection right there.
    func process(sampleBuffer: CMSampleBuffer) {
        // Get the actual image data from the camera frame.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            landmarksPublisher.send(nil)
            return
        }

        // Vision wraps the image in a "handler" before running the request on it.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            // Run the hand pose request on the frame.
            try handler.perform([request])
            // No hand found? Publish nil.
            guard
                let observation = request.results?.first,
                let landmarks = Self.extractLandmarks(from: observation)
            else {
                landmarksPublisher.send(nil)
                return
            }
            // Time at which the frame was taken.
            let timestamp = CMTimeGetSeconds(
                CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            )
            // Publish the 21 points and the timestamp.
            landmarksPublisher.send(
                HandLandmarks(points: landmarks, timestamp: timestamp)
            )
        } catch {
            landmarksPublisher.send(nil)
        }
    }

    // Pulls the 21 named points out of the Vision result in the right order.
    private static func extractLandmarks(
        from observation: VNHumanHandPoseObservation
    ) -> [VNRecognizedPoint]? {
        var collected: [VNRecognizedPoint] = []
        collected.reserveCapacity(jointOrder.count)

        for joint in jointOrder {
            guard let point = try? observation.recognizedPoint(joint) else { return nil }
            collected.append(point)
        }
        return collected.count == jointOrder.count ? collected : nil
    }
}
