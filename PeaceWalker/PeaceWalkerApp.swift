//
//  PeaceWalkerApp.swift
//  PeaceWalker
//
//  Created by Robe on 11/7/24.
//

import SwiftUI
import SwiftData

@main
struct PeaceWalkerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Journey.self, WalkSession.self])
        }
    }
}
