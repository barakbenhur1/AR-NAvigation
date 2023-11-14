//
//  RegularNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit
import GoogleMobileAds

class RegularNavigationViewController: UIViewController, TabBarViewController, NavigationViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var regularView: RegularNavigationView! {
        didSet {
            regularView.trackUserLocation = .followWithHeading
        }
    }
    
    private var routes: [MKRoute]!
    private var endPoint: CLLocation!
    
    var step: Int?
    weak var delegate: (any NavigationViewControllerDelegate)?
    
    //MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        initRegular()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        regularView?.updateInfoLabel()
    }
    
    //MARK: - Private Helpers
    private func initRegular() {
        regularView?.setEndPoint(point: endPoint)
        regularView?.addRoutes(routes: routes)
        regularView?.goToStep(index: step)
        resetMapCameraListner()
    }
    
    private func resetMapCameraListner() {
        regularView.setResetCamera { [weak self] in
            guard let self else { return }
            delegate?.resetMapCamera(view: self)
        }
    }
    
    //MARK: - Public Helpers
    func unvalid() {
        regularView?.unvalid()
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
