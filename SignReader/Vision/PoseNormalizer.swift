//
//  PoseNormalizer.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import CoreGraphics
import Foundation
import Vision

// Turns the raw hand points into numbers that are easier for the ML model to use.
// We move the points so the wrist becomes the origin (0, 0),
// then we shrink/grow them so the hand always has the same size on screen.
// Without this, signs would look different when the hand is close or far away.
nonisolated enum PoseNormalizer {
    static let landmarkCount = HandPoseDetector.jointOrder.count   // 21
    static let featureCount = landmarkCount * 2                    // 42 (x and y for 21 points)
    // Any point less reliable than this is rejected.
    static let minimumConfidence: Float = 0.3

    /// Same as `normalize(points:)` but accepts a `HandLandmarks` value directly.
    static func normalize(_ landmarks: HandLandmarks?) -> [Float]? {
        guard let landmarks else { return nil }
        return normalize(points: landmarks.points)
    }

    // Returns a flat list of 42 numbers: [x0, y0, x1, y1, ...].
    // Returns nil if a point is unreliable or if the hand cannot be measured.
    static func normalize(points: [VNRecognizedPoint]) -> [Float]? {
        // Must have exactly 21 points.
        guard points.count == landmarkCount else { return nil }

        // Reject the whole hand if any point has a low confidence.
        for point in points where point.confidence < minimumConfidence {
            return nil
        }

        // The wrist is the reference (0, 0).
        let wrist = points[0].location
        // The middle finger's base gives us the size of the hand.
        let middleMCP = points[9].location

        // Distance between wrist and middle MCP = our scale factor.
        let dx = middleMCP.x - wrist.x
        let dy = middleMCP.y - wrist.y
        let scale = sqrt(dx * dx + dy * dy)
        // If the two points are on top of each other, we can't divide → bail out.
        guard scale > 1e-6 else { return nil }

        // For each point, subtract the wrist position and divide by the scale.
        var out: [Float] = []
        out.reserveCapacity(featureCount)
        for point in points {
            let nx = Float((point.location.x - wrist.x) / scale)
            let ny = Float((point.location.y - wrist.y) / scale)
            out.append(nx)
            out.append(ny)
        }
        return out
    }
}
