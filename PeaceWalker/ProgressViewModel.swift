import Combine
import Foundation
import HealthKit
import SwiftUI

struct ActivityEntry: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    let distance: Double? // in miles
    let duration: TimeInterval?
}

enum TimePeriod: String {
    case daily, weekly, monthly, yearly
    
    func title(for metric: String) -> String {
        switch self {
        case .daily: return "\(metric) Today"
        case .weekly: return "\(metric) This Week"
        case .monthly: return "\(metric) This Month"
        case .yearly: return "\(metric) Last 12 Months"
        }
    }
}

struct DistanceInsights {
    let totalDistance: Double
    let averageDistance: Double
    let goalProgress: Double
    let trendInsight: (message: String, isPositive: Bool)?
    
    static let empty = DistanceInsights(totalDistance: 0.0, averageDistance: 0.0, goalProgress: 0.0, trendInsight: nil)
}

struct StepInsights {
    let totalSteps: Int
    let averageSteps: Double
    let busiestDay: (dayLabel: String, steps: Int)?
    let goalProgress: Double
    let trendInsight: (message: String, isPositive: Bool)?
    let goalAchievementStreak: String?
    let motivationalMessage: String?
    
    static let empty = StepInsights(totalSteps: 0, averageSteps: 0, busiestDay: nil, goalProgress: 0, trendInsight: nil, goalAchievementStreak: nil, motivationalMessage: nil)
}

struct ChartData: Identifiable {
    let id = UUID()
    let label: String
    let steps: Int
    let date: Date
    let distance: Double?
}

class ProgressViewModel: ObservableObject {
    @Published var stepCount: Int = 0 {
        didSet { calories = Int(Double(stepCount) * 0.05) }
    }
    @Published var stepGoal: Double {
        didSet { UserDefaults.standard.set(stepGoal, forKey: "stepGoal") }
    }
    @Published var distanceGoal: Double {
        didSet { UserDefaults.standard.set(distanceGoal, forKey: "distanceGoal") }
    }
    @Published var activityHistory: [ActivityEntry] = []
    @Published var distance: Double = 0.0
    @Published var calories: Int = 0
    @Published var selectedTimePeriod: TimePeriod = .daily {
        didSet {
            stepInsights = computeStepInsights()
            distanceInsights = computeDistanceInsights()
        }
    }
    @Published var stepInsights: StepInsights = StepInsights.empty
    @Published var distanceInsights: DistanceInsights = DistanceInsights.empty
    @Published var moodValue: Double = 0.5
    private var cancellables = Set<AnyCancellable>()
    private let healthStore = HKHealthStore()
    private let motionManager = MotionManager()
    
    init() {
        self.stepGoal = UserDefaults.standard.double(forKey: "stepGoal") > 0 ? UserDefaults.standard.double(forKey: "stepGoal") : 10000
        self.distanceGoal = UserDefaults.standard.double(forKey: "distanceGoal") > 0 ? UserDefaults.standard.double(forKey: "distanceGoal") : 5.0
        
        HealthKitManager.shared.fetchHistory { [weak self] entries in
            self?.activityHistory = entries
            if let todayEntry = entries.first(where: { Calendar.current.isDateInToday($0.date) }) {
                self?.stepCount = todayEntry.steps
                self?.distance = todayEntry.distance ?? 0.0
            } else {
                self?.stepCount = HealthKitManager.shared.stepCount
                self?.distance = HealthKitManager.shared.distance
                self?.updateTodayEntry()
            }
            self?.stepInsights = self?.computeStepInsights() ?? StepInsights.empty
            self?.distanceInsights = self?.computeDistanceInsights() ?? DistanceInsights.empty
            self?.updateMoodValue(activityLevel: self?.motionManager.activityLevel ?? 0.5)
        }
        
        HealthKitManager.shared.$stepCount
            .sink { [weak self] newStepCount in
                self?.stepCount = newStepCount
                self?.updateTodayEntry(steps: newStepCount)
                self?.stepInsights = self?.computeStepInsights() ?? StepInsights.empty
                self?.updateMoodValue(activityLevel: self?.motionManager.activityLevel ?? 0.5)
            }
            .store(in: &cancellables)
        
        HealthKitManager.shared.$distance
            .sink { [weak self] newDistance in
                self?.distance = newDistance
                self?.updateTodayEntry(distance: newDistance)
                self?.stepInsights = self?.computeStepInsights() ?? StepInsights.empty
                self?.distanceInsights = self?.computeDistanceInsights() ?? DistanceInsights.empty
            }
            .store(in: &cancellables)
        
        motionManager.$activityLevel
            .sink { [weak self] activityLevel in
                self?.updateMoodValue(activityLevel: activityLevel)
            }
            .store(in: &cancellables)
    }
    
