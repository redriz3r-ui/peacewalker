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
    @State private var isCameraFree: Bool = false

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
                // End Journey Button (top-right corner)
                 HStack {
                     Spacer()
                     if currentJourney != nil {
                         Button(action: {
                             endJourney()
                         }) {
                             Image(systemName: "xmark.circle.fill")
                                 .font(.system(size: 30))
                                 .foregroundColor(.red)
                                 .padding()
                         }
                         .transition(.opacity) // Smoothly show/hide the button
                     }
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
            }
        }
    }

    // MARK: - Before Journey Buttons
    private func beforeJourneyButtons() -> some View {
        HStack(spacing: 10) {
            // Generate Pins Button
            Button(action: {
                generatePins()
            }) {
                VStack {
                    if remainingRegenerations == 5 {
                        Text("Generate Pins") // Initial text before first generation
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Text("Generations Left: \(remainingRegenerations)") // Updates after generating
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50) // Set consistent button height
                .background(remainingRegenerations > 0 ? Color.blue.opacity(0.7) : Color.gray.opacity(0.7))
                .cornerRadius(8)
            }
            .disabled(remainingRegenerations <= 0) // Disable if no regenerations left

            // Start Journey Button
            Button(action: {
                startNewJourney()
            }) {
                VStack {
                    Image(systemName: "play.fill")
                        .font(.headline)
                    Text("Start Journey")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 50) // Set consistent button height
                .background(currentJourney == nil ? Color.green.opacity(0.7) : Color.gray.opacity(0.7))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            .disabled(currentJourney != nil) // Disable if a journey is already active
        }
        .padding(10) // Add padding around the buttons
    }

    // MARK: - Active Journey UI
    private func activeJourneyUI() -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Active Journey")
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                    .foregroundColor(.white)

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
    }
    // MARK: - Progress View
    private func progressView() -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 5) {
                HStack {
                    Text("Today's Steps: \(stepCount)")
                        .font(.headline)
                    Spacer()
                    Text("10,000 steps")
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
        guard remainingRegenerations > 0 else {
            print("[Error] No regenerations remaining today.")
            return
        }

        guard let userLocation = locationManager.location else {
            print("[Error] User location not available for pin generation.")
            return
        }

        // Regenerate pins and reset collected pins
        navigationManager.generatePins(for: .ringBased, center: userLocation)
        totalPins = navigationManager.pins.count // Update total pin count
        collectedPinCount = 0 // Reset collected pin count
        remainingRegenerations -= 1 // Decrease regenerations count
        print("[ContentView] Generated Ring-Based Pins. Remaining regenerations: \(remainingRegenerations)")
    }

    // MARK: - Start New Journey
    private func startNewJourney() {
        guard !navigationManager.pins.isEmpty else {
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

    // MARK: - Complete Journey
    private func completeJourney() {
        print("[Journey] Journey completed!")
        currentJourney = nil
        if remainingRegenerations > 0 {
            generatePins()
        } else {
            print("[ContentView] No regenerations left for today. Pins will not regenerate.")
        }
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
        let collectedPin = navigationManager.pins[index]

        // Remove the pin from the NavigationManager
        navigationManager.pins.remove(at: index)
        
        // Increment collected pin count
        collectedPinCount += 1

        // Update step count
        let pinCLLocation = CLLocation(latitude: collectedPin.coordinate.latitude, longitude: collectedPin.coordinate.longitude)
        let userCLLocation = CLLocation(latitude: locationManager.location?.latitude ?? 0, longitude: locationManager.location?.longitude ?? 0)
        let distanceInMeters = userCLLocation.distance(from: pinCLLocation)
        let steps = Int(distanceInMeters / 0.762) // Average step length in meters
        stepCount += steps

        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Log the collection
        print("[Collection] Collected Pin at \(collectedPin.coordinate.latitude), \(collectedPin.coordinate.longitude). Steps added: \(steps)")

        // Check if all pins are collected
        if navigationManager.pins.isEmpty {
            completeJourney()
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

    // MARK: - Step Observation
    private func startObservingSteps() {
        HealthKitManager.shared.startObservingSteps { newSteps in
            DispatchQueue.main.async {
                self.stepCount += newSteps
                if let journey = currentJourney {
                    journey.stepCount += newSteps
                    if navigationManager.pins.isEmpty {
                        completeJourney()
                    }
                }
            }
        }
    }
}
