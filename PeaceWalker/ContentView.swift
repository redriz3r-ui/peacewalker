import SwiftUI
import Foundation
import HealthKit
import SwiftData
import CoreLocation
import MapKit

struct ContentView: View {
    @State private var stepCount: Int = 0
    @State private var distanceWalked: Double = 0.0
    @State private var progressPercentage: Double = 0.0
    @State private var selectedDestination: String = "Clovis"
    @State private var isWalkSessionsVisible: Bool = false
    @State private var currentJourney: Journey?
    @State private var route: MKRoute?
    @State private var showFullRoute = false
    @State private var followProgress = false
    
    @Environment(\.modelContext) private var modelContext
    
    @Query var journeys: [Journey]
    
    let destinations = ["Kearney Park", "Clovis", "Visalia"]
    
    var body: some View {
        ZStack {
            MeshGradient(
                width: 2,
                height: 2,
                locations: gradientLocations(),
                colors: .colors(gradientColors()),
                smoothsColors: true
            )
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
                if let currentJourney = currentJourney {
                    journeyView(currentJourney: currentJourney)
                } else {
                    Button("Start Journey to \(selectedDestination)") {
                        startJourney(for: selectedDestination)
                    }
                    .padding()
                    .accessibilityLabel("Start Journey")
                    .accessibilityHint("Starts a new journey to \(selectedDestination)")
                }
                
                Spacer()
                destinationPicker()
            }
            .padding()
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                HealthKitManager.shared.requestAuthorization { success, _ in
                    if success {
                        print("[onAppear] HealthKit authorization successful.")
                        if currentJourney != nil {
                            startObservingSteps()
                            // LocationManager is now in MapView
                        }
                    } else {
                        print("[onAppear] HealthKit authorization failed.")
                        // Handle authorization failure
                    }
                }
                checkForExistingJourney(for: selectedDestination)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func journeyView(currentJourney: Journey) -> some View {
        VStack {
            // Display Journey Start Date
            Text("Journey Started: \(currentJourney.startDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .padding(.bottom, 5)
            
            progressView(currentJourney: currentJourney)
            
            ZStack(alignment: .bottomTrailing) {
                MapView(
                    route: $route,
                    progressPercentage: progressPercentage,
                    showFullRoute: showFullRoute,
                    followProgress: followProgress
                )
                .frame(height: 300)
                .cornerRadius(10)
                
                controlButtons()
                    .padding([.bottom, .trailing], 10)
            }
            
            HStack(spacing: 20) { // Adjust spacing as needed
                Button(action: {
                    isWalkSessionsVisible.toggle()
                }) {
                    HStack {
                        Image(systemName: isWalkSessionsVisible ? "eye.slash" : "eye")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        Text(isWalkSessionsVisible ? "Hide Walk Data" : "View Walk Data")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .accessibilityLabel(isWalkSessionsVisible ? "Hide Walk Data" : "View Walk Data")
                .accessibilityHint("Shows or hides the list of walk sessions")
                
                Button(action: {
                    resetJourney(for: currentJourney)
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("End Journey")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .accessibilityLabel("End Journey")
                .accessibilityHint("Resets the current journey progress")
            }
            .padding()
            
            // Show the walk sessions if the toggle is active
            if isWalkSessionsVisible {
                walkSessionsView(currentJourney: currentJourney)
            }
        }
    }
    
    private func progressView(currentJourney: Journey) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                Circle()
                    .trim(from: 0.0, to: progressPercentage)
                    .stroke(Color.blue, lineWidth: 15)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progressPercentage)
                Text("\(Int(progressPercentage * 100))%")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.blue)
            }
            .padding()
            
            VStack {
                Text("Total Steps:")
                Text("\(currentJourney.totalSteps)")
            }
            
            VStack {
                Text("Distance Walked:")
                Text("\(currentJourney.distanceWalked, specifier: "%.2f") Miles")
            }
            
            let distanceLeft = max(currentJourney.targetDistance - currentJourney.distanceWalked, 0.0)
            VStack {
                Text("Distance Left:")
                Text("\(distanceLeft, specifier: "%.2f") Miles")
            }
        }
    }
    
    private func controlButtons() -> some View {
        HStack(spacing: 8) {
            Button(action: {
                showFullRoute = true
                followProgress = false
            }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Show Full Route")
            .accessibilityHint("Displays the full route on the map")
            
            Button(action: {
                followProgress = true
                showFullRoute = false
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Follow Progress")
            .accessibilityHint("Centers the map on your current progress")
        }
    }
    
    // In walkSessionsView
    private func walkSessionsView(currentJourney: Journey) -> some View {
        VStack {
            Text("All Walk Sessions:")
                .font(.headline)
            ScrollView {
                ForEach(currentJourney.walkSessions) { walkSession in
                    VStack(alignment: .leading) {
                        Text("Walk on \(walkSession.startTime.formatted(date: Date.FormatStyle.DateStyle.abbreviated, time: Date.FormatStyle.TimeStyle.shortened))")
                        Text("  - Steps: \(walkSession.steps)")
                        Text("  - Distance: \(walkSession.distance, specifier: "%.2f") miles")
                    }
                    .padding(.bottom, 5)
                }
            }
            .frame(maxHeight: 500) // Adjust the height as needed
        }
        .padding()
    }
    
    private func destinationPicker() -> some View {
        Picker("Select Destination", selection: $selectedDestination) {
            ForEach(destinations, id: \.self) { destination in
                Text(destination)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(10)
        .padding(.bottom, 20)
        .onChange(of: selectedDestination) {
            print("[onChange] Destination switched to \(selectedDestination)")
            checkForExistingJourney(for: selectedDestination)
        }
    }
    // MARK: - Gradient Helper Functions
    private func gradientColors() -> [Color] {
        // Define colors for a gradient from blue at the bottom to black at the top
        let color1 = Color.black     // Top-left
        let color2 = Color.black     // Top-right
        let color3 = Color.blue      // Bottom-left
        let color4 = Color.blue      // Bottom-right

        return [color1, color2, color3, color4]
    }

    private func gradientLocations() -> MeshGradient.Locations {
        // Define a simple 2x2 grid of points covering the entire view
        let points: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.66),
            SIMD2<Float>(1.0, 0.66),
            SIMD2<Float>(0.0, 1.0),
            SIMD2<Float>(1.0, 1.0)
        ]

        return .points(points)
    }
    // MARK: - Helper Functions
    
    private func getCurrentJourney() -> Journey? {
        return journeys.first(where: { $0.destination == selectedDestination })
    }
    
    private func resetJourney(for journey: Journey) {
        modelContext.delete(journey)
        do {
            try modelContext.save()
            currentJourney = nil
            progressPercentage = 0.0
            stepCount = 0
            distanceWalked = 0.0
            HealthKitManager.shared.stopRealTimeTracking()
            // LocationManager is now in MapView
        } catch {
            print("Failed to reset journey: \(error.localizedDescription)")
            // Handle the error, e.g., show an alert
        }
    }
    
    private func startJourney(for destination: String) {
        guard let destinationCoordinates = RouteManager.shared.destinationData[destination] else {
            print("Destination info not found for \(destination)")
            return
        }

        // Obtain user location using CLLocationManager
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        guard let userLocation = locationManager.location?.coordinate else {
            print("User location not available.")
            return
        }

        let startCoordinate = userLocation // Define startCoordinate

        // Calculate the route using the startCoordinate
        RouteManager.shared.calculateWalkingRoute(from: startCoordinate, to: destinationCoordinates) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let route):
                    self.route = route

                    // Use the actual distance from the route as the target distance (convert meters to miles)
                    let actualTargetDistance = route.distance / 1609.34

                    // Create newJourney after obtaining the route
                    let newJourney = Journey(
                        startDate: Date(),
                        startLocation: "User's Current Location",
                        destination: destination,
                        targetDistance: actualTargetDistance
                    )

                    // Set startLatitude and startLongitude
                    newJourney.startLatitude = startCoordinate.latitude
                    newJourney.startLongitude = startCoordinate.longitude

                    // Save newJourney and update state
                    self.modelContext.insert(newJourney)
                    do {
                        try self.modelContext.save()
                        self.currentJourney = newJourney
                        self.progressPercentage = 0.0
                        self.startObservingSteps()
                        // LocationManager is now in MapView
                    } catch {
                        print("Failed to start journey: \(error.localizedDescription)")
                        // Handle the error, e.g., show an alert
                    }
                case .failure(let error):
                    print("Error calculating route: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    
    private func checkForExistingJourney(for destination: String) {
        if let journey = getCurrentJourney() {
            currentJourney = journey
            progressPercentage = ProgressManager.shared.getCurrentProgress(journey: journey)

            // Use the stored startCoordinate
            guard let startLatitude = journey.startLatitude,
                  let startLongitude = journey.startLongitude,
                  let destinationCoordinates = RouteManager.shared.destinationData[destination] else {
                print("Unable to retrieve coordinates for existing journey.")
                return
            }

            let startCoordinate = CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
            // Recalculate the route using the stored start coordinate
            RouteManager.shared.calculateWalkingRoute(from: startCoordinate, to: destinationCoordinates) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let route):
                        self.route = route
                    case .failure(let error):
                        print("Error calculating route: \(error.localizedDescription)")
                    }
                }
            }

            startObservingSteps()
            // LocationManager is now in MapView
        } else {
            currentJourney = nil
            progressPercentage = 0.0
            route = nil
            HealthKitManager.shared.stopRealTimeTracking()
            // LocationManager is now in MapView
        }
    }
    
    private func startObservingSteps() {
        guard let journey = self.currentJourney else { return }

        HealthKitManager.shared.startRealTimeTracking(from: journey.startDate) { newSteps in
            DispatchQueue.main.async {
                if let journey = self.currentJourney {
                    // Check if the journey is already complete
                    let currentProgress = ProgressManager.shared.getCurrentProgress(journey: journey)
                    if currentProgress >= 1.0 {
                        print("Journey is complete. No further steps will be counted.")
                        // Optionally, stop observing steps
                        HealthKitManager.shared.stopRealTimeTracking()
                        return
                    }

                    // Calculate steps since last update
                    let stepsSinceLastUpdate = newSteps - journey.totalSteps

                    // Only proceed if there are new steps
                    if stepsSinceLastUpdate > 0 {
                        // Estimate distance for this session
                        let averageStepLengthInMiles = 0.000473
                        let sessionDistance = Double(stepsSinceLastUpdate) * averageStepLengthInMiles

                        // Adjust sessionDistance if it exceeds the remaining distance
                        let remainingDistance = journey.targetDistance - journey.distanceWalked
                        let adjustedSessionDistance = min(sessionDistance, remainingDistance)

                        // Adjust stepsSinceLastUpdate proportionally
                        let adjustedSteps = Int(Double(stepsSinceLastUpdate) * (adjustedSessionDistance / sessionDistance))

                        // Create a new WalkSession
                        let walkSession = WalkSession(
                            startTime: Date(),
                            steps: adjustedSteps,
                            distance: adjustedSessionDistance
                        )
                        journey.walkSessions.append(walkSession)

                        // Update journey totals
                        journey.totalSteps += adjustedSteps
                        journey.distanceWalked += adjustedSessionDistance

                        // Update progress
                        self.progressPercentage = ProgressManager.shared.getCurrentProgress(journey: journey)

                        // If journey is now complete, stop observing steps
                        if self.progressPercentage >= 1.0 {
                            print("Journey has reached 100% completion.")
                            HealthKitManager.shared.stopRealTimeTracking()
                        }

                        do {
                            try self.modelContext.save()
                        } catch {
                            print("Failed to save journey progress: \(error.localizedDescription)")
                        }
                    } else {
                        // No new steps since last update; do not create a new WalkSession
                        print("No new steps since last update.")
                    }
                }
            }
        }
    }
}
