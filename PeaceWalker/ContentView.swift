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
    @State private var selectedDestination: String = "Clovis"
    @State private var journeyStarted: Bool = false
    @State private var journeyStartTime: Date?
    @State private var isWalkSessionsVisible: Bool = false
    @Query var journeys: [Journey]
    @State private var route: MKRoute?
    @State private var userLocation = CLLocationCoordinate2D(latitude: 36.7378, longitude: -119.7871)
    @State private var showFullRoute = false
    @State private var followProgress = true
    
    @Environment(\.modelContext) private var modelContext
    
    let destinations = ["Kearney Park", "Clovis", "Visalia"]
    
    var body: some View {
        VStack(spacing: 10) {
            if journeyStarted, let currentJourney = getCurrentJourney() {
                journeyView(currentJourney: currentJourney)
            } else {
                Button("Start Journey for \(selectedDestination)") {
                    startJourney(for: selectedDestination)
                }
                .padding()
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
                }
            }
            lastStepCount = loadLastStepCount()
        }
    }
    
    // MARK: - Helper Views
    
    private func journeyView(currentJourney: Journey) -> some View {
        VStack {
            progressView(currentJourney: currentJourney)
            
            ZStack {
                MapView(route: $route, progressPercentage: progressPercentage, showFullRoute: showFullRoute, followProgress: followProgress)
                    .frame(height: 300)
                    .cornerRadius(10)
                
                controlButtons()
            }
            
            Button("Show/Hide Walk Sessions") {
                isWalkSessionsVisible.toggle()
            }
            .padding()

            if isWalkSessionsVisible {
                walkSessionsView(currentJourney: currentJourney)
            }

            Button("Reset Journey") {
                resetJourney(for: currentJourney)
            }
            .padding()
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
        HStack(spacing: 10) {
            Button(action: {
                showFullRoute = true
                followProgress = false
            }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .shadow(radius: 5)

            Button(action: {
                followProgress = true
                showFullRoute = false
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .shadow(radius: 5)
        }
        .padding([.top, .leading], 20)
    }

    private func walkSessionsView(currentJourney: Journey) -> some View {
        VStack {
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
        // Using the zero-parameter closure
        .onChange(of: selectedDestination) {
            print("[onChange] Tab switched to \(selectedDestination)")
            checkForExistingJourney(for: selectedDestination)
        }
    }

    // MARK: - Helper Functions
    
    private func getCurrentJourney() -> Journey? {
        return journeys.first(where: { $0.destination == selectedDestination })
    }

    private func resetJourney(for journey: Journey) {
        modelContext.delete(journey)
        try? modelContext.save()
        journeyStarted = false
        journeyUpdate = ""
        journeyStartTime = nil
        lastStepCount = 0
        progressPercentage = 0.0
    }

    private func startJourney(for destination: String) {
        if let destinationInfo = RouteManager.shared.destinationData[destination] {
            RouteManager.shared.calculateWalkingRoute(from: userLocation, to: destination) { route in
                self.route = route
            }
        }

        let newJourney = Journey(
            startDate: Date(),
            startLocation: "Fresno",
            destination: destination,
            targetDistance: RouteManager.shared.destinationData[destination]?.targetDistance ?? 10.0
        )

        modelContext.insert(newJourney)
        try? modelContext.save()
        journeyStarted = true
        checkForExistingJourney(for: destination)
    }

    private func checkForExistingJourney(for destination: String) {
        if let journey = getCurrentJourney() {
            journeyStarted = true
            journeyStartTime = journey.startDate
            progressPercentage = ProgressManager.shared.getCurrentProgress(journey: journey)
            route = nil
        } else {
            journeyStarted = false
            journeyUpdate = ""
            route = nil
        }
    }
}
