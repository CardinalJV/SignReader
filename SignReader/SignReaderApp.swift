//
//  SignReaderApp.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 24/04/2026.
//

import SwiftUI

// This is the entry point of the app.
// `@main` tells Swift: "start the app from here".
// When the app launches, it opens a window that shows `ContentView`.
@main
struct SignReaderApp: App {
    // `body` describes the scenes (windows) of the app.
    var body: some Scene {
        // A WindowGroup is the main window. Inside it we put our first screen.
        WindowGroup {
            ContentView()
        }
    }
}
