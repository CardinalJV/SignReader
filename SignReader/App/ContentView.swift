//
//  ContentView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// This is the main screen of the app.
// It shows the camera, the hand landmarks, the buttons, and the captured letters.
struct ContentView: View {

    // The view model holds the data and logic for the main screen.
    // `@StateObject` keeps it alive while this screen is on screen.
    @StateObject private var viewModel = GestureRecognitionViewModel()
    // Tells if the "phrases" pop-up should be visible or not.
    @State private var showPhrases = false

    var body: some View {
        // NavigationStack allows us to push other screens (Signs, Settings, ...).
        NavigationStack {
            // ZStack stacks views on top of each other (back to front).
            ZStack {
                // Background color filling the whole screen.
                Color(.systemBackground).ignoresSafeArea()

                // If the user gave camera permission, show the live camera.
                // Otherwise, show a screen that asks for permission.
                if viewModel.isCameraAuthorized {
                    CameraPreviewView(session: viewModel.cameraSession.session)
                        .ignoresSafeArea()
                } else {
                    PermissionView()
                }

                // Optional drawing of the hand "skeleton" on top of the camera.
                if viewModel.settings.landmarkOverlayEnabled {
                    LandmarkOverlayView(landmarks: viewModel.landmarks)
                        .ignoresSafeArea()
                }

                // VStack stacks views vertically (top to bottom).
                VStack {
                    // Top row of buttons (camera switch, signs list, settings).
                    HStack(alignment: .top) {
                        Spacer()

                        GlassEffectContainer(spacing: 12) {
                            HStack(spacing: 12) {
                                // Button to flip between front and back camera.
                                Button {
                                    viewModel.cameraSession.switchCamera()
                                } label: {
                                    Image(systemName: "camera.rotate")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .padding(10)
                                        .glassEffect(in: Circle())
                                }

                                // Button (link) that opens the list of signs.
                                NavigationLink {
                                    SignsListView()
                                } label: {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .padding(10)
                                        .glassEffect(in: Circle())
                                }

                                // Button (link) that opens the Settings screen.
                                NavigationLink {
                                    SettingsView(viewModel: viewModel)
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .padding(10)
                                        .glassEffect(in: Circle())
                                }
                            }
                        }
                        .tint(.primary)
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()

                    // Bottom right: button that opens the phrases picker.
                    HStack {
                        Spacer()
                        Button {
                            showPhrases = true
                        } label: {
                            Image(systemName: "quote.bubble.fill")
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .padding(10)
                                .glassEffect(in: Circle())
                        }
                        .tint(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                    // The bottom panel showing captured letters and the current sign.
                    CapturePanelView(
                        typedText: viewModel.typedText,
                        result: viewModel.currentResult,
                        commitProgress: viewModel.commitProgress,
                        commitDuration: GestureRecognitionViewModel.commitDuration,
                        onClear: viewModel.clearTypedText,
                        onSpeak: viewModel.speakTypedText
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            // Hide the navigation bar and the status bar to keep a clean camera view.
            .navigationBarHidden(true)
            .statusBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        // Runs once the view appears: starts the camera and the recognition.
        .task {
            await viewModel.start()
        }
        // When the view disappears, stop the camera to save battery.
        .onDisappear {
            viewModel.stop()
        }
        // Shows the phrases picker as a sheet (pop-up from the bottom).
        .sheet(isPresented: $showPhrases) {
            PhrasesPickerView { phrase in
                viewModel.insertPhrase(phrase)
            }
        }
    }
}

// Small panel at the bottom of the screen.
// It shows the letters already captured and information about the current sign.
private struct CapturePanelView: View {
    // The text typed so far (letters validated one by one).
    let typedText: String
    // The current sign being seen by the camera (with its confidence).
    let result: GestureResult
    // A number from 0 to 1 showing how close we are to validating the current sign.
    let commitProgress: Double
    // The total time (in seconds) needed to validate a sign.
    let commitDuration: TimeInterval
    // Called when the user taps the "clear" button.
    let onClear: () -> Void
    // Called when the user taps the "speak" button.
    let onSpeak: () -> Void

    // True if the current sign is a real letter (not "unknown" or "nothing").
    private var hasLetter: Bool {
        result.label != .unknown && result.label != .nothing
    }

    // How many seconds are left before the sign is validated.
    private var remaining: Double {
        max(0, commitDuration * (1 - commitProgress))
    }

    // The confidence to display in the small circular meter.
    private var displayedConfidence: Float {
        hasLetter ? result.confidence : 0
    }

    // A trailing committed space is invisible at the end of a line, so render it as
    // an underscore until the next letter lands and the space gains a neighbor.
    private var displayedTypedText: String {
        guard typedText.hasSuffix(" ") else { return typedText }
        return String(typedText.dropLast()) + "_"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // First line: captured letters
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Captured")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(typedText.isEmpty ? "…" : displayedTypedText)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3, reservesSpace: false)
                        .truncationMode(.head)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !typedText.isEmpty {
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Circle().fill(Color.primary.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Read captured letters"))

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .background(Color.primary.opacity(0.12))

            // Second line: current letter + timer (left) / HOLD-SHOW + circular confidence (right)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if hasLetter {
                        Text(result.label.displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text("—")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if hasLetter && commitProgress > 0 {
                        Text(String(format: "%.1fs", remaining))
                            .font(.system(.footnote, design: .monospaced).weight(.medium))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: result.label)

                Spacer(minLength: 8)

                Text(hasLetter ? "HOLD" : "SHOW")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospaced()
                    .animation(.easeInOut(duration: 0.2), value: hasLetter)

                ConfidenceMeterView(confidence: displayedConfidence)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

// Screen shown when the user has not given camera permission.
// It explains the problem and offers a button to open the Settings app.
private struct PermissionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Enable the camera in Settings to recognize gestures.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.primary.opacity(0.15)))
                    .foregroundStyle(.primary)
            }
        }
    }
}