    func gradientColors() -> [Color] {
        switch moodValue {
        case 0..<0.3: return [Color.blue, Color.purple]
        case 0.3..<0.6: return [Color.green, Color.teal]
        case 0.6..<0.9: return [Color.yellow, Color.orange]
        default: return [Color.red, Color.pink]
        }
    }
    
    private func updateMoodValue(activityLevel: Double) {
        let stepMood = min(Double(stepCount) / stepGoal, 1.0)
        let combinedMood = (stepMood * 0.6 + activityLevel * 0.4)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.moodValue = combinedMood
            }
        }
    }
    
    private func updateTodayEntry(steps: Int? = nil, distance: Double? = nil) {
        let today = Date()
        if let todayIndex = activityHistory.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            let current = activityHistory[todayIndex]
            activityHistory[todayIndex] = ActivityEntry(date: today, steps: steps ?? current.steps, distance: distance ?? current.distance, duration: current.duration)
        } else {
            activityHistory.append(ActivityEntry(date: today, steps: steps ?? stepCount, distance: distance ?? self.distance, duration: nil))
        }
    }

    func getStepsForCurrentPeriod() -> Int {
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimePeriod {
        case .daily: return stepCount
        case .weekly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .day, value: -7, to: now)! }.reduce(0) { $0 + $1.steps }
        case .monthly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .month, value: -1, to: now)! }.reduce(0) { $0 + $1.steps }
        case .yearly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .month, value: -12, to: now)! }.reduce(0) { $0 + $1.steps }
        }
    }
    
    func getStepsChartData() -> [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimePeriod {
        case .daily:
            var hourlySteps: [ChartData] = []
            let startDate = calendar.date(byAdding: .hour, value: -24, to: now)!
            let endDate = now
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: DateComponents(hour: 1))
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            query.initialResultsHandler = { _, results, _ in
                guard let results = results else { dispatchGroup.leave(); return }
                results.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let hourStart = stat.startDate
                    let steps = Int(stat.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "ha"
                    hourlySteps.append(ChartData(label: formatter.string(from: hourStart), steps: steps, date: hourStart, distance: nil))
                }
                dispatchGroup.leave()
            }
            healthStore.execute(query)
            dispatchGroup.wait()
            return hourlySteps.sorted { $0.date < $1.date }
        case .weekly:
            return stride(from: 6, through: 0, by: -1).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                let steps = activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.steps }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return ChartData(label: formatter.string(from: date), steps: steps, date: date, distance: nil)
            }
        case .monthly:
            return stride(from: 4, through: 0, by: -1).map { weekOffset in
                let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now)!
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
                let steps = activityHistory.filter { $0.date >= weekStart && $0.date < calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)! }.reduce(0) { $0 + $1.steps }
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return ChartData(label: formatter.string(from: weekStart), steps: steps, date: weekStart, distance: nil)
            }
        case .yearly:
            return stride(from: 11, through: 0, by: -1).map { monthOffset in
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                let steps = activityHistory.filter { $0.date >= monthStart && $0.date < calendar.date(byAdding: .month, value: 1, to: monthStart)! }.reduce(0) { $0 + $1.steps }
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return ChartData(label: formatter.string(from: date), steps: steps, date: monthStart, distance: nil)
            }
        }
    }

    func getDistanceForCurrentPeriod() -> Double {
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimePeriod {
        case .daily: return distance
        case .weekly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .day, value: -7, to: now)! }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
        case .monthly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .month, value: -1, to: now)! }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
        case .yearly: return activityHistory.filter { $0.date >= calendar.date(byAdding: .month, value: -12, to: now)! }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
        }
    }

    func getDistanceChartData() -> [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimePeriod {
        case .daily:
            var hourlyDistance: [ChartData] = []
            let startDate = calendar.date(byAdding: .hour, value: -24, to: now)!
            let endDate = now
            let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsCollectionQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: DateComponents(hour: 1))
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            query.initialResultsHandler = { _, results, _ in
                guard let results = results else { dispatchGroup.leave(); return }
                results.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let hourStart = stat.startDate
                    let distance = (stat.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0) * 0.000621371
                    let formatter = DateFormatter()
                    formatter.dateFormat = "ha"
                    hourlyDistance.append(ChartData(label: formatter.string(from: hourStart), steps: 0, date: hourStart, distance: distance))
                }
                dispatchGroup.leave()
            }
            healthStore.execute(query)
            dispatchGroup.wait()
            return hourlyDistance.sorted { $0.date < $1.date }
        case .weekly:
            return stride(from: 6, through: 0, by: -1).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                let distanceForDay = activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return ChartData(label: formatter.string(from: date), steps: 0, date: date, distance: distanceForDay)
            }
        case .monthly:
            return stride(from: 4, through: 0, by: -1).map { weekOffset in
                let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now)!
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
                let distanceForWeek = activityHistory.filter { $0.date >= weekStart && $0.date < calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)! }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return ChartData(label: formatter.string(from: weekStart), steps: 0, date: weekStart, distance: distanceForWeek)
            }
        case .yearly:
            return stride(from: 11, through: 0, by: -1).map { monthOffset in
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                let distanceForMonth = activityHistory.filter { $0.date >= monthStart && $0.date < calendar.date(byAdding: .month, value: 1, to: monthStart)! }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return ChartData(label: formatter.string(from: date), steps: 0, date: monthStart, distance: distanceForMonth)
            }
        }
    }
    
    private func computeDistanceInsights() -> DistanceInsights {
        let totalDistance = getDistanceForCurrentPeriod()
        let chartData = getDistanceChartData()
        let averageDistance: Double = {
            guard !chartData.isEmpty else { return 0 }
            switch selectedTimePeriod {
            case .daily: return chartData.filter { ($0.distance ?? 0.0) > 0 }.count > 0 ? totalDistance / Double(chartData.filter { ($0.distance ?? 0.0) > 0 }.count) : 0
            case .weekly: return totalDistance / 7
            case .monthly: return totalDistance / Double(Calendar.current.dateComponents([.day], from: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, to: Date()).day ?? 30)
            case .yearly: return totalDistance / 12
            }
        }()
        let goalProgress: Double = {
            let dailyGoal = distanceGoal
            switch selectedTimePeriod {
            case .daily: return (totalDistance / dailyGoal) * 100
            case .weekly: return (totalDistance / 7 / dailyGoal) * 100
            case .monthly: return (totalDistance / Double(Calendar.current.dateComponents([.day], from: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, to: Date()).day ?? 30) / dailyGoal) * 100
            case .yearly: return (totalDistance / 12 / 30 / dailyGoal) * 100
            }
        }()
        let trendInsight: (message: String, isPositive: Bool)? = {
            let calendar = Calendar.current
            let now = Date()
            switch selectedTimePeriod {
            case .daily: return nil
            case .weekly:
                let currentWeekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                let previousWeekStart = calendar.date(byAdding: .day, value: -14, to: now)!
                let currentDistance = activityHistory.filter { $0.date >= currentWeekStart }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                let previousDistance = activityHistory.filter { $0.date >= previousWeekStart && $0.date < currentWeekStart }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                guard previousDistance > 0 else { return nil }
                let percentageChange = (currentDistance - previousDistance) / previousDistance * 100
                let isPositive = percentageChange > 0
                return ("\(isPositive ? "Up" : "Down") \(String(format: "%.0f", abs(percentageChange)))% from last week", isPositive)
            case .monthly:
                let currentMonthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                let previousMonthStart = calendar.date(byAdding: .month, value: -2, to: now)!
                let currentDistance = activityHistory.filter { $0.date >= currentMonthStart }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                let previousDistance = activityHistory.filter { $0.date >= previousMonthStart && $0.date < currentMonthStart }.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
                guard previousDistance > 0 else { return nil }
                let percentageChange = (currentDistance - previousDistance) / previousDistance * 100
                let isPositive = percentageChange > 0
                return ("\(isPositive ? "Up" : "Down") \(String(format: "%.0f", abs(percentageChange)))% from last month", isPositive)
            case .yearly: return nil
            }
        }()
        return DistanceInsights(totalDistance: totalDistance, averageDistance: averageDistance, goalProgress: goalProgress, trendInsight: trendInsight)
    }
    
    private func computeStepInsights() -> StepInsights {
        let totalSteps = getStepsForCurrentPeriod()
        let chartData = getStepsChartData()
        let averageSteps: Double = {
            guard !chartData.isEmpty else { return 0 }
            switch selectedTimePeriod {
            case .daily: return chartData.filter { $0.steps > 0 }.count > 0 ? Double(totalSteps) / Double(chartData.filter { $0.steps > 0 }.count) : 0
            case .weekly: return Double(totalSteps) / 7
            case .monthly: return Double(totalSteps) / Double(Calendar.current.dateComponents([.day], from: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, to: Date()).day ?? 30)
            case .yearly: return Double(totalSteps) / 12
            }
        }()
        let busiestDay: (dayLabel: String, steps: Int)? = {
            guard let maxEntry = chartData.max(by: { $0.steps < $1.steps }) else { return nil }
            switch selectedTimePeriod {
            case .daily: return ("Busiest Hour: \(maxEntry.label)", maxEntry.steps)
            case .weekly: return ("Busiest Day: \(maxEntry.label)", maxEntry.steps)
            case .monthly: return ("Busiest Day: \(maxEntry.label)", maxEntry.steps)
            case .yearly: return ("Busiest Month: \(maxEntry.label)", maxEntry.steps)
            }
        }()
        let goalProgress: Double = {
            let dailyGoal = stepGoal
            switch selectedTimePeriod {
            case .daily: return (Double(totalSteps) / dailyGoal) * 100
            case .weekly: return (Double(totalSteps) / 7 / dailyGoal) * 100
            case .monthly: return (Double(totalSteps) / Double(Calendar.current.dateComponents([.day], from: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, to: Date()).day ?? 30) / dailyGoal) * 100
            case .yearly: return (Double(totalSteps) / 12 / 30 / dailyGoal) * 100
            }
        }()
        let trendInsight: (message: String, isPositive: Bool)? = {
            let calendar = Calendar.current
            let now = Date()
            switch selectedTimePeriod {
            case .daily: return nil
            case .weekly:
                let currentWeekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                let previousWeekStart = calendar.date(byAdding: .day, value: -14, to: now)!
                let currentSteps = activityHistory.filter { $0.date >= currentWeekStart }.reduce(0) { $0 + $1.steps }
                let previousSteps = activityHistory.filter { $0.date >= previousWeekStart && $0.date < currentWeekStart }.reduce(0) { $0 + $1.steps }
                guard previousSteps > 0 else { return nil }
                let percentageChange = (Double(currentSteps - previousSteps) / Double(previousSteps)) * 100
                let isPositive = percentageChange > 0
                return ("\(isPositive ? "Up" : "Down") \(String(format: "%.0f", abs(percentageChange)))% from last week", isPositive)
            case .monthly:
                let currentMonthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                let previousMonthStart = calendar.date(byAdding: .month, value: -2, to: now)!
                let currentSteps = activityHistory.filter { $0.date >= currentMonthStart }.reduce(0) { $0 + $1.steps }
                let previousSteps = activityHistory.filter { $0.date >= previousMonthStart && $0.date < currentMonthStart }.reduce(0) { $0 + $1.steps }
                guard previousSteps > 0 else { return nil }
                let percentageChange = (Double(currentSteps - previousSteps) / Double(previousSteps)) * 100
                let isPositive = percentageChange > 0
                return ("\(isPositive ? "Up" : "Down") \(String(format: "%.0f", abs(percentageChange)))% from last month", isPositive)
            case .yearly: return nil
            }
        }()
        let goalAchievementStreak: String? = {
            let calendar = Calendar.current
            let now = Date()
            switch selectedTimePeriod {
            case .daily: return nil
            case .weekly:
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                let daysInWeek = calendar.dateComponents([.day], from: weekStart, to: now).day ?? 7
                var streak = 0
                for dayOffset in (0..<daysInWeek).reversed() {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    let stepsThatDay = activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.steps }
                    if stepsThatDay >= Int(stepGoal) { streak += 1 } else { break }
                }
                return streak > 0 ? "\(streak)-day streak of meeting your goal!" : nil
            case .monthly:
                let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 30
                var streak = 0
                for dayOffset in (0..<daysInMonth).reversed() {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    let stepsThatDay = activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.steps }
                    if stepsThatDay >= Int(stepGoal) { streak += 1 } else { break }
                }
                return streak > 0 ? "\(streak)-day streak of meeting your goal!" : nil
            case .yearly: return nil
            }
        }()
        let motivationalMessage: String? = {
            let calendar = Calendar.current
            let now = Date()
            switch selectedTimePeriod {
            case .daily: return totalSteps >= Int(stepGoal) ? "Great job! You’ve exceeded your daily goal!" : nil
            case .weekly:
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                let daysInWeek = calendar.dateComponents([.day], from: weekStart, to: now).day ?? 7
                let daysMeetingGoal = (0..<daysInWeek).filter { dayOffset in
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    return activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.steps } >= Int(stepGoal)
                }.count
                return daysMeetingGoal > 0 ? "You met your goal on \(daysMeetingGoal) day\(daysMeetingGoal == 1 ? "" : "s") this week!" : nil
            case .monthly:
                let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 30
                let daysMeetingGoal = (0..<daysInMonth).filter { dayOffset in
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                    return activityHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.steps } >= Int(stepGoal)
                }.count
                return daysMeetingGoal > 0 ? "You met your goal on \(daysMeetingGoal) day\(daysMeetingGoal == 1 ? "" : "s") this month!" : nil
            case .yearly: return nil
            }
        }()
        return StepInsights(totalSteps: totalSteps, averageSteps: averageSteps, busiestDay: busiestDay, goalProgress: goalProgress, trendInsight: trendInsight, goalAchievementStreak: goalAchievementStreak, motivationalMessage: motivationalMessage)
    }
}
