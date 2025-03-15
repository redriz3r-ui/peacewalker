import Foundation
import SwiftData
import CoreLocation

@Model
class WalkSession {
    @Attribute var id: UUID = UUID()
    @Attribute var date: Date = Date()
    @Attribute var steps: Int = 0
    @Attribute var distance: Double = 0.0
    @Attribute var routeData: Data = Data() // Persisted as Data
    
    var route: [CLLocationCoordinate2D] { // Computed, not persisted
        get {
            guard !routeData.isEmpty else { return [] }
            do {
                let coordinates = try JSONDecoder().decode([CodableCoordinate].self, from: routeData)
                return coordinates.map { $0.coordinate }
            } catch {
                print("Failed to decode route: \(error)")
                return []
            }
        }
        set {
            do {
                let codableRoute = newValue.map { CodableCoordinate($0) }
                routeData = try JSONEncoder().encode(codableRoute)
            } catch {
                print("Failed to encode route: \(error)")
                routeData = Data()
            }
        }
    }
    
    required init() {}
}

struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
