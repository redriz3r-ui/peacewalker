import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    private init() {}

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        healthStore.requestAuthorization(toShare: [], read: [stepType], completion: completion)
    }

    func fetchStepsSinceStart(journey: Journey, completion: @escaping (Double) -> Void) {
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
            guard let samples = results as? [HKQuantitySample], error == nil else {
                completion(0)
                return
            }

            let totalSteps = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.count()) }
            completion(totalSteps)
        }

        healthStore.execute(query)
    }

    func fetchHistoricalSteps(completion: @escaping (Int?, Error?) -> Void) {
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
            guard let samples = results as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }

            let totalSteps = samples.reduce(0) { $0 + Int($1.quantity.doubleValue(for: HKUnit.count())) }
            completion(totalSteps, nil)
        }

        healthStore.execute(query)
    }

    func startRealTimeTracking(completion: @escaping (Int) -> Void) {
        // Implement real-time step tracking logic
        // Call completion with the updated step count
    }
} 
