import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var stepQuery: HKAnchoredObjectQuery?

    private init() {}

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

        healthStore.requestAuthorization(toShare: [], read: [stepType, distanceType]) { success, error in
            if success {
                print("[HealthKitManager] Authorization successful")
            } else if let error = error {
                print("[HealthKitManager] Authorization failed: \(error.localizedDescription)")
            } else {
                print("[HealthKitManager] Authorization failed for an unknown reason.")
            }
            completion(success, error)
        }
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

    // MARK: - Added Methods

    func startObservingSteps(updateHandler: @escaping (Int) -> Void) {
        print("[HealthKitManager] Starting to observe steps...")

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        // Use HKObserverQuery to observe changes
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("[HealthKitManager] Error observing steps: \(error.localizedDescription)")
                updateHandler(0)
                return
            }

            // Fetch the latest step data
            self?.fetchLatestSteps { steps in
                updateHandler(steps)
            }
        }

        healthStore.execute(query)
    }

    private func fetchLatestSteps(completion: @escaping (Int) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now) // No need for `guard let` since it's non-optional

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("[HealthKitManager] Error fetching step data: \(error?.localizedDescription ?? "Unknown error")")
                completion(0)
                return
            }

            let stepCount = Int(sum.doubleValue(for: HKUnit.count()))
            print("[HealthKitManager] Latest Steps: \(stepCount)")
            completion(stepCount)
        }

        healthStore.execute(query)
    }
}
