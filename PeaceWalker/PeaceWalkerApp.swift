import SwiftUI
import SwiftData

@main
struct PeaceWalkerApp: App {
    @State private var showSplashScreen: Bool = !UserDefaults.standard.bool(forKey: "hasShownSplashScreen")

    var body: some Scene {
        WindowGroup {
            if showSplashScreen {
                SplashScreenView(showSplashScreen: $showSplashScreen)
                    .onDisappear {
                        // Set the flag in UserDefaults to indicate the splash screen has been shown
                        UserDefaults.standard.set(true, forKey: "hasShownSplashScreen")
                    }
            } else {
                ContentView()
                    .modelContainer(for: [Journey.self, WalkSession.self])
            }
        }
    }
}
