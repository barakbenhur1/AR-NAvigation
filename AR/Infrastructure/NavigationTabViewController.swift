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
    
    //MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        addObservers()
        setupObservers()
        handeleLoctionManager()
        handeleTabBar()
        handeleTableView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    //MARK: - Helpers
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateRoute(notification:)), name: .init("updateRoute"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setDestination(notification:)), name: .init("setDestination"), object: nil)
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.locationManager.stopUpdatingHeading()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.locationManager.startUpdatingLocation()
            self?.locationManager.startUpdatingHeading()
        }
    }
    
    private func handeleLoctionManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func handeleTableView() {
        listTableViewAnimationConstraint.constant = -listTableView.frame.height
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
    
    @objc private func updateRoute(notification: Notification) {
        guard self.routes == nil else { return }
        guard let routes = notification.object as? [MKRoute] else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
    }
    
    @objc private func updateSteps(currentLocation: CLLocation?) {
        guard let currentLocation = currentLocation else { return }
        guard let index = steps?.firstIndex(where: { step in
            let coordinate = step.polyline.coordinate
            let currentLoctionCoordinate = currentLocation.coordinate
            let currlat = Double(round(100 * coordinate.latitude) / 100)
            let userlat = Double(round(100 * currentLoctionCoordinate.latitude) / 100)
            let currlong = Double(round(100 * coordinate.longitude) / 100)
            let userlong = Double(round(100 * currentLoctionCoordinate.longitude) / 100)
            return currlat == userlat && currlong == userlong
        }) else { return }
        
        currentStep = index
    }
    
    @objc private func setDestination(notification: Notification) {
        guard let destination = notification.object as? CLLocation else { return }
        viewControllers.forEach({ viewController in
            viewController.setDestination(endPoint: destination)
        })
    }
    
    //MARK: -  @IBActions
    @IBAction func didClickOnList(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        listTableViewAnimationConstraint.constant = sender.isSelected ? 5 : -listTableView.frame.height
        listButton.alpha = sender.isSelected ? 1 : 0.5
        UIView.animate(withDuration: 0.5) { [weak self] in
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        updateSteps(currentLocation: locations.first)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
}
