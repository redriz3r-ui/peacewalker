import SwiftUI
import Combine
import CoreLocation
import MapKit
import SwiftData
import HealthKit

class MapViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02) // Tighter zoom
    )
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var shouldFollowUser: Bool = true
    @Published var isTracking: Bool = false
    @Published var currentRoute: [CLLocationCoordinate2D] = []
    @Published var steps: Int = 0
    @Published var distance: Double = 0.0
    @Published var calories: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var lastLocation: CLLocation?
    private var lastUpdateTime: Date?
    var modelContext: ModelContext?
    
    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
        
        // Location updates (throttled)
        LocationManager.shared.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self else { return }
                let now = Date()
                // Throttle to every 1 second
                guard self.lastUpdateTime == nil || now.timeIntervalSince(self.lastUpdateTime!) >= 1 else { return }
                self.lastUpdateTime = now
                
                self.userLocation = location.coordinate
                self.updateRegion(with: location.coordinate)
                if self.isTracking {
                    self.updateRoute(with: location)
                }
            }
            .store(in: &cancellables)
        
        // HealthKit steps
        HealthKitManager.shared.$stepCount
            .sink { [weak self] newStepCount in
                guard let self = self, self.isTracking else { return }
                self.steps = newStepCount - (self.stepsBaseline ?? 0)
                self.calories = Int(Double(self.steps) * 0.05) // Same as ProgressViewModel
            }
            .store(in: &cancellables)
    }
    
    private var stepsBaseline: Int? // Store starting steps
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        shouldFollowUser = true
        currentRoute = []
        stepsBaseline = HealthKitManager.shared.stepCount // Capture baseline
        steps = 0
        distance = 0.0
        calories = 0
        lastLocation = LocationManager.shared.location
        HealthKitManager.shared.fetchTodayDataWithRetry() // Ensure fresh data
    }
    
    func stopTracking() {
        guard isTracking, let context = modelContext else { return }
        isTracking = false
        stepsBaseline = nil
        let session = WalkSession()
        session.steps = steps
        session.distance = distance
        session.route = currentRoute
        if let journey = try? context.fetch(FetchDescriptor<Journey>()).first {
            journey.walkSessions.append(session)
            journey.stepCount += steps
        } else {
            let newJourney = Journey()
            newJourney.stepCount = steps
            newJourney.walkSessions = [session]
            context.insert(newJourney)
        }
        try? context.save()
    }
    
    func recenter() {
        shouldFollowUser = true
        if let coordinate = userLocation {
            updateRegion(with: coordinate)
        }
    }
    
    private func updateRegion(with coordinate: CLLocationCoordinate2D) {
        guard shouldFollowUser else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }
    
    private func updateRoute(with location: CLLocation) {
        let coordinate = location.coordinate
        currentRoute.append(coordinate)
        if let last = lastLocation {
            let delta = location.distance(from: last) * 0.000621371
            distance += delta
        }
        lastLocation = location
    }
}
