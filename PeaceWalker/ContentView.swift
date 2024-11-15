import SwiftUI
import Foundation
import HealthKit
import SwiftData
import CoreLocation
import MapKit

func saveLastStepCount(_ steps: Int) {
    UserDefaults.standard.set(steps, forKey: "lastStepCount")
}

func loadLastStepCount() -> Int {
    return UserDefaults.standard.integer(forKey: "lastStepCount")
}

struct ContentView: View {
    @State private var stepCount: Int = 0
    @State private var lastStepCount: Int = 0
    @State private var distanceWalked: Double = 0.0
    @State private var progressPercentage: Double = 0.0
    @State private var journeyUpdate: String = ""
    @State private var selectedDestination: String = "Visalia"
    @State private var journeyStarted: Bool = false
    @State private var journeyStartTime: Date?
    @State private var isWalkSessionsVisible: Bool = false
    @Query var journeys: [Journey]
    @State private var route: MKRoute?
    @State private var userLocation = CLLocationCoordinate2D(latitude: 36.7378, longitude: -119.7871) // Default to Fresno
    
    @Environment(\.modelContext) private var modelContext
    
    let destinations = ["Visalia", "Clovis", "Kearney Park"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("WalkMap🌎")
                    .font(.title)
                
                Text("Virtual Travel Journey")
                    .font(.caption)

                
                // Destination Picker
                Picker("Select Destination", selection: $selectedDestination) {
                    ForEach(destinations, id: \.self) { destination in
                        Text(destination)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedDestination, initial: false) { oldDestination, newDestination in
                    if oldDestination != newDestination {
                        print("[onChange] Tab switched from \(oldDestination) to \(newDestination)")
                        checkForExistingJourney(for: newDestination)
                    }
                }
                
                if journeyStarted {
                    Text(journeyUpdate)
                        .padding()
                        .foregroundColor(.blue)
                }
                
                // Display Journey Data
                if journeyStarted, let currentJourney = getCurrentJourney() {
                    VStack {
                        Text("Your Journey")
                             .font(.title)
                             .padding()

                         MapView(route: $route, userLocation: $userLocation)
                             .frame(height: 300)
                             .cornerRadius(10)
                             .padding()
                        ZStack {
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 100, height: 100)
                                .padding()

                            Text("\(Int(progressPercentage * 100))%")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        Text("Total Steps: \(currentJourney.totalSteps)")
                        Text("Distance Walked: \(currentJourney.distanceWalked, specifier: "%.2f") Miles")
                        
                        let distanceLeft = max(currentJourney.targetDistance - currentJourney.distanceWalked, 0.0)
                        Text("Distance Left: \(distanceLeft, specifier: "%.2f") Miles")
                        
                        // Button to Update Progress
                        Button("Update Steps") {
                            print("[Update Steps] Button pressed")
                            updateProgress(for: currentJourney)
                                
                        }
                        .padding()
                        
                        // Button to Toggle Walk Sessions List
                        Button("Show/Hide Walk Sessions") {
                            isWalkSessionsVisible.toggle()
                            print("[Walk Sessions] Toggled visibility to \(isWalkSessionsVisible)")
                        }
                        
                        if isWalkSessionsVisible {
                            Text("All Walk Sessions:")
                                .font(.headline)
                            ForEach(currentJourney.walkSessions) { session in
                                VStack(alignment: .leading) {
                                    Text("Walk on \(session.startTime.formatted())")
                                    Text("  - Steps: \(session.steps)")
                                    Text("  - Distance: \(session.distance, specifier: "%.2f") miles")
                                }
                                .padding(.bottom, 5)
                            }
                        }
                        
                        
                        
                        // Button to Reset Journey
                        Button("Reset Journey") {
                            print("[Reset Journey] Button pressed for \(currentJourney.destination)")
                            resetJourney(for: currentJourney)
                        }
                    }
                } else {
                    Text("No active journey for \(selectedDestination).")
                    Button("Start Journey for \(selectedDestination)") {
                        print("[Start Journey] Button pressed for \(selectedDestination)")
                            startJourney(for: selectedDestination)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            HealthKitManager.shared.requestAuthorization { success, _ in
                if success {
                    print("[onAppear] HealthKit authorization successful.")
                }
            }
            lastStepCount = loadLastStepCount()
            print("[onAppear] Loaded lastStepCount: \(lastStepCount)")
        }
    }
    
    private func getCurrentJourney() -> Journey? {
        let journey = journeys.first(where: { $0.destination == selectedDestination })
        if let journey = journey {
            print("[getCurrentJourney] Found explicitly created journey for \(selectedDestination)")
        } else {
            print("[getCurrentJourney] No journey found for \(selectedDestination)")
        }
        return journey
    }
    
    private func checkForExistingJourney(for destination: String) {
        print("[checkForExistingJourney] Checking for existing journey for \(destination)")
        
        if let journey = getCurrentJourney() {
            journeyStarted = true
            journeyStartTime = journey.startDate
            progressPercentage = ProgressManager.shared.getCurrentProgress(journey: journey)
            journeyUpdate = RouteManager.shared.getJourneyUpdate(progress: progressPercentage)
            
            // Recalculate the route for the current destination
            route = nil
            if let destinationInfo = RouteManager.shared.destinationData[destination] {
                let destinationCoordinates = destinationInfo.coordinates
                RouteManager.shared.calculateWalkingRoute(from: userLocation, to: destination) { calculatedRoute in
                    if let newRoute = calculatedRoute {
                        self.route = newRoute
                        print("[checkForExistingJourney] Route updated for \(destination)")
                    } else {
                        print("[checkForExistingJourney] Failed to update route for \(destination)")
                    }
                }
            }
            
            print("[checkForExistingJourney] Loaded existing journey for \(destination)")
        } else {
            journeyStarted = false
            journeyUpdate = "" // Clear the update message if no journey is found
            route = nil // Clear the route when no journey exists
            print("[checkForExistingJourney] No existing journey for \(destination)")
        }
    }

    private func updateProgress(for journey: Journey) {
        HealthKitManager.shared.fetchStepsSinceStart(journey: journey) { steps in
            DispatchQueue.main.async {
                let currentSteps = Int(steps)
                
                // Prevent double-counting by checking against lastStepCount
                if currentSteps > lastStepCount {
                    let newSteps = currentSteps - lastStepCount
                    let newDistance = Double(newSteps) * 0.000473
                    
                    journey.totalSteps += newSteps
                    journey.distanceWalked += newDistance
                    
                    let walkSession = WalkSession(startTime: Date(), steps: newSteps, distance: newDistance)
                    journey.walkSessions.append(walkSession)
                    
                    try? modelContext.save()
                    
                    progressPercentage = ProgressManager.shared.getCurrentProgress(journey: journey)
                    journeyUpdate = RouteManager.shared.getJourneyUpdate(progress: progressPercentage)
                    
                    // Update and save the lastStepCount
                    lastStepCount = currentSteps
                    saveLastStepCount(lastStepCount)
                    
                    print("[updateProgress] Added \(newSteps) steps and \(String(format: "%.2f", newDistance)) miles.")
                } else {
                    print("[updateProgress] No new steps recorded.")
                }
            }
        }
    }
    
    private func resetJourney(for journey: Journey) {
        print("[resetJourney] Attempting to delete journey for \(journey.destination)")

        // Delete the journey from the model context
        modelContext.delete(journey)

        // Save the context after deletion
        do {
            try modelContext.save()
            journeyStarted = false
            journeyUpdate = ""
            journeyStartTime = nil
            lastStepCount = 0
            progressPercentage = 0.0
            print("[resetJourney] Successfully deleted journey for \(journey.destination)")
        } catch {
            print("[resetJourney] Failed to delete journey: \(error.localizedDescription)")
        }
    }
    
    private func startJourney(for destination: String) {
        print("[Start Journey] Button pressed for \(destination)")
        
        if let destinationInfo = RouteManager.shared.destinationData[selectedDestination] {
            let destinationCoordinates = destinationInfo.coordinates
            RouteManager.shared.calculateWalkingRoute(from: userLocation, to: selectedDestination) { calculatedRoute in
                if let route = calculatedRoute {
                    self.route = route
                }
            }
        }
        
        if getCurrentJourney() == nil {
            let startDate = Date()
            let startLocation = "Fresno"

            // Safely unwrap the destination data
            guard let destinationInfo = RouteManager.shared.destinationData[selectedDestination] else {
                print("[startJourney] No data found for \(destination)")
                return
            }
            
            let targetDistanceInMiles = destinationInfo.targetDistance
            let destinationCoordinates = destinationInfo.coordinates
            
            // Create a new Journey object
            let newJourney = Journey(
                startDate: startDate,
                startLocation: startLocation,
                destination: destination,
                targetDistance: targetDistanceInMiles
            )
            
            // Insert and save the new journey
            modelContext.insert(newJourney)
            try? modelContext.save()
            
            journeyStarted = true
            journeyStartTime = startDate
            checkForExistingJourney(for: destination)
            print("[startJourney] New journey explicitly started for \(destination)")
        } else {
            print("[startJourney] Journey already exists for \(destination), skipping creation.")
        }
    }
}
