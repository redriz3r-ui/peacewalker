import SwiftUI
import SwiftData
import CloudKit

@main
struct PeaceWalkerApp: App {
    @State private var showSplashScreen: Bool = !UserDefaults.standard.bool(forKey: "hasShownSplashScreen")

    var body: some Scene {
        WindowGroup {
            if showSplashScreen {
                SplashScreenView(showSplashScreen: $showSplashScreen)
                    .onDisappear {
                        UserDefaults.standard.set(true, forKey: "hasShownSplashScreen")
                    }
            } else {
                ContentView()
                    .modelContainer(for: [Journey.self, WalkSession.self])
            }
        }
    }
}
