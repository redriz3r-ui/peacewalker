import Foundation
import SwiftData
import CoreLocation

@Model
class Journey: Identifiable {
    var startDate: Date
    var startLocation: String
    var destination: String
    var targetDistance: Double
    var distanceWalked: Double = 0.0
    var stepCount: Int = 0
    var totalSteps: Int = 0
    var walkSessions: [WalkSession] = []
    var startLatitude: Double? 
    var startLongitude: Double?

    init(startDate: Date, startLocation: String, destination: String, targetDistance: Double) {
        self.startDate = startDate
        self.startLocation = startLocation
        self.destination = destination
        self.targetDistance = targetDistance
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
