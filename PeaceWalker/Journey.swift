import Foundation
import SwiftData
import CoreLocation

@Model
class Journey: Identifiable {
    var startDate: Date
    var startLocation: String
    var targetDistance: Double
    var distanceWalked: Double = 0.0
    var stepCount: Int = 0
    var totalSteps: Int = 0
    var walkSessions: [WalkSession] = []
    var startLatitude: Double?
    var startLongitude: Double?
    var pinIDs: [UUID] = [] // IDs of pins associated with this journey

    init(startDate: Date, startLocation: String,  targetDistance: Double, startingPin: Pin? = nil) {
        self.startDate = startDate
        self.startLocation = startLocation
        self.targetDistance = targetDistance
        if let startingPin = startingPin {
            self.startLatitude = startingPin.coordinate.latitude
            self.startLongitude = startingPin.coordinate.longitude
            self.pinIDs.append(startingPin.id)
        }
    }

    func addPin(_ pin: Pin) {
        if !pinIDs.contains(pin.id) {
            pinIDs.append(pin.id)
            print("[Journey] Added pin \(pin.id) to journey.")
        }
    }

    func removePin(_ pin: Pin) {
        if let index = pinIDs.firstIndex(of: pin.id) {
            pinIDs.remove(at: index)
            print("[Journey] Removed pin \(pin.id) from journey.")
        }
    }
}


@Model
class WalkSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var steps: Int
    var distance: Double

    init(startTime: Date, steps: Int, distance: Double) {
        self.id = UUID()
        self.startTime = startTime
        self.steps = steps
        self.distance = distance
    }
}
