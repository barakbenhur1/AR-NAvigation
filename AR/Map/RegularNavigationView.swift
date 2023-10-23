//
//  RegularNavigationViewViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import MapKit

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
    
    var resetMapCamera: (() -> ())?
    
    // MARK: - @IBActions
    @IBAction func recenter(_ sender: UIButton) {
        setTrackingUserLocation()
        resetMapCamera?()
    }
    
    // MARK: - Helpers
    private func handeleMap() {
        mapView.delegate = self
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
        compassButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 10).isActive = true
    }
    
    func initMapCamera() {
        setCamera(coordinate:  mapView.userLocation.coordinate)
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 150), animated: true)
    }
    
    private func setCamera(coordinate: CLLocationCoordinate2D) {
        let mapCamera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 30, pitch: 30, heading: mapView.camera.heading)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    func setTrackingUserLocation() {
        mapView.setUserTrackingMode(trackUserLocation, animated: false)
    }
    
    private func updateInfoLabel(location: CLLocation?) {
        guard let location = location else { return }
        guard let currentStep = self.routes?.first?.steps.min(by: { first, second in
            let fc = first.polyline.coordinate
            let sc = second.polyline.coordinate
            let firstLocation = CLLocation(latitude: fc.latitude, longitude: fc.longitude)
            let secondLocation = CLLocation(latitude: sc.latitude, longitude: sc.longitude)
            return firstLocation.distance(from: location) < secondLocation.distance(from: location)
        }) else { return }
        
        dirctionInfoLabel.text = (currentStep == self.routes?.first?.steps.first ? "" : "in \(Int(location.distance(from: CLLocation(latitude: currentStep.polyline.coordinate.latitude, longitude: currentStep.polyline.coordinate.longitude)))) meters ") + currentStep.instructions
    }
    
    // MARK: - public functions
    func addRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        if let oldRoute = self.routes {
            oldRoute.forEach { mapView.removeOverlay($0.polyline) }
        }
        self.routes = routes
        routes.forEach { mapView.addOverlay($0.polyline, level: .aboveRoads) }
    }
    
    func setEndPoint(point: CLLocation) {
        self.endPoint = point
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
        renderer.lineWidth = 30
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
        updateInfoLabel(location: userLocation.location)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation.title == "destination" else { return nil }
        let identifier = "identifier"
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView.image = UIImage(named: "destinationSmall")
        annotationView.canShowCallout = true
        annotationView.calloutOffset = CGPoint(x: -5, y: 5)
        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure) as UIView
        return annotationView
    }
}
