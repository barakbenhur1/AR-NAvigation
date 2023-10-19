//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import CoreLocation
import MapKit

class NavigationViewController: UIViewController {
    @IBOutlet weak var arrivalTime: UILabel!
    
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var distance: UILabel!
    
    private var locationmanager: CLLocationManager!
    
    private var timer: Timer!
    
    private var count: Int!
    private var maxCount: Int!
    
    var location: CLLocation?
    var to: CLLocation?
    
    override func viewDidLoad() {
        maxCount = 4
        count = maxCount
        
        timer = Timer(timeInterval: 10, repeats: true, block: { [weak self] timer in
            self?.count = 0
        })
        
        RunLoop.main.add(timer, forMode: .common)
        
        locationmanager = CLLocationManager()
        locationmanager.delegate = self
        locationmanager.startUpdatingLocation()
        locationmanager.startUpdatingHeading()
        
        setLocation(sourceLocation: location, to: to)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    private func setUI(directions: MKDirections, route: MKRoute) {
        DispatchQueue.main.async { [weak self] in
            self?.place.text = route.name
            self?.distance.text = "\(Int(route.distance))m"
            directions.calculateETA { [weak self] response, error in
                guard let timeInterval = response?.expectedTravelTime else { return }
                let tmv = timeval(tv_sec: Int(timeInterval), tv_usec: 0)
                let time = Duration(tmv).formatted(.time(pattern: .hourMinute))
                self?.arrivalTime.text = "Arrival Time: \(time)"
            }
        }
    }
    
    private func setLocation(sourceLocation: CLLocation?, to: CLLocation?) {
        guard let sourceLocation = sourceLocation?.coordinate, let destinationLocation = to?.coordinate else { return }
        
        guard count != nil && count <= maxCount else { return }
        count += 1
        
        // Create MKPlacemark objects for source and destination
        let sourcePlacemark = MKPlacemark(coordinate: sourceLocation)
        let destinationPlacemark = MKPlacemark(coordinate: destinationLocation)
        
        // Create MKMapItems for source and destination
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        // Create a request for directions for walking
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .walking
        
        // Get directions using MKDirections
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] (response, error) in
            if let error = error {
                let popup = UIAlertController(title: "unable to navigate", message: error.localizedDescription, preferredStyle: .alert)
                let ok = UIAlertAction(title: "ok", style: .default)
                popup.addAction(ok)
                self?.show(popup, sender: nil)
            } else {
                if let route = response?.routes.first {
                    NotificationCenter.default.post(name: .init("updateRoute"), object: route)
                    self?.setUI(directions: directions, route: route)
                }
            }
        }
    }
    
    @IBAction func didClickOnBack(_ sender: UIButton) {
        dismiss(animated: true)
    }
}

extension NavigationViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first?.coordinate else { return }
        NotificationCenter.default.post(name: .init("updateLocation"), object: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
}
