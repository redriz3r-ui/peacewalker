import SwiftUI
import Charts

struct ProgressView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @State private var animateProgress = false
    @State private var selectedEntry: ActivityEntry?
    @State private var animateSteps = false
    @State private var animateDistance = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic gradient background
                LinearGradient(
                    gradient: Gradient(colors: viewModel.gradientColors()),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                
                ScrollView {
                    VStack(spacing: 20) {
                        userGreetingView
                        metricsView
                        stepProgressCardView
                        distanceProgressCardView
                        activityHistoryView
                    }
                }
                .background(Color.black)
                .sheet(item: $selectedEntry) { entry in
                    ActivityDetailView(entry: entry)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        animateProgress = true
                    }
                    HealthKitManager.shared.fetchTodayDataWithRetry()
                }
                .navigationTitle("Progress")
                .onChange(of: viewModel.stepCount) { oldValue, newValue in
                    if oldValue != newValue {
                        withAnimation(.easeInOut(duration: 0.1)) { // Blur on
                            animateSteps = false
                            print("Steps blur triggered: \(animateSteps)")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { // Scale up
                                animateSteps = true
                                print("Steps blur off, scale up: \(animateSteps)")
                            }
                        }
                    }
                }
                .onChange(of: viewModel.distance) { oldValue, newValue in
                    if oldValue != newValue {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            animateDistance = false
                            print("Distance blur triggered: \(animateDistance)")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                animateDistance = true
                                print("Distance blur reset: \(animateDistance)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var userGreetingView: some View {
        HStack {
            NavigationLink(destination: SettingsProfileView(viewModel: viewModel)) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
                    .opacity(0.7) // Optional: subtle tap effect
                VStack {
                    Text("Hello,")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Robe")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0.0, to: animateProgress ? min(Double(viewModel.stepCount) / Double(viewModel.stepGoal), 1.0) : 0.0)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 60, height: 60)
                
                Text("\(Int(Double(viewModel.stepCount) / Double(viewModel.stepGoal) * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading) {
                Text("Steps: \(viewModel.stepCount)")
                    .font(.headline)
                    .blur(radius: animateSteps ? 0 : 3)
                    .scaleEffect(animateSteps ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateSteps)
                Text("Goal: \(Int(viewModel.stepGoal))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
    
    private var stepProgressCardView: some View {
        NavigationLink(destination: StepProgressDetailView(viewModel: viewModel)) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Steps")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("\(viewModel.stepCount) steps")
                        .font(.title2)
                        .foregroundColor(.white)
                        .blur(radius: animateSteps ? 0 : 3)
                        .scaleEffect(animateSteps ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateSteps)
                }
                Spacer()
                HStack {
                    Chart {
                        ForEach(viewModel.getStepsChartData()) { data in
                            BarMark(
                                x: .value("Time", data.label),
                                y: .value("Steps", data.steps)
                            )
                            .foregroundStyle(.gray)
                        }
                    }
                    .frame(width: 100, height: 40)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    private var distanceProgressCardView: some View {
        NavigationLink(destination: DistanceProgressDetailView(viewModel: viewModel)) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Walking Distance")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text(String(format: "%.2f mi", viewModel.distance))
                        .font(.title2)
                        .foregroundColor(.white)
                        .blur(radius: animateDistance ? 0 : 3)
                        .scaleEffect(animateDistance ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateDistance)
                }
                Spacer()
                HStack {
                    Chart {
                        ForEach(viewModel.getDistanceChartData()) { data in
                            BarMark(
                                x: .value("Time", data.label),
                                y: .value("Distance", data.distance ?? 0.0)
                            )
                            .foregroundStyle(.gray)
                        }
                    }
                    .frame(width: 100, height: 40)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    
    private var activityHistoryView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Activity History")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.vertical) {
                LazyVStack(spacing: -30) {
                    ForEach(viewModel.activityHistory) { entry in
                        ActivityCard(entry: entry)
                            .frame(height: 100)
                            .shadow(radius: 3)
                            .zIndex(entry.date == viewModel.activityHistory.first?.date ? 1 : 0)
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                }
                .padding(.vertical, 30)
            }
            .frame(height: 150)
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var metricsView: some View {
        HStack(spacing: 10) {
            MetricCard(
                title: "Distance",
                value: String(format: "%.2f mi", viewModel.distance),
                icon: "map",
                shouldAnimate: animateDistance
            )
            MetricCard(
                title: "Calories",
                value: "\(viewModel.calories)",
                icon: "flame",
                shouldAnimate: animateSteps // Animate with steps since calories are derived from steps
            )
            MetricCard(
                title: "Steps",
                value: "\(viewModel.stepCount)",
                icon: "figure.walk",
                shouldAnimate: animateSteps
            )
        }
        .padding(.horizontal)
    }
}

// Update MetricCard to support animation
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var shouldAnimate: Bool = false // Add animation flag

    var body: some View {
        VStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .blur(radius: shouldAnimate ? 0 : 3) // Blur to clear
                .scaleEffect(shouldAnimate ? 1.1 : 1.0) // Slight pop
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shouldAnimate)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }
}

// Reusable view for displaying an insight with an icon and text
struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(text)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}

struct StepProgressDetailView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @State private var chartData: [ChartData] = []
    @State private var selectedSteps: (label: String, steps: Int)? // For tap feedback

    var body: some View {
        VStack(spacing: 20) {
            timePeriodPicker
            totalStepsView
            selectedStepsView
            stepsChartView
            insightsCardView
            Spacer()
        }
        .background(Color.black)
        .navigationTitle("Step Progress")
        .onChange(of: viewModel.selectedTimePeriod) { _, newPeriod in
            withAnimation(.easeInOut(duration: 0.5)) {
                chartData = viewModel.getStepsChartData()
            }
            selectedSteps = nil // Reset selection on tab switch
        }
        .onAppear {
            chartData = viewModel.getStepsChartData()
        }
    }
    
    private var timePeriodPicker: some View {
        Picker("Time Period", selection: $viewModel.selectedTimePeriod.animation()) {
            Text("D").tag(TimePeriod.daily)
            Text("W").tag(TimePeriod.weekly)
            Text("M").tag(TimePeriod.monthly)
            Text("Y").tag(TimePeriod.yearly)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var totalStepsView: some View {
        Text("\(viewModel.selectedTimePeriod.title(for: "Steps")): \(viewModel.stepInsights.totalSteps)")
            .font(.title2)
            .foregroundColor(.white)
    }
    
    private var selectedStepsView: some View {
        Group {
            if let selected = selectedSteps {
                Text("\(selected.label): \(selected.steps) steps")
                    .font(.headline)
                    .foregroundColor(.white)
                    .transition(.opacity)
            }
        }
    }
    
    private var stepsChartView: some View {
         Chart {
             ForEach(chartData) { data in
                 BarMark(
                     x: .value("Time", data.label),
                     y: .value("Steps", data.steps)
                 )
                 .foregroundStyle(.blue)
                 .annotation(position: .top, alignment: .center) {
                     if selectedSteps?.label == data.label {
                         Text("\(data.steps) steps")
                             .font(.caption)
                             .foregroundColor(.red) // Match goal line style
                             .padding(2)
                             .background(Color.black.opacity(0.7)) // Slight background for contrast
                             .cornerRadius(4)
                     }
                 }
             }
             if viewModel.selectedTimePeriod != .daily {
                 RuleMark(y: .value("Goal", viewModel.stepGoal))
                     .foregroundStyle(.red)
                     .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                     .annotation(position: .top, alignment: .leading) {
                         Text("Goal: \(Int(viewModel.stepGoal))")
                             .font(.caption)
                             .foregroundColor(.red)
                     }
             }
         }
         .frame(height: 200)
         .padding()
         .chartYAxis {
             AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel() }
         }
         .chartXAxis {
             if viewModel.selectedTimePeriod == .daily {
                 AxisMarks(position: .bottom, values: chartData.enumerated().compactMap { index, data in
                     index % 4 == 0 ? data.label : nil
                 }) { AxisValueLabel().font(.caption).offset(y: 10) }
             } else {
                 AxisMarks(position: .bottom) { AxisValueLabel().font(.caption).offset(y: 10) }
             }
         }
         .chartXScale(domain: .automatic(includesZero: false))
         .chartOverlay { proxy in
             GeometryReader { geo in
                 Rectangle().fill(.clear).contentShape(Rectangle())
                     .gesture(
                         SpatialTapGesture()
                             .onEnded { value in
                                 let tapX = value.location.x
                                 let plotFrame = geo[proxy.plotAreaFrame]
                                 let relativeX = tapX - plotFrame.minX
                                 
                                 // Map each label to its X-position
                                 let positions = chartData.map { datum in
                                     proxy.position(forX: datum.label) ?? 0
                                 }
                                 
                                 // Find nearest bar
                                 let nearest = positions.enumerated().min(by: { abs($0.element - relativeX) < abs($1.element - relativeX) })
                                 guard let (index, _) = nearest, index < chartData.count else { return }
                                 
                                 let tappedData = chartData[index]
                                 print("Tapped nearest: label=\(tappedData.label), steps=\(tappedData.steps), tapX=\(relativeX)")
                                 
                                 withAnimation(.easeInOut(duration: 0.2)) {
                                     selectedSteps = (label: tappedData.label, steps: tappedData.steps)
                                 }
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                     withAnimation(.easeInOut(duration: 0.2)) {
                                         selectedSteps = nil
                                     }
                                 }
                             }
                     )
             }
         }
     }
    
    private var insightsCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            InsightRow(
                icon: "chart.bar",
                iconColor: .gray,
                text: "Average Steps: \(String(format: "%.0f", viewModel.stepInsights.averageSteps))"
            )
            
            InsightRow(
                icon: "target",
                iconColor: .gray,
                text: "Goal Progress: \(String(format: "%.0f", viewModel.stepInsights.goalProgress))%"
            )
            
            if let trend = viewModel.stepInsights.trendInsight {
                InsightRow(
                    icon: trend.isPositive ? "arrow.up.right" : "arrow.down.right",
                    iconColor: trend.isPositive ? .green : .red,
                    text: trend.message
                )
            }
            
            if let streak = viewModel.stepInsights.goalAchievementStreak {
                InsightRow(
                    icon: "flame",
                    iconColor: .orange,
                    text: streak
                )
            }
            
            if let motivationalMessage = viewModel.stepInsights.motivationalMessage {
                InsightRow(
                    icon: "star",
                    iconColor: .yellow,
                    text: motivationalMessage
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct DistanceProgressDetailView: View {
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Time Period Picker
            Picker("Time Period", selection: $viewModel.selectedTimePeriod) {
                Text("D").tag(TimePeriod.daily)
                Text("W").tag(TimePeriod.weekly)
                Text("M").tag(TimePeriod.monthly)
                Text("Y").tag(TimePeriod.yearly)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Total Distance
            Text("\(viewModel.selectedTimePeriod.title(for: "Distance")): \(String(format: "%.2f mi", viewModel.distanceInsights.totalDistance))")
                .font(.title2)
                .foregroundColor(.white)
            
            // Chart
            Chart {
                ForEach(viewModel.getDistanceChartData()) { data in
                    BarMark(
                        x: .value("Time", data.label),
                        y: .value("Distance", data.distance ?? 0.0)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 200)
            .padding()
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                if viewModel.selectedTimePeriod == .daily {
                    AxisMarks(position: .bottom, values: viewModel.getDistanceChartData().enumerated().compactMap { index, data in
                        return index % 4 == 0 ? data.label : nil
                    }) { value in
                        AxisValueLabel()
                            .font(.caption)
                            .offset(y: 10)
                    }
                } else {
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel()
                            .font(.caption)
                            .offset(y: 10)
                    }
                }
            }
            .chartXScale(domain: .automatic(includesZero: false))
            
            // Insights Card
            VStack(alignment: .leading, spacing: 10) {
                InsightRow(
                    icon: "chart.bar",
                    iconColor: .gray,
                    text: "Average Distance: \(String(format: "%.2f mi", viewModel.distanceInsights.averageDistance))"
                )
                
                InsightRow(
                    icon: "target",
                    iconColor: .gray,
                    text: "Goal Progress: \(String(format: "%.0f", viewModel.distanceInsights.goalProgress))%"
                )
                
                if let trend = viewModel.distanceInsights.trendInsight {
                    InsightRow(
                        icon: trend.isPositive ? "arrow.up.right" : "arrow.down.right",
                        iconColor: trend.isPositive ? .green : .red,
                        text: trend.message
                    )
                }
                
                // Reusing StepInsights for streak and motivational message (based on step goal)
                if let streak = viewModel.stepInsights.goalAchievementStreak {
                    InsightRow(
                        icon: "flame",
                        iconColor: .orange,
                        text: streak
                    )
                }
                
                if let motivationalMessage = viewModel.stepInsights.motivationalMessage {
                    InsightRow(
                        icon: "star",
                        iconColor: .yellow,
                        text: motivationalMessage
                    )
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.black)
        .navigationTitle("Distance Progress")
    }
}

struct SettingsProfileView: View {
    @ObservedObject var viewModel: ProgressViewModel // Pass the same view model

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings & Profile")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding(.top)
            
            // Reuse setGoalView directly
            setGoalView
            
            Spacer()
        }
        .background(Color.black)
        .navigationTitle("Settings")
    }
    
    private var setGoalView: some View {
        VStack {
            Text("Set Daily Goals")
                .font(.headline)
                .foregroundColor(.white)
            // Step Goal
            Text("Step Goal: \(Int(viewModel.stepGoal)) steps")
                .foregroundColor(.white)
            Slider(value: $viewModel.stepGoal, in: 0...20000, step: 1000)
                .accentColor(.blue)
            // Distance Goal
            Text("Distance Goal: \(String(format: "%.1f", viewModel.distanceGoal)) miles")
                .foregroundColor(.white)
            Slider(value: $viewModel.distanceGoal, in: 0...20, step: 0.5)
                .accentColor(.blue)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ActivityDetailView: View {
    let entry: ActivityEntry
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formattedDate(entry.date))
                .font(.title)
                .foregroundColor(.white)
            Text("Steps: \(entry.steps)")
                .font(.headline)
                .foregroundColor(.white)
            if let distance = entry.distance {
                Text("Distance: \(String(format: "%.2f mi", distance))")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            if let duration = entry.duration {
                Text("Duration: \(formattedDuration(duration))")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            Button("Dismiss") {
                // Sheet will dismiss automatically when selectedEntry is set to nil
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(Color.black)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return hours > 0 ? "\(hours)h \(remainingMinutes)m" : "\(minutes)m"
    }
}

struct ActivityCard: View {
    let entry: ActivityEntry
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 25) {
                Text(formattedDate(entry.date))
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Steps: \(entry.steps)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if let distance = entry.distance {
                    Text("Distance: \(String(format: "%.2f mi", distance))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if let duration = entry.duration {
                    Text("Duration: \(formattedDuration(duration))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return hours > 0 ? "\(hours)h \(remainingMinutes)m" : "\(minutes)m"
    }
}
