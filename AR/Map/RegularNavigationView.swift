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
            mapView.delegate = self
        }
    }
    @IBOutlet weak var centerButton: UIButton!
    
    //MARK: - Veribales
    private var circleCenter: MKCircle?
    private var location: CLLocationCoordinate2D?
    private var directions: MKDirections!
    private var route: MKRoute?
    
    private var moved = false
    
    // MARK: - @IBActions
    @IBAction func recenter(_ sender: UIButton) {
        center()
    }
    
    // MARK: - Helpers
    func center() {
        guard let location = location else { return }
        
        let mapCamera = MKMapCamera(lookingAtCenter: location, fromDistance: 200, pitch: 30, heading: -90)
        mapView.setCamera(mapCamera, animated: true)
        centerButton.isHidden = true
        moved = false
    }
    
    func navigate(location: CLLocationCoordinate2D?) {
        guard let location = location else { return }
        let region = MKCoordinateRegion( center: location, latitudinalMeters: CLLocationDistance(exactly: 100)!, longitudinalMeters: CLLocationDistance(exactly: 100)!)
        mapView.setRegion(mapView.regionThatFits(region), animated: true)
        
        center()
    }
    
    func setLocation(location: CLLocationCoordinate2D?) {
        if let circleCenter = circleCenter {
            mapView.removeOverlay(circleCenter)
        }
        
        guard let location = location else { return }
        self.location = location
        circleCenter = MKCircle(center:  location, radius: 2)
        mapView.addOverlay(circleCenter!)
        
        guard !moved else {  return }
        let mapCamera = MKMapCamera(lookingAtCenter: location, fromDistance: 200, pitch: 30, heading: -90)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    func addRoute(route: MKRoute?) {
        guard let route = route else { return }
        if let oldRoute = self.route {
            mapView.removeOverlay(oldRoute.polyline)
        }
        self.route = route
        mapView.addOverlay(route.polyline, level: .aboveRoads)
    }
    
    // MARK: - mapView
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.strokeColor = .white.withAlphaComponent(0.8)
            circleRenderer.fillColor = .systemGreen.withAlphaComponent(0.8)
            circleRenderer.lineWidth = 6
            return circleRenderer
        }
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.blue.withAlphaComponent(0.6)
        renderer.lineWidth = 20
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let circleCenter = circleCenter {
            mapView.removeOverlay(circleCenter)
        }
        
        circleCenter = MKCircle(center:  userLocation.coordinate, radius: 2)
        mapView.addOverlay(circleCenter!)
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard let location = location else {
            centerButton.isHidden = true
            return
        }
        
        let current = mapView.region.center
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        
        let coord = location
        
        let currlat = Double(round(10000 * current.latitude) / 10000)
        let userlat = Double(round(10000 * coord.latitude) / 10000)
        let currlong = Double(round(10000 * current.longitude) / 10000)
        let userlong = Double(round(10000 * coord.longitude) / 10000)
        centerButton.isHidden = currlat == userlat && currlong == userlong
        
        moved = !centerButton.isHidden
    }
}
