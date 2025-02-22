import Foundation
import SwiftData

@Model
class UserProfile: Identifiable {
    @Attribute var userId: String
    @Attribute var username: String
    @Attribute var steps: Int64
    @Attribute var milesWalked: Double
    @Attribute var pinsCollected: Int64
    @Attribute var streakDays: Int64
    @Attribute var profileImage: URL?

    init(userId: String = UUID().uuidString, username: String = "", steps: Int64 = 0, milesWalked: Double = 0.0, pinsCollected: Int64 = 0, streakDays: Int64 = 0, profileImage: URL? = nil) {
        self.userId = userId
        self.username = username
        self.steps = steps
        self.milesWalked = milesWalked
        self.pinsCollected = pinsCollected
        self.streakDays = streakDays
        self.profileImage = profileImage
    }
    
    
}

@Model
class Event: Identifiable {
    @Attribute var eventId: String
    @Attribute var eventName: String
    @Attribute var startTime: Date?
    @Attribute var endTime: Date?
    @Attribute var pinCount: Int64
    @Attribute var winnerUserId: String?

    init(eventId: String = UUID().uuidString, eventName: String = "", startTime: Date? = nil, endTime: Date? = nil, pinCount: Int64 = 0, winnerUserId: String? = nil) {
        self.eventId = eventId
        self.eventName = eventName
        self.startTime = startTime
        self.endTime = endTime
        self.pinCount = pinCount
        self.winnerUserId = winnerUserId
    }
}

@Model
class EventLeaderboard: Identifiable {
    @Attribute var eventId: String
    @Attribute var userId: String
    @Attribute var stepsTaken: Int64
    @Attribute var pinsCollected: Int64
    @Attribute var ranking: Int64

    init(eventId: String = "", userId: String = "", stepsTaken: Int64 = 0, pinsCollected: Int64 = 0, ranking: Int64 = 0) {
        self.eventId = eventId
        self.userId = userId
        self.stepsTaken = stepsTaken
        self.pinsCollected = pinsCollected
        self.ranking = ranking
    }
}

@Model
class Journey: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var startDate: Date?
    @Attribute var startLocation: String?
    @Attribute var targetDistance: Double = 0.0
    @Attribute var distanceWalked: Double = 0.0
    @Attribute var stepCount: Int = 0
    @Attribute var totalSteps: Int = 0
    @Relationship var walkSessions: [WalkSession]?
    @Attribute var startLatitude: Double = 0.0
    @Attribute var startLongitude: Double = 0.0
    @Attribute var pinIDs: [String] = []

    init(id: UUID = UUID(), startDate: Date? = nil, startLocation: String? = nil, targetDistance: Double = 0.0, distanceWalked: Double = 0.0, stepCount: Int = 0, totalSteps: Int = 0, walkSessions: [WalkSession]? = nil, startLatitude: Double = 0.0, startLongitude: Double = 0.0, pinIDs: [String] = []) {
        self.id = id
        self.startDate = startDate
        self.startLocation = startLocation
        self.targetDistance = targetDistance
        self.distanceWalked = distanceWalked
        self.stepCount = stepCount
        self.totalSteps = totalSteps
        self.walkSessions = walkSessions
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.pinIDs = pinIDs
    }


    // Add a pin to the journey
    func addPin(_ pin: Pin, modelContext: ModelContext) {
        let pinIdString = pin.id.uuidString
        if !pinIDs.contains(pinIdString) {
            pinIDs.append(pinIdString)
            print("[Journey] Added pin \(pinIdString) to journey.")
        }
    }

    // Remove a pin from the journey
    func removePin(_ pin: Pin, modelContext: ModelContext) {
        let pinIdString = pin.id.uuidString
        if let index = pinIDs.firstIndex(of: pinIdString) {
            pinIDs.remove(at: index)
            print("[Journey] Removed pin \(pinIdString) from journey.")
        }
    }
}

@Model
class WalkSession: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var startTime: Date?
    @Attribute var steps: Int = 0
    @Attribute var distance: Double = 0.0
    @Relationship var journey: Journey?

    init(id: UUID = UUID(), startTime: Date? = nil, steps: Int = 0, distance: Double = 0.0, journey: Journey? = nil) {
        self.id = id
        self.startTime = startTime
        self.steps = steps
        self.distance = distance
        self.journey = journey
    }

    // Associate with a journey and save the context
    func linkToJourney(_ journey: Journey, modelContext: ModelContext) {
        self.journey = journey
        saveContext(modelContext: modelContext)
    }

    private func saveContext(modelContext: ModelContext) {
        do {
            try modelContext.save()
            print("[WalkSession] Changes saved successfully.")
        } catch {
            print("[WalkSession] Error saving context: \(error)")
        }
    }
}



