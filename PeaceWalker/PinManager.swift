import Foundation
import CoreLocation
import SceneKit
import MapKit
import Combine
import SwiftUI

// MARK: - Shared Models
struct Pin: Codable, Identifiable {
    let id: UUID = UUID() // Unique identifier for each pin
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date = Date() // Time when the pin was created
    var steps: Int? // Dynamically calculated steps to the pin
    var distanceFromUser: Double? // Distance from the user in meters
    var stepsFromUser: Int? // Steps required to reach the pin
    
}

struct RoutePin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    var distanceFromStart: Double? // Distance from the start in miles
    var isVisited: Bool = false    // Tracks if the pin is visited
}


struct PinInfoView: View {
    let pin: Pin
    let userLocation: CLLocation

    @Binding var isJourneyActive: Bool
    @Binding var activeJourneyPin: Pin?

    var body: some View {
        VStack(spacing: 20) {
            Text("On \(getStreetName(for: pin.coordinate))")
                .font(.title)
                .padding()

            Text("Distance: \(calculateDistanceInMiles(to: pin.coordinate), specifier: "%.2f") miles")
                .font(.headline)

            Text("Steps: \(calculateSteps(to: pin.coordinate)) steps")
                .font(.headline)

            difficultyView()

            Button(action: {
                activateJourney()
            }) {
                Text("Activate Journey")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private func getStreetName(for coordinate: CLLocationCoordinate2D) -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        var streetName = "Unknown"

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first, let name = placemark.thoroughfare {
                streetName = name
            }
        }

        return streetName
    }

    private func calculateDistanceInMiles(to coordinate: CLLocationCoordinate2D) -> Double {
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return userLocation.distance(from: pinLocation) / 1609.34 // Convert meters to miles
    }

    private func calculateSteps(to coordinate: CLLocationCoordinate2D) -> Int {
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = userLocation.distance(from: pinLocation)
        return Int(distanceInMeters / 0.762) // Average step length in meters
    }
    

    private func difficultyView() -> some View {
        let difficulty = calculateDifficulty(to: pin.coordinate)

        return HStack {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: "flame.fill")
                    .foregroundColor(index <= difficulty ? .red : .gray)
            }
        }
        .font(.largeTitle)
    }

    private func calculateDifficulty(to coordinate: CLLocationCoordinate2D) -> Int {
        let distanceInMiles = calculateDistanceInMiles(to: coordinate)
        switch distanceInMiles {
        case ..<0.5: return 1
        case ..<1.0: return 2
        case ..<2.0: return 3
        case ..<3.0: return 4
        default: return 5
        }
    }

    private func activateJourney() {
        isJourneyActive = true
        activeJourneyPin = pin
    }
}

// MARK: - Pin Generation Modes
enum PinGenerationMode {
    case ringBased
}

// MARK: - NavigationManager
class NavigationManager: ObservableObject {
    static let shared = NavigationManager() // Singleton instance
    
    // Published properties
    @Published var pins: [Pin] = []
    @Published var routePins: [RoutePin] = []
    @Published var annotations: [MKPointAnnotation] = [] // Add annotations array
    @Published var progress: Double = 0.0 // Progress percentage (0.0 - 1.0)
    private var timer: Timer?
    private let averageStepLength: Double = 0.762 // Average step length in meters
    
    // MARK: - Pin Management
    func addPin(at coordinate: CLLocationCoordinate2D) {
        let pin = Pin(coordinate: coordinate)
        pins.append(pin)

        // Create a corresponding MKPointAnnotation and add it to annotations
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Dynamic Pin"
        annotations.append(annotation)

        print("[NavigationManager] Added pin at: \(coordinate.latitude), \(coordinate.longitude)")
    }
    func removeAllPins() {
         pins.removeAll()
         annotations.removeAll() // Clear annotations when pins are cleared
     }
    
    func removePin(at coordinate: CLLocationCoordinate2D) {
        if let index = pins.firstIndex(where: { $0.coordinate == coordinate }) {
            pins.remove(at: index)
            print("[NavigationManager] Removed pin at \(coordinate.latitude), \(coordinate.longitude)")
        }
    }
    
    func generatePins(for mode: PinGenerationMode, center: CLLocationCoordinate2D) {
        switch mode {
        case .ringBased:
            generatePins(around: center, count: 3, radius: 10000)
            generatePins(around: center, count: 5, radius: 5000)
            generatePins(around: center, count: 7, radius: 1000)
        }
    }
    func updatePinMetadata(userLocation: CLLocation) {
        for (index, pin) in pins.enumerated() {
            let pinLocation = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
            let distance = userLocation.distance(from: pinLocation) // Distance in meters
            let steps = Int(distance / averageStepLength) // Average step length in meters

            pins[index].distanceFromUser = distance
            pins[index].stepsFromUser = steps
        }
    }
    
    func generatePins(around center: CLLocationCoordinate2D, count: Int, radius: Double) {
        pins.removeAll()
        for _ in 0..<count {
            let randomCoordinate = generateRandomCoordinate(around: center, radius: radius)
            addPin(at: randomCoordinate)
        }
    }
    
