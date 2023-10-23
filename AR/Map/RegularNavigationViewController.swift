//
//  RegularNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class RegularNavigationViewController: UIViewController, TabBarViewController {
    @IBOutlet weak var regularView: RegularNavigationView! {
        didSet {
            regularView.trackUserLocation = .followWithHeading
        }
    }
    
    private var routes: [MKRoute]!
    
    var step: Int?
    var resetMapCamera: (() -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        regularView?.addRoutes(routes: routes)
        
        regularView?.resetMapCamera = { [weak self] in
            self?.resetMapCamera?()
        }
    }
   
    func setRoutes(routes: [MKRoute]) {
        self.routes = routes
        regularView?.addRoutes(routes: routes)
    }
    
    func setDestination(endPoint: CLLocation) {
        regularView?.setEndPoint(point: endPoint)
    }
    
    func goToStep(index: Int) {
        step = index
        regularView.goToStep(index: index)
    }
}
