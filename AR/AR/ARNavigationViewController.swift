//
//  ARNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class ARNavigationViewController: UIViewController, TabBarViewController {
    @IBOutlet weak var arView: UIView!
    @IBOutlet weak var regularView: RegularNavigationView!
    @IBOutlet weak var mapButton: UIButton! {
        didSet {
            mapButton.setImage(UIImage(named: "map"), for: .normal)
        }
    }
    
    private var ar: ARNavigationView!
    
    private var route: MKRoute!
    private var location: CLLocationCoordinate2D!
    
    deinit {
        ar?.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ar = ARNavigationView()
        ar.addTo(view: arView)
//        ar?.run()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ar?.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ar?.run()
        regularView.setLocation(location: location)
        regularView.navigate(location: location)
        regularView.addRoute(route: route)
        ar?.addRoute(route: route)
    }
    
    func setRoute(route: MKRoute) {
        self.route = route
        regularView?.addRoute(route: route)
        ar?.addRoute(route: route)
    }
    
    func setLocation(location: CLLocationCoordinate2D) {
        self.location = location
        regularView?.setLocation(location: location)
    }
    
    @IBAction func handleMap(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = !sender.isSelected ? 0.5 : 1
        regularView.isHidden = !sender.isSelected
    }
}
