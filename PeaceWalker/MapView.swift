import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var route: MKRoute?
    var progressPercentage: Double
    var showFullRoute = false
    var followProgress = false
    
    // MARK: - LocationManager

    class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
        @Published var location: CLLocationCoordinate2D?
        private let manager = CLLocationManager()
        var locationUpdateHandler: ((CLLocationCoordinate2D) -> Void)?

        override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
        }

        func startUpdatingLocation() {
            manager.startUpdatingLocation()
        }

        func stopUpdatingLocation() {
            manager.stopUpdatingLocation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                self.location = location.coordinate
                locationUpdateHandler?(location.coordinate)
            }
        }

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                print("Location access denied.")
                // Handle location access denial
            default:
                break
            }
        }
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        guard let route = route else { return }

        // Add the full route overlay if needed
        if showFullRoute {
            mapView.addOverlay(route.polyline)
        }

        // Create and add the progress polyline based on progressPercentage
        if let progressPolyline = RouteManager.shared.createProgressPolyline(route: route, progressPercentage: progressPercentage) {
            mapView.addOverlay(progressPolyline)
        }

        // Adjust the map view
        if showFullRoute {
            displayFullRoute(mapView: mapView, route: route)
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
                  if let routePolyline = overlay as? MKPolyline {
                      let renderer = MKPolylineRenderer(overlay: routePolyline)
                      if routePolyline === parent.route?.polyline {
                          renderer.strokeColor = .blue
                          renderer.lineWidth = 4
                      } else {
                          renderer.strokeColor = .green
                          renderer.lineWidth = 4
                      }
                      return renderer
                  }
                  return MKOverlayRenderer()
              }
          }

    // MARK: - Full Route View
    func displayFullRoute(mapView: MKMapView, route: MKRoute) {
        let boundingMapRect = route.polyline.boundingMapRect
        let edgePadding = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
        mapView.setVisibleMapRect(boundingMapRect, edgePadding: edgePadding, animated: true)
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
                    let heading = calculateHeading(from: previousCoordinate, to: coordinate)
                    let camera = MKMapCamera(
                        lookingAtCenter: coordinate,
                        fromDistance: 2500,
                        pitch: 45,
                        heading: heading
                    )
                    mapView.setCamera(camera, animated: true)
                    return
                }
            }
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
}

// Extension to convert radians to degrees
extension Double {
    func toDegrees() -> Double {
        return self * 180 / .pi
    }
    
}


