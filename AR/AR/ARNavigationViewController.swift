//
//  ARNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class ARNavigationViewController: UIViewController, TabBarViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var arView: UIView!
    @IBOutlet weak var regularView: RegularNavigationView! {
        didSet {
            regularView.trackUserLocation = .followWithHeading
            regularView.mapView.isUserInteractionEnabled = false
        }
    }
    
    @IBOutlet weak var mapButton: UIButton! {
        didSet {
            mapButton.setImage(UIImage(named: "map"), for: .normal)
        }
    }
    
    //MARK: - Properties
    private var ar: ARNavigationView!
    
    private var routes: [MKRoute]!
    
    private let mapAlpha = 0.7
    
    var step: Int?
    var resetMapCamera: (() -> ())?
    
    //MARK: - Life cycle
    deinit {
        ar?.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ar = ARNavigationView()
        ar.addTo(view: arView)
        regularView.addRoutes(routes: routes)
        ar?.addRoutes(routes: routes)
        ar.run()
        ar?.pause()
        regularView?.goToStep(index: step)
        
        regularView?.resetMapCamera = { [weak self] in
            self?.resetMapCamera?()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
        ar?.pause()
        ar?.turneFlashOff()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupObservers()
        ar?.run()
        ar?.toggleFlashIfNeeded()
    }
    
    //MARK: - Helpers
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.ar?.pause()
            self?.ar?.turneFlashOff()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.ar?.run()
            self?.ar?.toggleFlashIfNeeded()
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setRoutes(routes: [MKRoute]) {
        self.routes = routes
        regularView?.addRoutes(routes: routes)
        ar?.addRoutes(routes: routes)
    }
    
    func setDestination(endPoint: CLLocation) {
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
    
    //MARK: - @IBActions
    @IBAction func handleMap(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = sender.isSelected ? 1 : 0.5
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            self.regularView.alpha = sender.isSelected ? self.mapAlpha : 0
        }
    }
}
