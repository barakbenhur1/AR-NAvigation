//
//  RegularNavigationViewViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import MapKit

typealias ResetCamera = () -> ()

class RegularNavigationView: CleanView, MKMapViewDelegate {
    //MARK: - @IBOutlets
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            handeleMap()
        }
    }
    @IBOutlet weak var dirctionInfoLabel: UILabel!
    @IBOutlet weak var centerButton: UIButton!
    
    //MARK: - Veribales
    private var directions: MKDirections!
    private var routes: [MKRoute]?
    private var endPoint: CLLocation!
    private var imageName: String!
    private var currentStepIndex: Int!
    private var regionManager: RegionManager!
    private var lineWidth: CGFloat!
//    private var skipDistance: Bool!
    
    var trackUserLocation: MKUserTrackingMode = .followWithHeading {
        didSet {
            setTrackingUserLocation()
        }
    }
    
    private var moved = false {
        didSet {
            centerButton.isHidden = !moved
        }
    }
    
    private var resetMapCamera: ResetCamera?
    
    // MARK: - @IBActions
    @IBAction func recenter(_ sender: UIButton) {
        setTrackingUserLocation()
        resetMapCamera?()
    }
    
    // MARK: - Helpers
    private func handeleMap() {
        mapView.delegate = self
        lineWidth = 30
        setupCompass()
        initMapCamera()
    }
    
    private func setupCompass() {
        mapView.showsCompass = false
        let compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .visible
        compassButton.isUserInteractionEnabled = false
        mapView.addSubview(compassButton)
        compassButton.translatesAutoresizingMaskIntoConstraints = false
        compassButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -5).isActive = true
        compassButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 120).isActive = true
    }
    
    func unvalid() {
        dirctionInfoLabel.isHidden = true
        centerButton.alpha = 0
        trackUserLocation = .none
        mapView.setUserTrackingMode(.none, animated: false)
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 1200), animated: true)
        let mid = CLLocationCoordinate2D(latitude: (endPoint.coordinate.latitude + mapView.userLocation.coordinate.latitude) / 2, longitude: (endPoint.coordinate.longitude + mapView.userLocation.coordinate.longitude) / 2)
        setCamera(coordinate: mid, fromDistance: 1100, animated: false)
        lineWidth = 10
        addRoutes(routes: routes)
        setEndPoint(point: endPoint, image: "destinationVerySmall")
    }
    
    func initMapCamera() {
        setCamera(coordinate: mapView.userLocation.coordinate)
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 120), animated: true)
    }
    
    func setResetCamera(complition: @escaping ResetCamera) {
        resetMapCamera = complition
    }
    
    private func setCamera(coordinate: CLLocationCoordinate2D) {
        setCamera(coordinate: coordinate, fromDistance: 100)
    }
    
    private func setCamera(coordinate: CLLocationCoordinate2D, fromDistance: CGFloat, animated: Bool = true) {
        let mapCamera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: fromDistance, pitch: 40, heading: mapView.camera.heading)
        mapView.setCamera(mapCamera, animated: animated)
    }
    
    func setTrackingUserLocation() {
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 220), animated: true)
        mapView.setUserTrackingMode(trackUserLocation, animated: false)
    }
    
    func stopMonitoringAllRegions() {
        regionManager?.stopUpdatingLocation()
        regionManager?.stopMonitoringAllRegions()
    }
    
    func startMonitoringRegions() {
        regionManager?.startUpdatingLocation()
        regionManager?.startMonitoringRegions(with: routes)
        
        regionManager?.trackRegion { [weak self] index, count, state in
            guard let self else { return }
            switch state {
            case .enter:
                currentStepIndex = index
                updateInfoLabel(showDistance: index < count / 2)
            case .exit:
                currentStepIndex = index
                updateInfoLabel(showDistance: index < count / 2)
                break
            case .determine( _, let state):
                guard state == .inside else { return }
                guard index == 1 && count > 1 else { return }
                currentStepIndex = index
                updateInfoLabel(showDistance: true)
            }
        }
    }
    
    private func updateInfoLabel(showDistance: Bool) {
        guard let currentStepIndex else { return }
        guard currentStepIndex >= 0 else { return }
        guard currentStepIndex < (self.routes?.first?.steps.count ?? 0) else {
            if let last = self.routes?.first?.steps.last {
                dirctionInfoLabel.text = "\(last.instructions)"
            }
            return
        }
        guard let cs = self.routes?.first?.steps[currentStepIndex] else { return }
        guard cs == self.routes?.first?.steps.first && !cs.instructions.isEmpty || cs != self.routes?.first?.steps.first else {
            dirctionInfoLabel.text = NSLocalizedString("start here", comment: "")
            return
        }
        
        var text = cs.instructions
        
        if showDistance, let location = regionManager?.location {
            let coordinate = cs.polyline.coordinate
            let distance = "\(NSLocalizedString("in", comment: "")) \(Int(location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)))) \(NSLocalizedString("meters", comment: ""))"
            text = "\(distance) \(text)"
        }
        
        dirctionInfoLabel.text = text
    }
    
    // MARK: - public functions
    func addRoutes(routes: [MKRoute]?) {
        guard let routes else { return }
        if let oldRoute = self.routes {
            oldRoute.forEach { mapView.removeOverlay($0.polyline) }
        }
        
        currentStepIndex = 0
        dirctionInfoLabel.text = ""
        self.routes = routes
        routes.forEach { mapView.addOverlay($0.polyline, level: .aboveRoads) }
        updateInfoLabel(showDistance: true)
        stopMonitoringAllRegions()
        regionManager = RegionManager()
        startMonitoringRegions()
    }
    
    func setEndPoint(point: CLLocation?, image: String = "destinationSmall") {
        guard let point else { return }
        mapView.removeAnnotations(mapView.annotations)
        endPoint = point
        imageName = image
        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = endPoint.coordinate
        endAnnotation.title = "destination"
        mapView.addAnnotation(endAnnotation)
    }
    
    func goToStep(index: Int?) {
        guard let index = index, let coordinate = routes?.first?.steps[index].polyline.coordinate else { return }
        setCamera(coordinate: coordinate)
    }
    
    // MARK: - mapView
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .systemYellow.withAlphaComponent(0.6)
        renderer.lineWidth = lineWidth
        return renderer
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        let current = mapView.region.center
        guard let coord = mapView.userLocation.location?.coordinate else { return }
        let currlat = Double(round(20000 * current.latitude) / 20000)
        let userlat = Double(round(20000 * coord.latitude) / 20000)
        let currlong = Double(round(20000 * current.longitude) / 20000)
        let userlong = Double(round(20000 * coord.longitude) / 20000)
        moved = currlat != userlat || currlong != userlong
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard !moved else { return }
        setTrackingUserLocation()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation.title == "destination" else { return nil }
        let identifier = "identifier"
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView.image = UIImage(named: imageName)
        annotationView.canShowCallout = true
        annotationView.calloutOffset = CGPoint(x: -5, y: 5)
        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure) as UIView
        return annotationView
    }
}
