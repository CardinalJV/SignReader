//
//  DataCollectionView.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import SwiftUI

// Screen used to record training samples that will be used to train the ML model.
// The user picks a sign, taps Record, and the app saves what the camera sees as data.
struct DataCollectionView: View {
    // Bindable lets us change the data collector's properties from this view.
    @Bindable var dataCollector: DataCollector
    // True while the "delete confirmation" dialog is showing.
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            // Picker to choose which sign we want to record samples for.
            Section("Label") {
                Picker("Gesture", selection: $dataCollector.selectedLabel) {
                    ForEach(GestureLabel.trainableCases) { label in
                        HStack {
                            Text(label.emoji)
                            Text(label.displayName)
                        }
                        .tag(label)
                    }
                }
                .pickerStyle(.menu)
            }

            // Start/Stop recording button.
            Section("Recording") {
                Button {
                    dataCollector.setRecording(!dataCollector.isRecording)
                } label: {
                    HStack {
                        Image(systemName: dataCollector.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.title2)
                        Text(dataCollector.isRecording ? "Stop Recording" : "Record")
                    }
                }
                .tint(dataCollector.isRecording ? .red : .accentColor)
            }

            // List of every sign and how many samples we have for it.
            Section("Samples Collected") {
                ForEach(GestureLabel.trainableCases) { label in
                    HStack {
                        Text(label.emoji)
                        Text(label.displayName)
                        Spacer()
                        Text("\(dataCollector.sampleCounts[label] ?? 0)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Button to share the CSV file, and button to delete everything.
            Section("Export / Reset") {
                ShareLink(item: dataCollector.fileURL) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Data Collection")
        .navigationBarTitleDisplayMode(.inline)
        // Safety: stop recording if the user leaves the screen.
        .onDisappear {
            dataCollector.setRecording(false)
        }
        // Confirmation dialog before erasing the CSV file.
        .confirmationDialog("Delete all samples?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dataCollector.deleteAll()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}
