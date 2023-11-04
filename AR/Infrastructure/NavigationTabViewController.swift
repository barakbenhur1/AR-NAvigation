//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit
import AVFAudio

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
    func reroute()
    func isMute() -> Bool
}

internal class NavigationTabViewModel: NSObject {
    private var synthesizer: AVSpeechSynthesizer? = nil
    private var timers: [String: Timer?]!
    
    override init() {
        timers = [:]
        super.init()
    }
    
    func stopTimers() {
        timers.values.forEach({ timer in
            timer?.invalidate()
        })
        timers = [:]
    }
    
    private func stopTimer(key: String) {
        let timer = timers?[key]
        timer??.invalidate()
        timers[key] = nil
    }
    
    private func setTimer(key: String, time: CGFloat, function: @escaping () -> ()) {
        let timer = Timer(timeInterval: time, repeats: true, block: { timer in
            function()
        })
        
        RunLoop.main.add(timer, forMode: .common)
        
        timers[key] = timer
    }
    
    func setNavigtionInfoTimer(time: CGFloat ,to: CLLocation?, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()) {
        stopTimer(key: "setNavigtionInfoTimer")
        setTimer(key: "setNavigtionInfoTimer",time: time) { [weak self] in
            guard let self else { return }
            calculateNavigtionInfo(to: to, transportType: transportType, success: success, error: error)
        }
    }
    
    func calculateNavigtionInfo(to: CLLocation?, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()){
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
        
        directions.calculate { response, err in
            if let err = err {
                error(err)
            }
            else {
                success(directions, response?.routes)
            }
        }
    }
    
    func voiceText(string: String?) {
        guard let string else { return }
        let utterance = AVSpeechUtterance(string: string)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.speak(utterance)
    }
    
    func playSound(name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: nil)!
        AudioManager.defualt.setupPlayer(url)
        AudioManager.defualt.play()
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
            guard let delegate, !delegate.isMute() else { return }
            voice()
        }
    }
    
    private var selectedStep: Int!
    
    private var radius: (_ step: MKRoute.Step, _ transportType: MKDirectionsTransportType) -> (CGFloat) = { step, transportType in
        switch transportType {
        case .walking:
            return min(20 ,step.distance / 2)
        default:
            return step.distance / 2
        }
    }
    
    private let viewModel = NavigationTabViewModel()
    
    var delegate: TabBarViewControllerDelegate?
    var transportType: MKDirectionsTransportType = .walking
    var to: CLLocation?
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
        handeleLoctionManager()
        handeleTabBar()
        handeleTableView()
        getRoutes()
        setDestination()
        setupNavigtionInfoTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        viewModel.stopTimers()
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    //MARK: - Private Helpers
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            self?.locationManager.stopUpdatingLocation()
            self?.locationManager.stopUpdatingHeading()
            
            self?.viewModel.stopTimers()
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
    
    private func getRoutes() {
        viewModel.calculateNavigtionInfo(to: to, transportType: transportType) { [weak self]  directions, routes in
            guard let self else { return }
            delegate?.success(directions: directions, routes: routes)
            updateRoutes(routes: routes)
        } error: { [weak self]  error in
            guard let self else { return }
            delegate?.error(error: error)
        }
    }
    
    private func setupNavigtionInfoTimer() {
        viewModel.setNavigtionInfoTimer(time: 1.667, to: to, transportType: transportType) { [weak self] directions,routes in
            guard let self else { return }
            delegate?.success(directions: directions, routes: routes)
        } error: { [weak self] error in
            guard let self = self else { return }
            delegate?.error(error: error)
        }
    }
    
    private func updateRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
        
        for step in routes.first?.steps ?? [] {
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: radius(step, transportType), identifier: step.description)
            region.notifyOnEntry = true
            locationManager.startMonitoring(for: region)
        }
    }
    
    private func setDestination() {
        guard let destination = to else { return }
        viewControllers.forEach({ viewController in
            viewController.setDestination(endPoint: destination)
        })
    }
    
    private func reroute() {
        // play reroute sound
        viewModel.voiceText(string: NSLocalizedString("reroute", comment: ""))
        viewModel.playSound(name: "recalculate.mp3")
        // reroute logic
        delegate?.reroute()
        getRoutes()
    }
    
    //MARK: - Public Helpers
    
    func voice() {
        let step = routes?.first?.steps[currentStep]
        let preText = currentStep == 0 ? "" : "in \(Int(locationManager.location!.distance(from: CLLocation(latitude: step!.polyline.coordinate.latitude, longitude: step!.polyline.coordinate.longitude)))) meters"
        let text = currentStep == 0 && (step == nil || step!.instructions.isEmpty) ? NSLocalizedString("start here", comment: "") : step?.instructions ?? ""
        viewModel.voiceText(string: "\(preText) \(text)")
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
        
        if indexPath.row == 0 && (cell.title.text == nil || cell.title.text!.isEmpty) {
            cell.title.text = NSLocalizedString("start here", comment: "")
        }
        
        cell.contentView.backgroundColor = selectedStep == indexPath.row ? .lightGray : .white
        cell.contentView.backgroundColor = currentStep == indexPath.row ? .green : .white
        
        return cell
    }
}

extension NavigationTabViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first, let pointCount = routes?.first?.polyline.pointCount else { return }
        // check if user gos off the route
        for i in 0..<pointCount {
            let coordinate = routes.first!.polyline.points()[i].coordinate
            guard location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) > 10 else { return }
        }
        // reroute
        reroute()
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let region = region as? CLCircularRegion {
            currentStep = steps?.firstIndex { step in
                return step.polyline.coordinate.latitude == region.center.latitude && step.polyline.coordinate.longitude == region.center.longitude
            }
        }
    }
}
