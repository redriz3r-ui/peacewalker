import Foundation
import SwiftData

@Model
class Journey {
    var startDate: Date
    var startLocation: String
    var destination: String
    var targetDistance: Double
    var distanceWalked: Double
    var stepCount: Int
    var totalSteps: Int
    var walkSessions: [WalkSession]
    // Add this line

    init(startDate: Date, startLocation: String, destination: String, targetDistance: Double) {
        self.startDate = startDate
        self.startLocation = startLocation
        self.destination = destination
        self.targetDistance = targetDistance
        self.distanceWalked = 0.0
        self.stepCount = 0
        self.totalSteps = 0
        self.walkSessions = [] // Initialize the walkSessions list
    }
}

@Model
class WalkSession {
    var startTime: Date
    var steps: Int
    var distance: Double

    init(startTime: Date, steps: Int, distance: Double) {
        self.startTime = startTime
        self.steps = steps
        self.distance = distance
    }
}
