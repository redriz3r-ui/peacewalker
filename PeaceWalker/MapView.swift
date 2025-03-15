import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @StateObject private var viewModel: MapViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: MapViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region, showsUserLocation: true)
                .gesture(DragGesture().onChanged { _ in viewModel.shouldFollowUser = false })
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    viewModel.isTracking && !viewModel.currentRoute.isEmpty ?
                        PolylineOverlay(coordinates: viewModel.currentRoute) : nil
                )
            
            VStack {
                metricsView
                    .padding(.horizontal)
                Spacer()
                HStack {
                    Text("Steps: \(viewModel.steps)")
                    Spacer()
                    Text("Distance: \(String(format: "%.2f", viewModel.distance)) mi")
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                HStack(spacing: 10) {
                    Button(action: { viewModel.isTracking ? viewModel.stopTracking() : viewModel.startTracking() }) {
                        Text(viewModel.isTracking ? "Stop" : "Start")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isTracking ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button(action: { viewModel.recenter() }) {
                        Image(systemName: "location.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .tabItem { Label("Map", systemImage: "map") }
    }
    
    private var metricsView: some View {
        HStack(spacing: 10) {
            MetricCard(title: "Distance", value: String(format: "%.2f mi", viewModel.distance), icon: "map")
            MetricCard(title: "Calories", value: "\(viewModel.calories)", icon: "flame")
            MetricCard(title: "Steps", value: "\(viewModel.steps)", icon: "figure.walk")
        }
    }
}

struct PolylineOverlay: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
