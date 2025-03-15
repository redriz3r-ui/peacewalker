////
////  PinManager.swift
////  MapWalker
////
////  Created by Robe on 2/22/25.
////
//
//
//import CoreLocation
//import Combine
//
//class PinManager: ObservableObject {
//    static let shared = PinManager()
//    @Published var pins: [Pin] = []
//
//    func generatePins(around center: CLLocationCoordinate2D, count: Int, radius: Double) {
//        pins = (0..<count).map { _ in
//            let randomCoordinate = generateRandomCoordinate(around: center, radius: radius)
//            return Pin(coordinate: randomCoordinate, name: "Pin \(index + 1)")
//        }
//    }
//
//    private func generateRandomCoordinate(around center: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
//        let earthRadius: Double = 6_371_000 // meters
//        let angularRadius = radius / earthRadius
//        let randomAngle = Double.random(in: 0...(2 * .pi))
//        let randomDistance = Double.random(in: 0...angularRadius)
//        let lat1 = center.latitude * .pi / 180
//        let lon1 = center.longitude * .pi / 180
//        let lat2 = asin(sin(lat1) * cos(randomDistance) + cos(lat1) * sin(randomDistance) * cos(randomAngle))
//        let lon2 = lon1 + atan2(sin(randomAngle) * sin(randomDistance) * cos(lat1), cos(randomDistance) - sin(lat1) * sin(lat2))
//        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
//    }
//}