    private func generateRandomCoordinate(around center: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        let earthRadius: Double = 6_371_000
        let angularRadius = radius / earthRadius
        let randomAngle = Double.random(in: 0...(2 * .pi))
        let randomDistance = Double.random(in: 0...angularRadius)
        let lat1 = center.latitude.radians
        let lon1 = center.longitude.radians
        
        let lat2 = asin(sin(lat1) * cos(randomDistance) +
                        cos(lat1) * sin(randomDistance) * cos(randomAngle))
        
        let lon2 = lon1 + atan2(sin(randomAngle) * sin(randomDistance) * cos(lat1),
                                cos(randomDistance) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2.degrees, longitude: lon2.degrees)
    }
    
    // MARK: - Proximity-Based Collection
    func checkProximityToPins(userLocation: CLLocation, stepsTaken: Int) {
        for (index, pin) in pins.enumerated() {
            let pinLocation = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
            let distance = userLocation.distance(from: pinLocation)
            
            if distance <= 50 { // Proximity threshold
                print("[NavigationManager] Collected pin at: \(pin.coordinate.latitude), \(pin.coordinate.longitude)")
                pins.remove(at: index)
                updateSteps(stepCount: stepsTaken) // Update progress based on steps
                break
            }
        }
    }
    
    // MARK: - Step and Progress Management
    func updateSteps(stepCount: Int) {
        guard let route = routePins.first else { return } // Assume at least one route exists
        let totalStepsForRoute = Int(routePins.reduce(0) { $0 + ($1.distanceFromStart ?? 0) * 1609.34 } / averageStepLength) // Convert miles to meters
        
        progress = min(Double(stepCount) / Double(totalStepsForRoute), 1.0)
        print("[NavigationManager] Updated progress: \(progress * 100)%")
    }
    
    func calculateProgressMilestones() -> [Double] {
        let milestoneCount = 4
        return (1...milestoneCount).map { progress * Double($0) / Double(milestoneCount) }
    }
    
    // MARK: - Route Management
    func calculateWalkingRoute(from startLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, interval: Double, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        let startPlacemark = MKPlacemark(coordinate: startLocation)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("[NavigationManager] Error calculating route: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let route = response?.routes.first {
                print("[NavigationManager] Route successfully calculated.")
                self.routePins = self.generateRoutePins(for: route, interval: interval)
                completion(.success(route))
            } else {
                let error = NSError(domain: "NavigationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No routes found."])
                completion(.failure(error))
            }
        }
    }
    
    private func generateRoutePins(for route: MKRoute, interval: Double) -> [RoutePin] {
        var accumulatedDistance: Double = 0
        var generatedPins: [RoutePin] = []
        
        let points = route.polyline.points()
        let pointCount = route.polyline.pointCount
        
        for i in 0..<pointCount {
            if i > 0 {
                let previousCoordinate = points[i - 1].coordinate
                let currentCoordinate = points[i].coordinate
                let segmentDistance = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
                    .distance(from: CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)) / 1609.34 // Convert meters to miles
                
                accumulatedDistance += segmentDistance
                
                if accumulatedDistance >= interval {
                    let newPin = RoutePin(
                        name: "Pin \(generatedPins.count + 1)",
                        coordinate: currentCoordinate,
                        distanceFromStart: accumulatedDistance
                    )
                    generatedPins.append(newPin)
                    accumulatedDistance = 0
                }
            }
        }
        
        return generatedPins
    }
    
    // MARK: - Pin Query Helpers
       func getPin(by id: UUID) -> Pin? {
           return pins.first(where: { $0.id == id })
       }

       func getPinsWithinRadius(center: CLLocationCoordinate2D, radius: Double) -> [Pin] {
           return pins.filter {
               let location = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
               let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
               return location.distance(from: centerLocation) <= radius
           }
       }
    
    // MARK: - Daily Pin Refresh
    func startDailyPinRefresh(center: CLLocationCoordinate2D) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            print("[NavigationManager] Regenerating pins for the day...")
            self.generatePins(for: .ringBased, center: center)
        }
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
    var toDegrees: Double { self * 180 / .pi }
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}

extension NavigationManager {
    /// Creates a progress polyline representing the user's progress along a route.
    /// - Parameters:
    ///   - route: The `MKRoute` object representing the current walking route.
    ///   - progressPercentage: The user's progress along the route as a percentage (0.0 to 1.0).
    /// - Returns: An optional `MKPolyline` representing the progress on the route, or `nil` if no progress is made.
    func createProgressPolyline(route: MKRoute, progressPercentage: Double) -> MKPolyline? {
        guard progressPercentage > 0, progressPercentage <= 1 else {
            print("[NavigationManager] Invalid progress percentage.")
            return nil
        }

        let totalDistance = route.distance
        let completedDistance = totalDistance * progressPercentage

        var accumulatedDistance: CLLocationDistance = 0
        var progressCoordinates: [CLLocationCoordinate2D] = []

        let points = route.polyline.points()
        let pointCount = route.polyline.pointCount

        for i in 0..<pointCount {
            let coordinate = points[i].coordinate

            if i > 0 {
                let previousCoordinate = points[i - 1].coordinate
                let segmentDistance = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

                accumulatedDistance += segmentDistance

                if accumulatedDistance <= completedDistance {
                    progressCoordinates.append(coordinate)
                } else {
                    break
                }
            } else {
                progressCoordinates.append(coordinate) // Add the starting point
            }
        }

        guard !progressCoordinates.isEmpty else {
            print("[NavigationManager] No progress coordinates generated.")
            return nil
        }

        return MKPolyline(coordinates: progressCoordinates, count: progressCoordinates.count)
    }
}
