import SwiftUI
import Foundation
import HealthKit
import CoreLocation
import MapKit

struct ContentView: View {
    // MARK: - State Variables
    @State private var stepCount: Int = 0
    @State private var distanceWalked: Double = 0.0
    @State private var progressPercentage: Double = 0.0
    @State private var currentJourney: Journey? // Determines the UI state
    @State private var route: MKRoute?
    @State private var showFullRoute = false
    @State private var followProgress = false
    @State private var isFreeRoam: Bool = true // Default to free roam
    @State private var centerOnUser: Bool = false
    @State private var remainingRegenerations: Int = 5 // Limit to 5 regenerations per day
    @State private var collectedPinCount: Int = 0
    @State private var totalPins: Int = 0
    @State private var isNearPin: Bool = false
    @State private var nearbyPinIndex: Int? = nil
    @State private var selectedPin: Pin? // To hold the tapped pin's data
    @State private var showPinInfo: Bool = false // To toggle the info view
    @State private var dailyLimit: Int = 5 // Free limit
    @State private var isSubscribed: Bool = false // Track subscription status
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var locationManager = MapView.LocationManager()
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // MapView
            MapView(
                route: $route,
                progressPercentage: progressPercentage,
                showFullRoute: showFullRoute && currentJourney != nil,
                followProgress: followProgress && currentJourney != nil,
                centerOnUser: $centerOnUser
            )
            
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Overlay UI
            VStack(spacing: 5) {
                if currentJourney != nil {
                    
                }
                
                Spacer()
                if currentJourney == nil {
                    // Before Journey UI
                    beforeJourneyButtons()
                } else {
                    // Active Journey UI
                    activeJourneyUI()
                }
                
                progressView() // Persistent daily progress bar
                    .padding(.top, 10)
            }
            .padding()
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                HealthKitManager.shared.requestAuthorization { success, _ in
                    if success {
                        print("[onAppear] HealthKit authorization successful.")
                        startObservingSteps()
                        startProximityMonitoring() // Start monitoring proximity
                    } else {
                        print("[onAppear] HealthKit authorization failed.")
                    }
                }
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    checkPinProximity()
                }
                checkDailyReset()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(""),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Before Journey Buttons
    private func beforeJourneyButtons() -> some View {
        HStack(spacing: 10) {
            // Generate Pins Button
            Button(action: {
                if remainingRegenerations > 0 || isSubscribed {
                    generatePins()
                } else {
                    showAlert = true
                    alertMessage = "No generations remaining for today. Please wait until reset or subscribe for unlimited generations."
                }
            }) {
                VStack {
                    Text(remainingRegenerations > 0 || isSubscribed ? "Generate Pins" : "No Generations Left")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background((remainingRegenerations > 0 || isSubscribed) ? Color.blue.opacity(0.7) : Color.gray.opacity(0.7))
                .cornerRadius(8)
            }
            .disabled(remainingRegenerations <= 0 && !isSubscribed) // Disable button if no regenerations left and user isn't subscribed
            
            // Start Journey Button
            if remainingRegenerations <= 0 && !isSubscribed && navigationManager.pins.isEmpty {
                CountdownTimerView() // Show countdown when out of generations and no pins are available
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.7))
                    .cornerRadius(8)
            } else {
                Button(action: {
                    if navigationManager.pins.isEmpty {
                        showAlert = true
                        alertMessage = "No pins available to start a journey. Generate pins first."
                    } else {
                        startNewJourney()
                    }
                }) {
                    VStack {
                        Image(systemName: "play.fill")
                            .font(.headline)
                        Text("Start Journey")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(currentJourney == nil ? Color.green.opacity(0.7) : Color.gray.opacity(0.7))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .disabled(currentJourney != nil) // Disable if a journey is already active
            }
        }
        .padding(10) // Add padding around the buttons
    }
    
    // MARK: - Active Journey UI
    private func activeJourneyUI() -> some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    endJourney()
                }) {
                    Text("End Journey")
                        .font(.headline)
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                
                HStack {
                    ForEach(0..<totalPins, id: \.self) { index in
                        Image(systemName: index < collectedPinCount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(index < collectedPinCount ? .white : .white)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(8)
            }
            
            // Collect Pin Button (always visible)
            Button(action: {
                if isNearPin, let index = nearbyPinIndex {
                    collectPin(at: index) // Collect the nearby pin
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isNearPin ? Color.blue : Color.gray)
                        .frame(maxWidth: .infinity, minHeight: 50) // Ensure a large tappable area
                    
                    if isNearPin {
                        Text("Collect Pin")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else if let nearestIndex = nearbyPinIndex {
                        let nearestPin = navigationManager.pins[nearestIndex]
                        let userCLLocation = CLLocation(latitude: locationManager.location?.latitude ?? 0, longitude: locationManager.location?.longitude ?? 0)
                        let pinCLLocation = CLLocation(latitude: nearestPin.coordinate.latitude, longitude: nearestPin.coordinate.longitude)
                        let stepsToNearestPin = Int(pinCLLocation.distance(from: userCLLocation) / 0.762) // Steps calculation
                        
                        Text("Nearest Pin: \(stepsToNearestPin) Steps")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Text("No Pins Nearby")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 50) // Ensure the button has consistent height
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    // MARK: - Progress View
    private func progressView() -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 5) {
                HStack {
                    Text("Today's Steps: \(stepCount)")
                        .font(.headline)
                }
                .padding(.horizontal)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 20)
                        
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.green]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(
                            width: CGFloat(min(Double(stepCount) / 10_000.0, 1.0)) * geometry.size.width,
                            height: 20
                        )
                        .cornerRadius(10)
                    }
                }
                .frame(height: 20)
                .padding(.horizontal)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
            .shadow(radius: 5)
        }
    }
    
    // MARK: - Generate Pins
    private func generatePins() {
        guard remainingRegenerations > 0 || isSubscribed else {
            print("[Error] No generations remaining for today.")
            return
        }
        
        guard let userLocation = locationManager.location else {
            print("[Error] User location not available for pin generation.")
            return
        }
        
        if navigationManager.pins.isEmpty {
            navigationManager.generatePins(for: .ringBased, center: userLocation)
            totalPins = navigationManager.pins.count
            collectedPinCount = 0
            
            if !isSubscribed {
                remainingRegenerations -= 1
                saveRemainingGenerations()
            }
            
            print("[ContentView] Generated Ring-Based Pins. Remaining regenerations: \(remainingRegenerations)")
        } else {
            print("[Info] Pins already generated; cannot generate more without collection.")
        }
    }
    
    // MARK: - Start New Journey
    private func startNewJourney() {
        guard !navigationManager.pins.isEmpty else {
            alertMessage = "No pins available to start a journey."
            showAlert = true
            print("[Error] No pins available to start a journey.")
            return
        }
        
        currentJourney = Journey(
            startDate: Date(),
            startLocation: "Your Location",
            targetDistance: 1.0 // Set dynamically based on total pin distance
        )
        
        totalPins = navigationManager.pins.count
        collectedPinCount = 0
        
        print("[Journey] New journey started: \(collectedPinCount)/\(totalPins) Collected.")
    }
    
    
    // MARK: - Proximity Monitoring
    private func startProximityMonitoring() {
        print("[Proximity] Starting proximity monitoring...")
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            print("[Proximity] Timer triggered.")
            checkPinProximity()
        }
    }
    
    private func checkPinProximity() {
        guard let userLocation = locationManager.location else {
            print("[Proximity] User location not available.")
            return
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let collectionRadius: Double = 50 // Proximity radius in meters
        
        var nearestPinIndex: Int? = nil
        var nearestPinDistance: Double = .greatestFiniteMagnitude // Large initial value
        
        isNearPin = false
        nearbyPinIndex = nil
        
        for (index, pin) in navigationManager.pins.enumerated() {
            let pinCLLocation = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
            let distance = userCLLocation.distance(from: pinCLLocation)
            
            if distance <= collectionRadius {
                // Pin is within collection range
                isNearPin = true
                nearbyPinIndex = index
                print("[Proximity] Pin \(index) is within \(collectionRadius)m radius. Ready to collect.")
                return
            }
            
            // Track the nearest pin
            if distance < nearestPinDistance {
                nearestPinDistance = distance
                nearestPinIndex = index
            }
        }
        
        // Update nearest pin info if no pin is within collection range
        if let nearestIndex = nearestPinIndex {
            nearbyPinIndex = nearestIndex
            let stepsToNearestPin = Int(nearestPinDistance / 0.762) // Convert distance to steps
            print("[Proximity] Nearest pin at index \(nearestIndex): Distance = \(nearestPinDistance) meters (\(stepsToNearestPin) steps)")
        }
    }
    
    
    private func collectPin(at index: Int) {
        guard index >= 0 && index < navigationManager.pins.count else { return }

        let collectedPin = navigationManager.pins[index]
        navigationManager.pins.remove(at: index)
        collectedPinCount += 1

        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        print("[Collection] Collected Pin at \(collectedPin.coordinate.latitude), \(collectedPin.coordinate.longitude).")

        // Check if all pins are collected
        if navigationManager.pins.isEmpty {
            handleAllPinsCollected()
        }
    }
    
    private func endJourney() {
        print("[Journey] Journey ended by user.")
        currentJourney = nil
        collectedPinCount = 0
        totalPins = 0
        navigationManager.pins.removeAll() // Clear any active pins
        route = nil // Clear the route if it exists
        progressPercentage = 0.0 // Reset progress bar
    }
    
    private func checkDailyReset() {
        let currentDate = Calendar.current.startOfDay(for: Date()) // Normalize to midnight
        let lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date ?? Date.distantPast

        if currentDate > lastResetDate {
            // Reset the remaining generations
            remainingRegenerations = isSubscribed ? Int.max : dailyLimit
            UserDefaults.standard.set(currentDate, forKey: "lastResetDate")
            UserDefaults.standard.set(remainingRegenerations, forKey: "remainingRegenerations")
            print("[Daily Reset] Generations reset to \(remainingRegenerations).")
        } else {
            // Load the saved remaining generations
            remainingRegenerations = UserDefaults.standard.integer(forKey: "remainingRegenerations")
        }
    }
    
    private func saveRemainingGenerations() {
        UserDefaults.standard.set(remainingRegenerations, forKey: "remainingRegenerations")
    }
    
    func toggleSubscription() {
        isSubscribed.toggle()
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
        remainingRegenerations = isSubscribed ? Int.max : dailyLimit
        print(isSubscribed ? "[Subscription] Unlimited generations enabled." : "[Subscription] Free tier active.")
    }
    
    // MARK: - Step Observation
    private func startObservingSteps() {
        print("[HealthKitManager] Starting to observe steps...")

        var baselineSteps = stepCount

        HealthKitManager.shared.startObservingSteps { newSteps in
            DispatchQueue.main.async {
                let incrementalSteps = newSteps - baselineSteps
                if incrementalSteps > 0 {
                    self.stepCount += incrementalSteps
                    baselineSteps = newSteps

                    print("[Real-Time] Incremental steps: \(incrementalSteps). Total steps: \(self.stepCount).")

                    if self.stepCount >= 10_000 && !self.showAlert {
                        self.handleStepGoalReached() // Call step goal handler
                    }
                } else {
                    print("[Real-Time] No new steps detected.")
                }
            }
        }
    }
    
    struct CountdownTimerView: View {
        @State private var timeRemaining: TimeInterval = 0
        private let formatter: DateComponentsFormatter
        
        init() {
            formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
        }
        
        var body: some View {
            VStack {
                Text("Next Reset In")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(formatter.string(from: timeRemaining) ?? "Calculating...")
                    .font(.headline)
                    .foregroundColor(.white)
                    .onAppear {
                        startCountdown()
                    }
            }
        }
        
        private func startCountdown() {
            let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            timeRemaining = midnight.timeIntervalSinceNow
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
    private func handleAllPinsCollected() {
        print("[Journey] Journey completed!")
        currentJourney = nil // End the current journey

        if navigationManager.pins.isEmpty {
            alertMessage = "Congratulations! You've collected all pins for this journey. 🎉"
            showAlert = true
        } else {
            alertMessage = "Journey completed successfully! 🚶‍♂️"
            showAlert = true
        }

        if remainingRegenerations > 0 || isSubscribed {
            generatePins() // Automatically generate new pins if possible
        } else {
            alertMessage += "\nNo more generations left today. Please subscribe for unlimited pins or wait for the daily reset."
            print("[ContentView] No regenerations left for today. Pins will not regenerate.")
        }
    }
    private func handleStepGoalReached() {
        print("[Steps] Step goal of 10,000 reached!")
        
        alertMessage = "Amazing job! You've reached your step goal of 10,000 steps today! 🚶‍♂️🎉"
        showAlert = true

        // Highlight the progress bar temporarily
        withAnimation(.easeInOut(duration: 1.0)) {
            progressPercentage = 1.0 // Ensure the bar is full
        }
    }
}
