//
//  RegularNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class RegularNavigationViewController: UIViewController, TabBarViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var regularView: RegularNavigationView! {
        didSet {
            regularView.trackUserLocation = .followWithHeading
        }
    }
    
    private var routes: [MKRoute]!
    private var endPoint: CLLocation!
    
    var step: Int?
    var resetMapCamera: (() -> ())?
    
    //MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        initRegular()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        regularView?.startMonitoringRegions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        regularView?.stopMonitoringAllRegions()
    }
    
    //MARK: - Helpers
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.regularView?.stopMonitoringAllRegions()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.regularView?.startMonitoringRegions()
        }
    }
    
    private func initRegular() {
        regularView?.setEndPoint(point: endPoint)
        regularView?.addRoutes(routes: routes)
        regularView?.goToStep(index: step)
        
        regularView?.resetMapCamera = { [weak self] in
            self?.resetMapCamera?()
        }
    }
    
    func unvalid() {
        regularView?.unvalid()
    }
    
    func valid() {
        regularView?.valid()
    }
    
    func setRoutes(routes: [MKRoute]) {
        self.routes = routes
        regularView?.addRoutes(routes: routes)
    }
    
    func setDestination(endPoint: CLLocation) {
        self.endPoint = endPoint
        regularView?.setEndPoint(point: endPoint)
    }
    
    func goToStep(index: Int) {
        step = index
        regularView?.goToStep(index: index)
    }
    
    func reCenter() {
        step = nil
        regularView?.initMapCamera()
        regularView?.setTrackingUserLocation()
    }
}
