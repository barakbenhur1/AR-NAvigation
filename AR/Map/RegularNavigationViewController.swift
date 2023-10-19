//
//  RegularNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class RegularNavigationViewController: UIViewController, TabBarViewController {
    @IBOutlet weak var regularView: RegularNavigationView!
    
    private var route: MKRoute!
    private var location: CLLocationCoordinate2D!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        regularView.setLocation(location: location)
        regularView.navigate(location: location)
        regularView.addRoute(route: route)
    }
    
    func setRoute(route: MKRoute) {
        guard self.route == nil else { return }
        self.route = route
        regularView?.addRoute(route: route)
    }
    
    func setLocation(location: CLLocationCoordinate2D) {
        self.location = location
        regularView?.setLocation(location: location)
    }
}
