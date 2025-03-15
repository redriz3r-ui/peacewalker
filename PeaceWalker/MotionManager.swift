//
//  MotionManager.swift
//  MapWalker
//
//  Created by Robe on 3/5/25.
//


// MotionManager.swift
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var activityLevel: Double = 0.5 // 0.0 to 1.0
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let data = data else { return }
            
            // Calculate magnitude of acceleration
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            // Map acceleration to activity level (0.0 to 1.0)
            let newActivityLevel = min(max((acceleration - 1.0) / 2.0, 0.0), 1.0)
            
            // Smooth out rapid changes
            self?.activityLevel = (self?.activityLevel ?? 0.5) * 0.9 + newActivityLevel * 0.1
        }
    }
}