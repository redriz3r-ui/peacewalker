//
//  SplashScreenView.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//


import SwiftUI
import Combine

struct SplashScreenView: View {
    @Binding var showSplashScreen: Bool
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            Text("Welcome to PeaceWalker")
                .font(.largeTitle)
            Spacer()
            Button("Get Started") {
                requestPermissions()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }

    private func requestPermissions() {
        HealthKitManager.shared.requestAuthorization()
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    print("HealthKit authorization failed")
                }
            }, receiveValue: { success in
                if success {
                    UserDefaults.standard.set(true, forKey: "hasShownSplashScreen")
                    showSplashScreen = false
                }
            })
            .store(in: &cancellables)
    }
}