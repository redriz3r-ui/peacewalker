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
    @State private var currentJourney: Journey?
    @State private var route: MKRoute?
    @State private var showFullRoute = false
    @State private var followProgress = false
    @State private var isFreeRoam: Bool = true // Default to free roam
    @State private var centerOnUser: Bool = false
    @State private var remainingRegenerations: Int = 5 // Limit to 5 regenerations per day
    @State private var collectedPinCount: Int = 0
    @State private var totalPins: Int = 0

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

            // Control Buttons Overlay
            VStack {
                controlButtons()
                Spacer()
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
            }
        }
    }

    // MARK: - Control Buttons
    private func controlButtons() -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: {
                    generatePins()
                }) {
                    VStack {
                        Text("\(remainingRegenerations)")
                            .font(.headline)
                    }
                    .padding()
                    .background(remainingRegenerations > 0 ? Color.blue.opacity(0.7) : Color.gray.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .disabled(remainingRegenerations <= 0)

                Button(action: {
                    startNewJourney()
                }) {
                    VStack {
                        Image(systemName: "play.fill")
                    }
                    .padding()
                    .background(currentJourney == nil ? Color.green.opacity(0.7) : Color.gray.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .disabled(currentJourney != nil) // Disable if a journey is already active
            }

            // Manual Refresh Button for Debugging
            Button(action: {
                print("[Manual Refresh] Checking proximity manually...")
                checkPinProximity()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .clipShape(Circle())
            }
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
        remainingRegenerations -= 1
        print("[ContentView] Generated Ring-Based Pins. Remaining regenerations: \(remainingRegenerations)")
    }
    // MARK: - Start New Journey
    private func startNewJourney() {
        guard !navigationManager.pins.isEmpty else {
            print("[Error] No pins available to start a journey.")
            return
        }

        let totalPins = navigationManager.pins.count
        let collectedPins = collectedPinCount

        currentJourney = Journey(
            startDate: Date(),
            startLocation: "Your Location",
            targetDistance: 1.0 // Set dynamically based on total pin distance
        )

        print("[Journey] New journey started: \(collectedPins)/\(totalPins) Collected.")
        startObservingSteps()
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
        print("[Proximity] User Location: \(userLocation.latitude), \(userLocation.longitude)")

        let collectionRadius: Double = 50 // Proximity radius in meters

        for (index, pin) in navigationManager.pins.enumerated() {
            let pinCLLocation = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
            let distance = userCLLocation.distance(from: pinCLLocation)

            print("[Proximity] Pin \(index) at \(pin.coordinate.latitude), \(pin.coordinate.longitude): Distance = \(distance) meters")

            if distance <= collectionRadius {
                print("[Proximity] Pin \(index) is within \(collectionRadius)m radius. Collecting...")
                collectPin(at: index)
                break // Prevent multiple simultaneous collections
            }
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

    // MARK: - Progress View
    private func progressView() -> some View {
        VStack(spacing: 10) {
            // Active Journey Indicator
            if let journey = currentJourney {
                VStack {
                    HStack{
                        Text("Active Journey ")
                            .font(.subheadline)
                            .padding(8)
                            .frame(maxWidth: .infinity)
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
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Progress Bar
            VStack(spacing: 5) {
                HStack {
                    Text("\(stepCount) steps")
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
