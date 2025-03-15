//
//  PeaceWalkerApp.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//


import SwiftUI
import SwiftData

@main
struct PeaceWalkerApp: App {
    @State private var showSplashScreen: Bool = !UserDefaults.standard.bool(forKey: "hasShownSplashScreen")

    var body: some Scene {
        WindowGroup {
            if showSplashScreen {
                SplashScreenView(showSplashScreen: $showSplashScreen)
            } else {
                ContentView()
                    .modelContainer(for: [UserProfile.self, Journey.self, WalkSession.self])
            }
        }
    }
}