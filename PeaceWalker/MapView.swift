import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var route: MKRoute?
    var progressPercentage: Double
var showFullRoute = false // State to toggle between views
  var followProgress = false
    
    let mapView = MKMapView()
    
    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false // Disable user location tracking

        // Set initial region to the starting point of the route (if available)
        if let route = route {
            let startCoordinate = route.polyline.points()[0].coordinate
            let initialRegion = MKCoordinateRegion(
                center: startCoordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            mapView.setRegion(initialRegion, animated: false)
        }

        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        guard let route = route else { return }
        
        // Create and add the progress polyline based on progressPercentage
        let progressPolyline = updateProgressPolyline(for: route, progressPercentage: progressPercentage)
        mapView.addOverlay(progressPolyline)
        
        // Toggle between full route view and follow progress view
        if showFullRoute {
            displayFullRoute(mapView: mapView, route: progressPolyline)
        } else if followProgress {
            centerMapOnProgressWithHeading(mapView: mapView, route: route, progressPercentage: progressPercentage)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKPolyline {
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = .green
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
    
    // MARK: - Full Route View (Simplified)
    func displayFullRoute(mapView: MKMapView, route: MKPolyline) {
        // Ensure the polyline has points
        guard route.pointCount > 0 else {
            print("[displayFullRoute] Polyline is empty.")
            return
        }

        // Get the bounding map rect of the current polyline (either full route or progress)
        let boundingMapRect = route.boundingMapRect

        // Define edge padding for a better fit (adjust as needed)
        let edgePadding = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)

        // Set the visible map rect with edge padding
        mapView.setVisibleMapRect(boundingMapRect, edgePadding: edgePadding, animated: true)

        // Optionally set a skewed camera for a dynamic view
        let centerCoordinate = route.coordinate
        let camera = MKMapCamera(
            lookingAtCenter: centerCoordinate,
            fromDistance: 3000, // Adjust the distance for zoom level
            pitch: 45,          // Add pitch for skewed view
            heading: 0          // Keep the heading north
        )
        mapView.setCamera(camera, animated: true)

        print("[displayFullRoute] Displaying full view of the current polyline.")
    }
    
    // MARK: - Follow Progress with Dynamic Heading
    func centerMapOnProgressWithHeading(mapView: MKMapView, route: MKRoute, progressPercentage: Double) {
        let totalDistance = route.distance
        let completedDistance = totalDistance * progressPercentage
        
        var accumulatedDistance: CLLocationDistance = 0
        let points = route.polyline.points()
        let pointCount = route.polyline.pointCount

        for i in 0..<pointCount {
            let coordinate = points[i].coordinate
            
            if i > 0 {
                let previousCoordinate = points[i - 1].coordinate
                let segmentDistance = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                
                accumulatedDistance += segmentDistance
                
                if accumulatedDistance >= completedDistance {
                    // Calculate the dynamic heading based on the direction of the route segment
                    let heading = calculateHeading(from: previousCoordinate, to: coordinate)
                    
                    // Set the camera at the current progress point with dynamic heading
                    let camera = MKMapCamera(
                        lookingAtCenter: coordinate,
                        fromDistance: 2500, // Adjust for zoom level
                        pitch: 45,          // Tilt for skewed view
                        heading: heading    // Use calculated heading
                    )
                    mapView.setCamera(camera, animated: true)
                    return
                }
            }
        }
    }
    
    // MARK: - Create Progress Polyline
    func updateProgressPolyline(for route: MKRoute, progressPercentage: Double) -> MKPolyline {
        let totalDistance = route.distance
        let completedDistance = totalDistance * progressPercentage
        
        var accumulatedDistance: CLLocationDistance = 0
        var progressCoordinates: [CLLocationCoordinate2D] = []
        
        let points = route.polyline.points()
        let pointCount = route.polyline.pointCount
        
        for i in 0..<pointCount {
            let coordinate = points[i].coordinate
            
            if i > 0 {
                let previousCoordinate = points[i - 1].coordinate
                let segmentDistance = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                
                accumulatedDistance += segmentDistance
                
                if accumulatedDistance >= completedDistance {
                    break
                }
            }
            
            progressCoordinates.append(coordinate)
        }
        
        return MKPolyline(coordinates: progressCoordinates, count: progressCoordinates.count)
    }
}

// MARK: - Calculate Heading
func calculateHeading(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
    let deltaLongitude = end.longitude - start.longitude
    let y = sin(deltaLongitude) * cos(end.latitude)
    let x = cos(start.latitude) * sin(end.latitude) - sin(start.latitude) * cos(end.latitude) * cos(deltaLongitude)
    let heading = atan2(y, x).toDegrees()
    return (heading < 0) ? heading + 360 : heading
}

// Extension to convert radians to degrees
extension Double {
    func toDegrees() -> Double {
        return self * 180 / .pi
    }
}
