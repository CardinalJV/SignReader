//
//  CameraPreviewView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import AVFoundation
import SwiftUI
import UIKit

// SwiftUI does not natively show the live camera, so we use UIKit (older Apple framework)
// to display it. `UIViewRepresentable` is the bridge between SwiftUI and UIKit.
struct CameraPreviewView: UIViewRepresentable {
    // The camera session that provides the live video.
    let session: AVCaptureSession

    // Creates the UIKit view that displays the camera.
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        // Connects the camera session to the view.
        view.videoPreviewLayer.session = session
        // Fills the screen with the video while keeping its aspect ratio.
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        // Rotates the video to portrait orientation if supported.
        if let connection = view.videoPreviewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    // Called by SwiftUI to refresh the view if the session changes.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    // A custom UIKit view whose underlying layer is a camera preview layer.
    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
