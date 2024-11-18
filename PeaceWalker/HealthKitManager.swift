import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var stepQuery: HKAnchoredObjectQuery?

    private init() {}

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        healthStore.requestAuthorization(toShare: [], read: [stepType, distanceType], completion: completion)
    }

    // Updated method signature to include startDate
    func startRealTimeTracking(from startDate: Date, completion: @escaping (Int) -> Void) {
        // Stop any existing query
        stopRealTimeTracking()

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        var anchor: HKQueryAnchor?

        let query = HKAnchoredObjectQuery(type: stepType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { query, samplesOrNil, deletedObjects, newAnchor, error in
            guard let samples = samplesOrNil as? [HKQuantitySample], error == nil else {
                completion(0)
                return
            }

            let newSteps = samples.reduce(0) { $0 + Int($1.quantity.doubleValue(for: HKUnit.count())) }
            completion(newSteps)
            anchor = newAnchor
        }

        query.updateHandler = { query, samplesOrNil, deletedObjects, newAnchor, error in
            guard let samples = samplesOrNil as? [HKQuantitySample], error == nil else {
                completion(0)
                return
            }

            let newSteps = samples.reduce(0) { $0 + Int($1.quantity.doubleValue(for: HKUnit.count())) }
            completion(newSteps)
            anchor = newAnchor
        }

        healthStore.execute(query)
        self.stepQuery = query
    }

    func stopRealTimeTracking() {
        if let query = stepQuery {
            healthStore.stop(query)
            stepQuery = nil
        }
    }

    func fetchDistanceSinceStart(journey: Journey, completion: @escaping (Double) -> Void) {
        let startDate = journey.startDate
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

        let query = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
            guard let samples = results as? [HKQuantitySample], error == nil else {
                print("[HealthKitManager] Error fetching distance: \(error?.localizedDescription ?? "Unknown error")")
                completion(0)
                return
            }

            let totalDistance = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.mile()) }
            print("[HealthKitManager] Fetched Distance: \(totalDistance) Miles")
            completion(totalDistance)
        }

        healthStore.execute(query)
    }
}
