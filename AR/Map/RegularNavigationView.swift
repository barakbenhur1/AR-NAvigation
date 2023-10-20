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
    @IBOutlet weak var centerButton: UIButton!
    
    //MARK: - Veribales
    private var directions: MKDirections!
    private var routes: [MKRoute]?
    
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
        mapView.isZoomEnabled = false
        mapView.setCameraZoomRange(MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 150), animated: true)
        let mapCamera = MKMapCamera(lookingAtCenter: mapView.userLocation.coordinate, fromDistance: 30, pitch: 30, heading: mapView.camera.heading)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    private func setTrackingUserLocation() {
        mapView.setUserTrackingMode(trackUserLocation, animated: false)
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
    
    // MARK: - mapView
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .purple.withAlphaComponent(0.6)
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
    }
}
