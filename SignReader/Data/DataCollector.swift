//
//  DataCollector.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

//import Combine
import Foundation
import SwiftUI

// Records training samples to a CSV file.
// A "sample" is a window of 30 frames; each frame has 42 numbers (21 points, x and y).
// This file is used later to train the machine learning model.
@MainActor
@Observable
final class DataCollector {

    // The name of the file where samples are saved.
    static let fileName = "training_data.csv"

    // How many samples we have recorded for each sign (used to display counts).
    private(set) var sampleCounts: [GestureLabel: Int] = [:]
    // The label that will be applied to new samples (chosen by the user in the UI).
    var selectedLabel: GestureLabel = .a
    // True while we are recording samples.
    private(set) var isRecording = false

    // Full path on disk to the CSV file.
    let fileURL: URL

    private let windowSize = PoseBuffer.windowSize         // 30 frames per sample
    private let featureCount = PoseNormalizer.featureCount  // 42 numbers per frame
    // Background queue used to write to disk without blocking the UI.
    private let queue = DispatchQueue(label: "com.signlens.datacollector", qos: .utility)

    // Creates the data collector and prepares the CSV file.
    init(directory: URL? = nil) {
        // By default, store the file inside the app's Documents folder.
        let base = directory ?? FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        self.fileURL = base.appendingPathComponent(Self.fileName)
        // Make sure the file exists (with its CSV header).
        ensureFileExists()
        // Count how many samples already exist for each sign.
        refreshCounts()
    }

    // Turns recording on or off.
    func setRecording(_ recording: Bool) {
        isRecording = recording
    }

    /// Saves a 30-frame window (42 numbers per frame) to the CSV file, if recording is on.
    func capture(window: [[Float]]) {
        guard isRecording else { return }
        guard window.count == windowSize else { return }
        // Quick safety check: all frames must have the right number of values.
        for frame in window where frame.count != featureCount { return }

        let label = selectedLabel
        // Build a single CSV line: label + all the numbers in the window.
        let row = makeCSVRow(label: label, window: window)

        // Write the line to the file from a background queue.
        queue.async { [fileURL] in
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                if let data = row.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                return
            }
        }

        // Update the counter shown in the UI.
        sampleCounts[label, default: 0] += 1
    }

    // Erases the CSV file and recreates an empty one with just the header.
    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
        ensureFileExists()
        refreshCounts()
    }

    // MARK: - Internals

    // Creates the CSV file with its header line if it doesn't exist yet.
    private func ensureFileExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            let header = makeHeader()
            try? header.data(using: .utf8)?.write(to: fileURL)
        }
    }

    // Reads the CSV file and counts how many samples each sign already has.
    private func refreshCounts() {
        var counts: [GestureLabel: Int] = [:]
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else {
            sampleCounts = counts
            return
        }
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" })
        // Skip the first line (it's the header).
        for (i, line) in lines.enumerated() where i > 0 {
            let firstField = line.split(separator: ",", maxSplits: 1).first.map(String.init)
            if let raw = firstField, let label = GestureLabel(rawValue: raw) {
                counts[label, default: 0] += 1
            }
        }
        sampleCounts = counts
    }

    // Builds the first line of the CSV (the column names).
    // Example: "label,f0_x0,f0_y0,f0_x1,...,f29_y20"
    private func makeHeader() -> String {
        var columns: [String] = ["label"]
        for t in 0..<windowSize {
            for j in 0..<(featureCount / 2) {
                columns.append("f\(t)_x\(j)")
                columns.append("f\(t)_y\(j)")
            }
        }
        return columns.joined(separator: ",") + "\n"
    }

    // Builds one line of the CSV for a single sample (one window).
    private func makeCSVRow(label: GestureLabel, window: [[Float]]) -> String {
        var fields: [String] = [label.rawValue]
        fields.reserveCapacity(1 + windowSize * featureCount)
        for frame in window {
            for value in frame {
                fields.append(String(format: "%.6f", value))
            }
        }
        return fields.joined(separator: ",") + "\n"
    }
}
