//
//  ContentView.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//


import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext // Grab from environment
    
    var body: some View {
        TabView {
            ProgressView(viewModel: ProgressViewModel()) // No modelContext
                .tabItem { Label("Progress", systemImage: "chart.bar") }
            MapView(modelContext: modelContext) // Pass it explicitly
                .tabItem { Label("Map", systemImage: "map") }
        }
    }
}

