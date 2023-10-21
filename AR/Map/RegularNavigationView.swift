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
    
    var trackUserLocation: MKUserTrackingMode = .follow {
        didSet {
            setTrackingUserLocation()
        }
    }
    
    private var moved = false
    
    // MARK: - @IBActions
    @IBAction func recenter(_ sender: UIButton) {
        setTrackingUserLocation()
    }
    
    // MARK: - Helpers
    private func handeleMap() {
        mapView.delegate = self
        mapView.showsCompass = false
        
        let compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .visible
        compassButton.isUserInteractionEnabled = false
        
        mapView.addSubview(compassButton)
        
        compassButton.translatesAutoresizingMaskIntoConstraints = false
        compassButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12).isActive = true
        compassButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 12).isActive = true
        let mapCamera = MKMapCamera(lookingAtCenter: mapView.userLocation.coordinate, fromDistance: 30, pitch: 30, heading: mapView.camera.heading)
        mapView.setCamera(mapCamera, animated: true)
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 150), animated: true)
    }
    
    private func setTrackingUserLocation() {
        mapView.setUserTrackingMode(trackUserLocation, animated: false)
    }
    
    private func updateInfoLabel(location: CLLocation?) {
        guard let location = location else { return }
        let currentStep = self.routes?.first?.steps.min(by: { first, second in
            let fc = first.polyline.coordinate
            let sc = second.polyline.coordinate
            let firstLocation = CLLocation(latitude: fc.latitude, longitude: fc.longitude)
            let secondLocation = CLLocation(latitude: sc.latitude, longitude: sc.longitude)
            return firstLocation.distance(from: location) < secondLocation.distance(from: location)
        })
        dirctionInfoLabel.text = currentStep?.instructions
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
    
    // MARK: - mapView
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .systemYellow.withAlphaComponent(0.6)
        renderer.lineWidth = 30
        return renderer
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard trackUserLocation != .none else { return }
        centerButton.isHidden = mapView.isUserLocationVisible
        moved = !centerButton.isHidden
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard trackUserLocation != .none && !moved else { return }
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
