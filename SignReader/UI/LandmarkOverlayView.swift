//
//  LandmarkOverlayView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI
import Vision

// Draws the hand "skeleton" (dots and lines) on top of the camera preview.
// Each finger has 5 points; we connect them with lines to form the skeleton.
struct LandmarkOverlayView: View {
    // The 21 detected hand points (or nil if no hand is visible).
    let landmarks: [VNRecognizedPoint]?

    // For each finger, the order of point indexes to draw a line through.
    private static let fingerChains: [[Int]] = [
        [0, 1, 2, 3, 4],      // thumb
        [0, 5, 6, 7, 8],      // index
        [0, 9, 10, 11, 12],   // middle
        [0, 13, 14, 15, 16],  // ring
        [0, 17, 18, 19, 20]   // little
    ]

    // A point with a score below this value is shown in gray (less reliable).
    private static let highConfidence: Float = 0.5
    private static let pointRadius: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            // Canvas is a fast drawing area provided by SwiftUI.
            Canvas { context, size in
                guard let points = landmarks, points.count == 21 else { return }

                // Draw the skeleton lines first so the dots will appear on top.
                for chain in Self.fingerChains {
                    var path = Path()
                    var started = false
                    var allConfident = true
                    for idx in chain {
                        let p = points[idx]
                        if p.confidence < Self.highConfidence { allConfident = false }
                        let cgPoint = Self.convert(point: p, in: size)
                        if started {
                            path.addLine(to: cgPoint)
                        } else {
                            path.move(to: cgPoint)
                            started = true
                        }
                    }
                    // Teal when reliable, gray when one of the points is unsure.
                    let color: Color = allConfident ? .teal.opacity(0.75) : .gray.opacity(0.45)
                    context.stroke(path, with: .color(color), lineWidth: 2)
                }

                // Then draw a dot for every hand point.
                for p in points {
                    let center = Self.convert(point: p, in: size)
                    let rect = CGRect(
                        x: center.x - Self.pointRadius,
                        y: center.y - Self.pointRadius,
                        width: Self.pointRadius * 2,
                        height: Self.pointRadius * 2
                    )
                    let color: Color = p.confidence >= Self.highConfidence ? .teal : .gray
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // The overlay is just a drawing; it should not catch taps.
            .allowsHitTesting(false)
        }
    }

    // Vision uses coordinates from 0 to 1 with the origin at the bottom-left.
    // SwiftUI uses the top-left, so we flip the Y axis and scale to pixel size.
    private static func convert(point: VNRecognizedPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.location.x * size.width,
            y: (1 - point.location.y) * size.height
        )
    }
}
