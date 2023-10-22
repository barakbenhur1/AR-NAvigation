//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import CoreLocation
import MapKit
import SwiftyGif

class NavigationViewController: UIViewController {
    @IBOutlet weak var arrivaTimelView: UIStackView!
    @IBOutlet weak var arrivalTime: UILabel!
    @IBOutlet weak var walkingAnimation: UIImageView!
    
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var distance: UILabel!
    
    private var locationManager: CLLocationManager!
    
    private var timer: Timer!
    
    var destinationName: String?
    var transportType: MKDirectionsTransportType = .walking
    var location: CLLocation?
    var to: CLLocation?
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override func viewDidLoad() {
        initUI()
        handeleLoctionManager()
        setDestination()
        setupNavigtionInfoTimer()
        setupObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
        removeObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.timer?.invalidate()
            self?.timer = nil
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.setupNavigtionInfoTimer()
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    private func initUI() {
        walkingAnimation.setGifImage(try! UIImage(gifName: transportType == .walking ? "walking" : "car"))
        place.text = self.destinationName
    }
    
    private func setupNavigtionInfoTimer() {
        timer = Timer(timeInterval: 1.667, repeats: true, block: { [weak self] timer in
            self?.claculateNavigtionInfo()
        })
        
        timer.fire()
        
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func handeleLoctionManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setDestination() {
        NotificationCenter.default.post(name: .init("setDestination"), object: to)
    }
    
    private func setUI(directions: MKDirections, routes: [MKRoute]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let route = routes.first else { return }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let distance = "\(formatter.string(from: NSNumber(value: Int(route.distance)))!)m"
            let attr = NSMutableAttributedString(string: distance)
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: self.distance.font.pointSize), range: NSRange(location: distance.count - 1, length: 1))
            attr.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: distance.count - 1, length: 1))
            self.distance.attributedText = attr
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.walkingAnimation.alpha = 1
                self?.distance.alpha = 1
            }
            directions.calculateETA { [weak self] response, error in
                guard let timeInterval = response?.expectedTravelTime else { return }
                let tmv = timeval(tv_sec: Int(timeInterval), tv_usec: 0)
                let time = Duration(tmv).formatted(.time(pattern: .hourMinute))
                self?.arrivalTime.text = "Arrival Time: \(time)"
                
                UIView.animate(withDuration: 0.3) { [weak self] in
                    self?.arrivaTimelView.alpha = 1
                }
            }
        }
    }
    
    private func claculateNavigtionInfo() {
        guard let destinationLocation = to?.coordinate else { return }
        
        let destinationPlacemark = MKPlacemark(coordinate: destinationLocation)
        
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        // Create a request for directions for walking
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destinationItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        // Get directions using MKDirections
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] (response, error) in
            if let error = error {
                let popup = UIAlertController(title: "unable to navigate", message: error.localizedDescription, preferredStyle: .alert)
                let ok = UIAlertAction(title: "ok", style: .default)
                popup.addAction(ok)
                self?.show(popup, sender: nil)
            } else {
                if let routes = response?.routes {
                    NotificationCenter.default.post(name: .init("updateRoute"), object: routes)
                    self?.setUI(directions: directions, routes: routes)
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
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
}
