//
//  CameraSession.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import AVFoundation
import Combine
import UIKit

// Manages the iPhone camera.
// Responsibilities: ask permission, start/stop, switch front/back, deliver frames.
nonisolated final class CameraSession: NSObject, @unchecked Sendable {
    // The Apple object that controls the camera.
    let session = AVCaptureSession()
    // Each new camera frame is sent through this "publisher" (event stream).
    let sampleBufferPublisher = PassthroughSubject<CMSampleBuffer, Never>()
    // Sends `true` when the camera is interrupted (e.g. phone call), `false` when it resumes.
    let interruptionPublisher = PassthroughSubject<Bool, Never>()

    // Background queue used to configure/start/stop the session safely.
    private let sessionQueue = DispatchQueue(label: "com.signlens.camera.session")
    // Background queue used to receive each camera frame.
    private let videoQueue = DispatchQueue(
        label: "com.signlens.camera",
        qos: .userInitiated
    )
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoInput: AVCaptureDeviceInput?
    // System notifications we subscribe to (interruption, app background, ...).
    private var observers: [NSObjectProtocol] = []
    private(set) var isConfigured = false

    override init() {
        super.init()
        // Listen to system events to pause/resume the camera automatically.
        registerObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // Asks the user for permission to access the camera (if not already answered).
    // Returns true if we have permission, false otherwise.
    func requestAuthorizationIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // Starts the camera. Configures it the first time it's called.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configure()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // Stops the camera.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // Switches between the front and the back camera.
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            // Make sure the session is set up before changing the camera.
            if !self.isConfigured {
                self.configure()
            }

            guard let currentInput = self.videoInput else { return }
            let currentPosition = currentInput.device.position
            // Pick the opposite camera (front <-> back).
            let newPosition: AVCaptureDevice.Position = (currentPosition == .front) ? .back : .front

            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)

                self.session.beginConfiguration()
                // Remove current input first
                self.session.removeInput(currentInput)

                // Try to add the new input; if it fails, restore the old input
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoInput = newInput

                    // Re-apply desired frame rate on the new device
                    self.configureFrameRate(on: newDevice, targetFPS: 60)

                    // Update connection settings (rotation + mirroring)
                    if let connection = self.videoOutput.connection(with: .video) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                        if connection.isVideoMirroringSupported {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = (newPosition == .front)
                        }
                    }
                } else {
                    // Restore old input on failure
                    if self.session.canAddInput(currentInput) {
                        self.session.addInput(currentInput)
                    }
                }

                self.session.commitConfiguration()
            } catch {
                // If creating the new input fails, do nothing
                return
            }
        }
    }

    // First-time setup of the camera: choose the device, set the resolution,
    // configure the output, the rotation and the mirroring.
    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            return
        }

        configureFrameRate(on: device, targetFPS: 60)

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }
        } catch {
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            // iOS 17+ rotation API. 90° = portrait sur iPhone, et — depuis qu'on
            // restreint Mac Catalyst à landscape-only — donne aussi l'orientation
            // correcte sur Mac.
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        isConfigured = true
    }

    // Picks the highest-resolution camera format that supports the desired frames-per-second.
    private func configureFrameRate(on device: AVCaptureDevice, targetFPS: Double) {
        // Choisir le format avec la plus grande résolution parmi ceux qui supportent
        // `targetFPS`. Sans ce tri, `first(where:)` tombait sur un format basse résolution
        // (genre 352×288) qui rendait l'image floue, surtout après un switch de caméra.
        let candidates = device.formats.filter { format in
            format.videoSupportedFrameRateRanges.contains { range in
                range.maxFrameRate >= targetFPS
            }
        }
        guard let format = candidates.max(by: { a, b in
            let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
            let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
            return (Int(da.width) * Int(da.height)) < (Int(db.width) * Int(db.height))
        }) else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    // Subscribes to system notifications so the camera reacts well to:
    // - interruptions (incoming call, Siri, ...)
    // - app entering/leaving background.
    private func registerObservers() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.interruptionPublisher.send(true)
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.interruptionPublisher.send(false)
            self?.start()
        })

        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        })

        observers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.start()
        })
    }
}

// Called by the system each time the camera produces a new frame.
// We just forward the frame to our publisher so the rest of the app can use it.
nonisolated extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        sampleBufferPublisher.send(sampleBuffer)
    }
}
