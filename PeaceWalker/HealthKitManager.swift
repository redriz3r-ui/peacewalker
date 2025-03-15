//
//  HealthKitManager.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//

import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    @Published var stepCount: Int = 0
    @Published var distance: Double = 0.0 // in miles

    private init() {
        requestAuthorization()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Authorization failed: \(error)")
                }
            }, receiveValue: { success in
                if success {
                    self.startObservingSteps()
                    self.startObservingDistance()
                    self.fetchTodayDataWithRetry()
                }
            })
            .store(in: &AnyCancellableStorage.shared.cancellables)
    }

    func requestAuthorization() -> Future<Bool, Error> {
        Future { promise in
            guard HKHealthStore.isHealthDataAvailable() else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"])))
                return
            }
            
            let typesToRead: Set = [
                HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            ]
            
            self.healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(success))
                }
            }
        }
    }

    public func fetchTodayDataWithRetry(attempt: Int = 0) {
        fetchLatestSteps { steps in
            print("Fetched steps (attempt \(attempt + 1)): \(steps)")
            if steps == 0 && attempt < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.fetchTodayDataWithRetry(attempt: attempt + 1)
                }
            }
        }
        fetchLatestDistance { distance in
            print("Fetched distance (attempt \(attempt + 1)): \(distance)")
            if distance == 0 && attempt < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.fetchTodayDataWithRetry(attempt: attempt + 1)
                }
            }
        }
    }

    func startObservingSteps() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            if error == nil {
                print("Step count observer triggered")
                self?.fetchLatestSteps()
            } else {
                print("Step count observer error: \(String(describing: error))")
            }
        }
        healthStore.execute(query)
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if !success {
                print("Background delivery for steps failed: \(String(describing: error))")
            }
        }
    }

    func startObservingDistance() {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let query = HKObserverQuery(sampleType: distanceType, predicate: nil) { [weak self] _, _, error in
            if error == nil {
                print("Distance observer triggered")
                self?.fetchLatestDistance()
            } else {
                print("Distance observer error: \(String(describing: error))")
            }
        }
        healthStore.execute(query)
        
        healthStore.enableBackgroundDelivery(for: distanceType, frequency: .immediate) { success, error in
            if !success {
                print("Background delivery for distance failed: \(String(describing: error))")
            }
        }
    }

    private func fetchLatestSteps(completion: ((Int) -> Void)? = nil) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            DispatchQueue.main.async {
                self?.stepCount = steps
                completion?(steps)
            }
        }
        healthStore.execute(query)
    }

    private func fetchLatestDistance(completion: ((Double) -> Void)? = nil) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            let distance = (result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0) * 0.000621371 // Convert meters to miles
            DispatchQueue.main.async {
                self?.distance = distance
                completion?(distance)
            }
        }
        healthStore.execute(query)
    }

    func fetchHistory(completion: @escaping ([ActivityEntry]) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let startDate = Calendar.current.date(byAdding: .month, value: -12, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        var dailyEntries: [Date: ActivityEntry] = [:]
        
        let stepQuery = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        stepQuery.initialResultsHandler = { [weak self] query, results, error in
            guard let results = results else {
                completion([])
                return
            }
            
            let distanceQuery = HKStatisticsCollectionQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            distanceQuery.initialResultsHandler = { query, distanceResults, error in
                guard let distanceResults = distanceResults else {
                    completion([])
                    return
                }
                
                results.enumerateStatistics(from: startDate, to: Date()) { stepStat, _ in
                    let date = stepStat.startDate
                    let steps = Int(stepStat.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                    let distanceStat = distanceResults.statistics(for: date)
                    let distance = (distanceStat?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0) * 0.000621371 // Convert to miles
                    
                    dailyEntries[date] = ActivityEntry(
                        date: date,
                        steps: steps,
                        distance: distance,
                        duration: nil
                    )
                }
                
                let sortedEntries = dailyEntries.values.sorted { $0.date > $1.date }
                DispatchQueue.main.async {
                    completion(sortedEntries)
                }
            }
            
            self?.healthStore.execute(distanceQuery)
        }
        
        healthStore.execute(stepQuery)
    }
}

class AnyCancellableStorage {
    static let shared = AnyCancellableStorage()
    var cancellables = Set<AnyCancellable>()
}
