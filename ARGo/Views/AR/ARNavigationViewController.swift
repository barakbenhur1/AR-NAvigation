//
//  ARNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

class ARNavigationViewController: UIViewController, TabBarViewController, NavigationViewController {    
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
            mapButton.setImage(UIImage(named: "mapDisabled"), for: .disabled)
        }
    }
    
    //MARK: - Properties
    private var ar: ARNavigationView!
    private var routes: [MKRoute]!
    private var endPoint: CLLocation!
    private let mapAlpha = 0.7
    
    weak var delegate: NavigationViewControllerDelegate?
    
    private var isValid: Bool!
    
    var step: Int?
    
    //MARK: - Life cycle
    deinit {
        ar?.destroy()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.alpha = 0
        initRegular()
        initAR()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let isValid, isValid else { return }
        setupObservers()
        ar?.run()
        ar?.toggleFlashIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let isValid, isValid else { return }
        removeObservers()
        ar?.stopTimers()
        ar?.turnFlashOff()
        ar?.pause()
    }
    
    //MARK: - Helpers
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.ar?.stopTimers()
            self?.ar?.pause()
            self?.ar?.turnFlashOff()
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
    
    private func initRegular() {
        regularView.setEndPoint(point: endPoint)
        regularView.addRoutes(routes: routes)
        regularView?.goToStep(index: step)
        resetMapCameraListner()
    }
    
    private func initAR() {
        guard CameraManager.isAuthorized else { return }
        ar?.destroy()
        ar = ARNavigationView()
        ar.addTo(view: arView)
        ar?.addRoutes(routes: routes) { [weak self] showMap in
            guard let self else { return }
            if showMap {
                regularView.alpha = 0.5
                mapButton.alpha = 1
                mapButton.isEnabled = false
            }
            else {
                mapButton.alpha = 0.5
            }
        }
        ar?.run()
    }
    
    func updateMonitoredRegion(index: Int, count: Int) {
        regularView?.updateMonitoredRegion(index: index, count: count)
        ar?.updateMonitoredRegion(index: index, count: count)
    }
    
    func updateMonitoredRegionWithDistance(index: Int) {
        regularView?.updateMonitoredRegionWithDistance(index: index)
        ar?.updateMonitoredRegionWithDistance(index: index)
    }
    
    func startAtNext() {
        ar?.startAtNext()
    }
    
    func unvalid() {
        isValid = false
        ar?.turnFlashOff()
    }
    
    func valid() {
        isValid = true
        setupObservers()
        ar?.run()
        ar?.toggleFlashIfNeeded()
        
        UIView.animate(withDuration: 2) { [weak self] in
            guard let self else { return }
            view.alpha = 1
        }
        
        guard !CameraManager.isAuthorized else { return }
        let popup = CameraManager.authorizationPopup
        present(popup, animated: true)
    }
    
    private func resetMapCameraListner() {
        regularView.setResetCamera { [weak self] in
            guard let self else { return }
            delegate?.resetMapCamera(view: self)
        }
    }
    
    func setRoutes(routes: [MKRoute]) {
        self.routes = routes
        regularView?.addRoutes(routes: routes)
        ar?.addRoutes(routes: routes) { [weak self] showMap in
            guard let self else { return }
            if showMap {
                regularView.alpha = 0.5
                mapButton.alpha = 1
                mapButton.isEnabled = false
            }
            else {
                mapButton.alpha = 0.5
            }
        }
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
    
    func arriveToStart() {
        let isFirst = ar.arriveToStart()
        if isFirst {
            regularView.alpha = 0
            mapButton.alpha = 0.5
            mapButton.isEnabled = true
        }
    }
    
    func arrived() {
        regularView?.arrived()
        ar?.arrived()
    }
    
    func removeRoute() {
        ar?.removeAllRoutesAndNodes(routes: routes)
        regularView?.removeRoute()
    }
    
    //MARK: - @IBActions
    @IBAction func handleMap(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = sender.isSelected ? 1 : 0.5
        
        regularView.transform = !sender.isSelected ? .identity : regularView.transform.scaledBy(x: 1.2, y: 1.2).concatenating(.init(translationX: 0, y: -25))
        
        UIView.animate(withDuration: 0.15) { [weak self] in
            guard let self else { return }
            regularView.alpha = sender.isSelected ? mapAlpha : 0
            regularView.transform = sender.isSelected ? .identity : regularView.transform.scaledBy(x: 1.2, y: 1.2).concatenating(.init(translationX: 0, y: -25))
        }
    }
}
