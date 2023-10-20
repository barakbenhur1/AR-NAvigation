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
  
    @IBOutlet weak var regularView: RegularNavigationView! {
        didSet {
            regularView.trackUserLocation = .followWithHeading
        }
    }
    
    @IBOutlet weak var mapButton: UIButton! {
        didSet {
            mapButton.setImage(UIImage(named: "map"), for: .normal)
        }
    }
    
    private var ar: ARNavigationView!
    
    private var routes: [MKRoute]!
    
    deinit {
        ar?.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ar = ARNavigationView()
        ar.addTo(view: arView)
        ar.run()
        ar?.pause()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
        ar?.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupObservers()
        ar?.run()
        regularView.addRoutes(routes: routes)
        ar?.addRoutes(routes: routes)
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.ar?.pause()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.ar?.run()
        }
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setRoutes(routes: [MKRoute]) {
        self.routes = routes
        regularView?.addRoutes(routes: routes)
        ar?.addRoutes(routes: routes)
    }
    
    @IBAction func handleMap(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = !sender.isSelected ? 0.5 : 1
        regularView.isHidden = !sender.isSelected
        
        regularView.trackUserLocation = regularView.isHidden ? .none : .followWithHeading
    }
}
