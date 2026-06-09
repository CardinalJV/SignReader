//
//  SettingsView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// Settings screen.
// Lets the user toggle speech, haptics, the landmark overlay, and reach the data collection screen.
struct SettingsView: View {
    // Reference to the main view model so we can read/write the settings.
    @ObservedObject var viewModel: GestureRecognitionViewModel

    var body: some View {
        Form {
            // Switches for the audio/vibration feedback.
            Section("Feedback") {
                Toggle("Speech", isOn: $viewModel.settings.speechEnabled)
                Toggle("Haptics", isOn: $viewModel.settings.hapticsEnabled)
            }

            // Switch to show or hide the hand skeleton on screen.
            Section("Display") {
                Toggle("Landmarks", isOn: $viewModel.settings.landmarkOverlayEnabled)
            }

            // Link to the screen used to record training samples.
            Section("Training Data") {
                NavigationLink("Sample Collection") {
                    DataCollectionView(dataCollector: viewModel.dataCollector)
                }
            }

            // Information for the user about the recognition settings used.
            Section("Info") {
                LabeledContent("Confidence Threshold", value: "65%")
                LabeledContent("Window", value: "30 frames")
                LabeledContent("Frame Rate", value: "60 fps")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
