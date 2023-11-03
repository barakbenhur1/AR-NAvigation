//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

//MARK: - Protocols
protocol TabBarViewController: UIViewController {
    func setRoutes(routes: [MKRoute])
    func setDestination(endPoint: CLLocation)
    func goToStep(index: Int)
    func reCenter()
    var resetMapCamera: (() -> ())? { get set }
    var step: Int? { get set }
}

protocol TabBarViewControllerDelegate: UIViewController {
    func success(directions: MKDirections, routes: [MKRoute]?)
    func error(error: Error)
}

internal class NavigationTabViewModel: NSObject {
    func calculateNavigtionInfo(to: CLLocation?, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()) {
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
        
        directions.calculate { (response, err) in
            if let err = err {
                error(err)
            }
            else {
                success(directions, response?.routes)
            }
        }
    }
}

class NavigationTabViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var listTableView: UITableView! {
        didSet {
            listTableView.delegate = self
            listTableView.dataSource = self
            listTableView.layer.borderWidth = 0.5
            listTableView.layer.borderColor = UIColor.black.cgColor
        }
    }
    
    @IBOutlet weak var listButton: UIButton!
    @IBOutlet weak var listTableViewAnimationConstraint: NSLayoutConstraint!
    
    //MARK: - Properties
    private var tabBar: UITabBarController!
    private var viewControllers: [TabBarViewController]!
    private var locationManager: CLLocationManager!
    
    private var routes: [MKRoute]! {
        didSet {
            guard let s = routes.first?.steps else { return }
            steps = s
        }
    }
    
    private var steps: [MKRoute.Step]! {
        didSet {
            currentStep = 0
            selectedStep = 0
        }
    }
    
    private var currentStep: Int! {
        didSet {
            listTableView.reloadData()
        }
    }
    
    private var selectedStep: Int!
    
    private let viewModel = NavigationTabViewModel()
    private var timer: Timer!
    
    var delegate: TabBarViewControllerDelegate?
    var transportType: MKDirectionsTransportType = .walking
    var to: CLLocation?
    
    //MARK: - Life cycle
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
        handeleLoctionManager()
        handeleTabBar()
        handeleTableView()
        setDestination()
        setupNavigtionInfoTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    //MARK: - Helpers
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.locationManager.stopUpdatingHeading()
            
            self?.timer?.invalidate()
            self?.timer = nil
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.locationManager.startUpdatingLocation()
            self?.locationManager.startUpdatingHeading()
            
            self?.setupNavigtionInfoTimer()
        }
    }
    
    private func handeleLoctionManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func handeleTableView() {
        listTableViewAnimationConstraint.constant = 40
        listTableView.rowHeight = 50
        listTableView.alpha = 0
        listTableView.layer.masksToBounds = true
        listTableView.layer.cornerRadius = 10
        listTableView.register(UINib(nibName: "StepTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
    
    private func handeleTabBar() {
        tabBar = UITabBarController()
        tabBar.tabBar.tintColor = .black
        let map = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "map") as! RegularNavigationViewController
        let ar = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ar") as! ARNavigationViewController
        viewControllers = [map, ar]
        tabBar.setViewControllers(viewControllers, animated: true)
        tabBar.view.addTo(view: view)
        view.sendSubviewToBack(tabBar.view)
        
        map.resetMapCamera = { [weak self] in
            guard let self = self else { return }
            self.listTableView.reloadData()
            self.listTableView.scrollToRow(at: .init(row: self.currentStep, section: 0), at: .top, animated: false)
            self.selectedStep = self.currentStep
            ar.reCenter()
        }
        
        ar.resetMapCamera = { [weak self] in
            guard let self = self else { return }
            self.listTableView.reloadData()
            self.listTableView.scrollToRow(at: .init(row: self.currentStep, section: 0), at: .top, animated: false)
            self.selectedStep = self.currentStep
            map.reCenter()
        }
    }
    
    private func setupNavigtionInfoTimer() {
        timer = Timer(timeInterval: 1.667, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            viewModel.calculateNavigtionInfo(to: to, transportType: transportType) { [weak self] directions,routes in
                guard let self = self else { return }
                delegate?.success(directions: directions, routes: routes)
                updateRoute(routes: routes)
            }
        error: { [weak self] error in
            guard let self = self else { return }
            delegate?.error(error: error)
        }
        })
        
        timer.fire()
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc private func updateRoute(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
        
        for step in routes.first?.steps ?? [] {
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: 4, identifier: step.description)
            region.notifyOnEntry = true
            locationManager.startMonitoring(for: region)
        }
    }
    
    @objc private func setDestination() {
        guard let destination = to else { return }
        viewControllers.forEach({ viewController in
            viewController.setDestination(endPoint: destination)
        })
    }
    
    //MARK: -  @IBActions
    @IBAction func didClickOnList(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        listTableViewAnimationConstraint.constant = sender.isSelected ? 115 : 40
        listButton.alpha = sender.isSelected ? 1 : 0.5
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            self.listTableView.alpha = sender.isSelected ? 0.7 : 0
            self.view.layoutIfNeeded()
        }
    }
}

//MARK: - Extensions
extension NavigationTabViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedStep = indexPath.row
       
        for i in  0..<(routes?.first?.steps.count ?? 0) {
            tableView.cellForRow(at: .init(row: i, section: 0))?.contentView.backgroundColor = currentStep == i ? .green : .white
        }
        tableView.cellForRow(at: indexPath)?.contentView.backgroundColor = currentStep == indexPath.row ? .green : .lightGray
        viewControllers.forEach({ viewController in
            viewController.goToStep(index: indexPath.row)
        })
    }
}

extension NavigationTabViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routes?.first?.steps.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? StepTableViewCell else { return UITableViewCell() }
        cell.title.text = routes.first?.steps[indexPath.row].instructions
        
        cell.contentView.backgroundColor = selectedStep == indexPath.row ? .lightGray : .white
        cell.contentView.backgroundColor = currentStep == indexPath.row ? .green : .white
        
        return cell
    }
}

extension NavigationTabViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let region = region as? CLCircularRegion {
            currentStep = steps.firstIndex { step in
                return step.polyline.coordinate.latitude == region.center.latitude && step.polyline.coordinate.longitude == region.center.longitude
            }
        }
    }
}
