import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var route: MKRoute?
    var progressPercentage: Double
    var showFullRoute = false
    var followProgress = false
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    var isFreeRoam: Bool = false
    @Binding var centerOnUser: Bool
    @State private var didCenterInitially = false
    
    let PinManager = NavigationManager.shared
    
    class PinAnnotation: NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var title: String?
        var subtitle: String?
        
        init(coordinate: CLLocationCoordinate2D, steps: Int) {
            self.coordinate = coordinate
            self.title = "\(steps) Steps"
            super.init()
        }
    }
    
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
            default:
                break
            }
        }
    }
    
    @ObservedObject var locationManager = LocationManager()
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = true
        
        // Add Tap Gesture Recognizer
        // let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        // mapView.addGestureRecognizer(tapGesture)
        
        // Center on user location initially
        locationManager.locationUpdateHandler = { [weak mapView] userLocation in
            guard let mapView = mapView, !didCenterInitially else { return }
            
            let camera = MKMapCamera(
                lookingAtCenter: userLocation,
                fromDistance: 3500,
                pitch: 60,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)
            didCenterInitially = true
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        
        if centerOnUser, let userLocation = locationManager.location {
            let camera = MKMapCamera(
                lookingAtCenter: userLocation,
                fromDistance: 2500,
                pitch: 60,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)
            centerOnUser = false
        }
        
        let existingAnnotations = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
        let newAnnotations = NavigationManager.shared.pins.map { pin -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = pin.coordinate
            annotation.title = "Pin"
            return annotation
        }
        
        // Find annotations to add
        let annotationsToAdd = newAnnotations.filter { newAnnotation in
            !existingAnnotations.contains { $0.coordinate.latitude == newAnnotation.coordinate.latitude &&
                $0.coordinate.longitude == newAnnotation.coordinate.longitude }
        }
        
        // Find annotations to remove
        let annotationsToRemove = existingAnnotations.filter { existingAnnotation in
            !newAnnotations.contains { $0.coordinate.latitude == existingAnnotation.coordinate.latitude &&
                $0.coordinate.longitude == existingAnnotation.coordinate.longitude }
        }
        
        // Update annotations on the map
        mapView.removeAnnotations(annotationsToRemove)
        mapView.addAnnotations(annotationsToAdd)
        
        // Center map on pins if needed
        centerMapOnPins(mapView)
    }
    
    func centerMapOnPins(_ mapView: MKMapView) {
        let coordinates = NavigationManager.shared.pins.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }
        
        var mapRect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            mapRect = mapRect.union(rect)
        }
        
        mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        let geocoder = CLGeocoder()
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routePolyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(overlay: routePolyline)
                renderer.strokeColor = routePolyline === parent.route?.polyline ? .blue : .green
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil } // Skip user location
            
            let identifier = "Pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.pinTintColor = .red // Customize the pin color
                
                // Add a callout accessory with distance info
                let calloutLabel = UILabel()
                
                if let userLocation = parent.locationManager.location {
                    let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    let pinCLLocation = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
                    let distance = userCLLocation.distance(from: pinCLLocation) // Distance in meters
                    
                    // Convert distance to miles
                    let distanceInMiles = distance / 1609.34
                    
                    // Format the distance for display
                    calloutLabel.text = String(format: "%.2f miles away", distanceInMiles)
                } else {
                    calloutLabel.text = "Calculating distance..."
                }
                
                calloutLabel.font = .systemFont(ofSize: 12)
                calloutLabel.textColor = .gray
                annotationView?.detailCalloutAccessoryView = calloutLabel
            }
            return annotationView
        }
        
        
        func displayFullRoute(mapView: MKMapView, route: MKRoute) {
            let boundingMapRect = route.polyline.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
            mapView.setVisibleMapRect(boundingMapRect, edgePadding: edgePadding, animated: true)
        }
        
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
        
        func calculateHeading(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
            let deltaLongitude = end.longitude - start.longitude
            let y = sin(deltaLongitude) * cos(end.latitude)
            let x = cos(start.latitude) * sin(end.latitude) - sin(start.latitude) * cos(end.latitude) * cos(deltaLongitude)
            let heading = atan2(Double(y), Double(x)).toDegrees
            return (heading < 0) ? heading + 360 : heading
        }
    }
}
