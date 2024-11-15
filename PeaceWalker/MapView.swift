import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var route: MKRoute?
    @Binding var userLocation: CLLocationCoordinate2D
    var progressPolyline: MKPolyline?

    private let mapView = MKMapView()

    // MARK: - Make UIView
    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        return mapView
    }

    // MARK: - Update UIView
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        // Add route overlay if available
        if let route = route {
            let polyline = route.polyline
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, animated: true)
        }
    }

    // MARK: - Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        // MARK: - Render Overlay
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
