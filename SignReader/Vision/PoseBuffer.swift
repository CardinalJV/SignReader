//
//  PoseBuffer.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import Combine
import Foundation

/// Keeps the most recent N frames in memory (a "sliding window").
/// We use a circular array internally so adding a new frame is very fast.
/// Once the window is full, every new frame returns the last N frames in order.
nonisolated final class PoseBuffer {
    // Number of frames kept in the window (about 0.5s at 60fps).
    static let windowSize = 30

    // Publishes the current window (or nil if not full yet).
    let windowPublisher = CurrentValueSubject<[[Float]]?, Never>(nil)

    private let capacity: Int            // Max number of frames.
    private var storage: [[Float]?]      // Circular storage of size `capacity`.
    private var head = 0                 // Index where the next frame will be written.
    private var filled = 0               // Number of frames currently stored.
    // A lock so we can safely append from multiple threads.
    private let lock = NSLock()

    init(capacity: Int = PoseBuffer.windowSize) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    /// Adds a new frame to the buffer.
    /// While the buffer is filling up: returns nil.
    /// Once full: returns the last `capacity` frames in order (oldest → newest).
    @discardableResult
    func append(_ frame: [Float]) -> [[Float]]? {
        lock.lock()
        defer { lock.unlock() }

        // Overwrite the oldest spot with the new frame.
        storage[head] = frame
        head = (head + 1) % capacity
        if filled < capacity { filled += 1 }

        // Still filling? Don't publish a window yet.
        guard filled == capacity else {
            windowPublisher.send(nil)
            return nil
        }

        // Build a fresh window in chronological order.
        var window: [[Float]] = []
        window.reserveCapacity(capacity)
        for offset in 0..<capacity {
            let index = (head + offset) % capacity
            if let frame = storage[index] {
                window.append(frame)
            }
        }
        windowPublisher.send(window)
        return window
    }

    // Clears the buffer (used after camera interruptions to avoid stale data).
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        storage = Array(repeating: nil, count: capacity)
        head = 0
        filled = 0
        windowPublisher.send(nil)
    }
}
