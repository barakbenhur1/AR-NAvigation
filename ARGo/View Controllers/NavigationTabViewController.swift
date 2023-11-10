//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit
import AVFAudio
import GoogleMobileAds

//MARK: - Protocols
protocol TabBarViewController: UIViewController {
    func setRoutes(routes: [MKRoute])
    func setDestination(endPoint: CLLocation)
    func goToStep(index: Int)
    func reCenter()
    var step: Int? { get set }
}

protocol TabBarViewControllerDelegate: UIViewController {
    func success(directions: MKDirections, routes: [MKRoute]?)
    func error(error: Error)
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
    
    func stopTimer(key: String) {
        let timer = timers?[key]
        timer??.invalidate()
        timers[key] = nil
    }
    
    func setTimer(key: String, time: CGFloat, repeats: Bool = true, function: @escaping () -> ()) {
        let timer = Timer(timeInterval: time, repeats: repeats, block: { timer in
            function()
        })
        
        timers[key] = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    func getAd(adView: @escaping ((GADInterstitialAd?) -> ())) {
        AdsManager.sheard.getAd(unitID: AdMobUnitID.sheard.interstitialNoRewardID, adView: adView)
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
    
    func playSound(name: String, didFinsish: (() -> ())? = nil) {
        let url = Bundle.main.url(forResource: name, withExtension: nil)!
        AudioManager.defualt.setupPlayer(url)
        AudioManager.defualt.play {
           didFinsish?()
        }
    }
    
    func stopVoice() {
        synthesizer?.stopSpeaking(at: .immediate)
    }
}

class NavigationTabViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var listHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var listButton: UIButton!
    @IBOutlet weak var listTableViewAnimationConstraint: NSLayoutConstraint!
    @IBOutlet weak var listTableView: UITableView! {
        didSet {
            listTableView.delegate = self
            listTableView.dataSource = self
            listTableView.layer.borderWidth = 0.5
            listTableView.layer.borderColor = UIColor.black.cgColor
        }
    }
    
    //MARK: - Properties
    private var tabBar: UITabBarController!
    private var viewControllers: [TabBarViewController]!
    private var loader: LoaderView!
    @objc private var locationManager: LocationManager!
    private var monitoredRegions: [CLRegion]!
    private var isStartReroutingAllowed: Bool!
    private var isRerouteAllowed: Bool!
    
    private var routes: [MKRoute]! {
        didSet {
            guard let s = routes.first?.steps else { return }
            listHeightConstraint.constant = s.count > 2 ? s.count > 3 ? 160 : 150 : 100
            steps = s
        }
    }
    
    private var steps: [MKRoute.Step]! {
        didSet {
            currentStep = 0
            voice(for: currentStep)
        }
    }
    
    private var currentStep: Int! {
        didSet {
            listTableView.reloadData()
            listTableView.scrollToRow(at: .init(row: currentStep, section: 0), at: .top, animated: true)
        }
    }
    
    private var radius: (_ step: MKRoute.Step, _ transportType: MKDirectionsTransportType) -> (CGFloat) = { step, transportType in
        switch transportType {
        case .walking:
            return max(min(step.distance / 2 , 4) , 1)
        default:
            return step.distance / 2
        }
    }
    
    private let viewModel = NavigationTabViewModel()
    
    weak var delegate: TabBarViewControllerDelegate?
    var transportType: MKDirectionsTransportType = .walking
    var to: CLLocation?
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handeleLoctionManager()
        handeleTabBar()
        handeleTableView()
        setDestination()
        getRoutes()
    }
    
    private func setUserOnRouteCheckTimer() {
        viewModel.setTimer(key: "isOnRute", time: 5) { [weak self] in
            guard let self else { return }
            guard let userLocation = locationManager.location else { return }
            guard let route = routes.first else { return }
            guard !location(userLocation, isOn: route) else { return }
            reroute()
        }
    }
    
    private func handeleLoctionManager() {
        locationManager = LocationManager()
        locationManager.trackDidUpdateLocations { [weak self] locations in
            guard let self else { return }
            locationManager(locationManager, didUpdateLocations: locations)
        }
        locationManager.trackDidEnterRegion { [weak self] region in
            guard let self else { return }
            locationManager(locationManager, didEnterRegion: region)
        }
        locationManager.trackDidExitRegion { [weak self] region in
            guard let self else { return }
            locationManager(locationManager, didExitRegion: region)
        }
        locationManager.trackDidDetermineState { [weak self] state, region in
            guard let self else { return }
            locationManager(locationManager, didDetermineState: state, for: region)
        }
    }
    
    private func location(_ location: CLLocation, isOn route: MKRoute) -> Bool {
        //check if user is on the route
        let distanceInMeters = 34.0
        let coordinates = route.polyline.coordinates
        return location.isInRange(coordinates: coordinates, distanceInMeters: distanceInMeters)
    }
    
    private func handeleTableView() {
        listTableViewAnimationConstraint.constant = 40
        listTableView.rowHeight = 50
        listTableView.alpha = 0
        listTableView.layer.masksToBounds = true
        listTableView.layer.cornerRadius = 10
        listTableView.register(UINib(nibName: "StepTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
        listButton.setImage(UIImage(systemName: "location.slash.circle.fill"), for: .normal)
        listButton.setImage(UIImage(systemName: "location.circle.fill"), for: .selected)
    }
    
    private func handeleTabBar() {
        tabBar = UITabBarController()
        tabBar.tabBar.tintColor = .black
        let map = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "map") as! RegularNavigationViewController
        let ar = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ar") as! ARNavigationViewController
        viewControllers = [ar, map]
        tabBar.setViewControllers(viewControllers, animated: true)
        tabBar.view.addTo(view: view)
        view.sendSubviewToBack(tabBar.view)
        
        loader = LoaderView()
        loader.isHidden = true
        loader.addTo(view: view, bottom: -tabBar.tabBar.frame.height - 34)
        
        map.delegate = self
        ar.delegate = self
    }
    
    private func getRoutes() {
        viewModel.calculateNavigtionInfo(to: to, transportType: transportType) { [weak self]  directions, routes in
            guard let self else { return }
            delegate?.success(directions: directions, routes: routes)
            loader.isHidden = true
            updateRoutes(routes: routes)
        } error: { [weak self]  error in
            guard let self else { return }
            loader.isHidden = true
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
    
    private func stopMonitoringAllRegions() {
        //stop monitoring all monitored regions
        monitoredRegions = []
        for region in (locationManager?.monitoredRegions ?? []) {
            locationManager?.stopMonitoring(for: region)
        }
    }
    
    private func startMonitoringRegions() {
        monitoredRegions = []
        for step in (routes?.first?.steps ?? []) {
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: radius(step, transportType), identifier: "\(step.polyline.coordinate)")
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager?.startMonitoring(for: region)
            monitoredRegions?.append(region)
        }
    }
    
    private func locationManager(_ manager: LocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        guard let to else { return }
        guard location.distance(from: to) <= 2 else { return }
        viewModel.voiceText(string: routes.first?.steps.last?.instructions)
        stopMonitoringAllRegions()
        viewModel.stopTimers()
        viewModel.getAd { [weak self] adView in
            guard let self else { return }
            guard let adView else { return }
            showAD(interstitial: adView)
        }
    }
    
    private func showAD(interstitial: GADInterstitialAd) {
        interstitial.present(fromRootViewController: self)
    }
    
    private func locationManager(_ manager: LocationManager, didEnterRegion region: CLRegion) {
        if let region = region as? CLCircularRegion {
            guard let index = monitoredRegions?.firstIndex(of: region) else { return }
            isStartReroutingAllowed = true
            if index < routes.first!.steps.count {
                currentStep = index
            }
            else {
                currentStep = routes.first!.steps.count - 1
                manager.stopMonitoring(for: region)
                monitoredRegions.remove(at: monitoredRegions.count - 1)
                
                guard !(routes?.first?.steps ?? []).isEmpty, let coordinate = to?.coordinate else { return }
                let region = CLCircularRegion(center: coordinate, radius: 4, identifier: "destention")
                region.notifyOnEntry = true
                region.notifyOnExit = true
                manager.startMonitoring(for: region)
                monitoredRegions?.append(region)
            }
            voice(for: index)
        }
    }
    
    private func locationManager(_ manager: LocationManager, didExitRegion region: CLRegion) {
        isStartReroutingAllowed = true
    }
    
    private func locationManager(_ manager: LocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if let region = region as? CLCircularRegion {
            guard state == .inside, let index = monitoredRegions?.firstIndex(of: region) else { return }
            if index == 1, monitoredRegions.count > 1 {
                currentStep = 1
                isStartReroutingAllowed = manager.location!.distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)) < 34
            }
        }
    }
    
    private func updateRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
        
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingHeading()
        setupNavigtionInfoTimer()
        setUserOnRouteCheckTimer()
        stopMonitoringAllRegions()
        startMonitoringRegions()
    }
    
    private func setDestination() {
        guard let destination = to else { return }
        isStartReroutingAllowed = false
        isRerouteAllowed = true
        viewControllers.forEach({ viewController in
            viewController.setDestination(endPoint: destination)
        })
    }
    
    private func reroute() {
        guard let isStartReroutingAllowed, isStartReroutingAllowed, let isRerouteAllowed, isRerouteAllowed else { return }
        // close locations list
        listButton.isSelected = false
        listButton.alpha = 0.5
        listTableView.alpha = 0
        listTableViewAnimationConstraint.constant = 40
        
        // re-route logic
        locationManager.stopUpdatingLocation()
        viewModel.stopTimers()
        loader.isHidden = false
        
        // play re-route sound
        viewModel.playSound(name: "recalculate.mp3") { [weak self] in
            guard let self else { return }
            getRoutes()
        }
        
        if let delegate, !delegate.isMute() {
            viewModel.voiceText(string: NSLocalizedString("reroute", comment: ""))
        }
        
        self.isRerouteAllowed = false
        self.isStartReroutingAllowed = false
        viewModel.setTimer(key: "isRerouteAllowed", time: 8, repeats: false) { [weak self] in
            guard let self else { return }
            self.isRerouteAllowed = true
        }
    }
    
    //MARK: - Public Helpers
    
    func closeResorces() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingHeading()
        stopMonitoringAllRegions()
        viewModel.stopTimers()
        viewModel.stopVoice()
    }
    
    func unvalid() {
        view.isUserInteractionEnabled = false
        tabBar.tabBar.isHidden = true
        listButton.isHidden = true
        viewModel.stopVoice()
        viewModel.stopTimers()
        let map = viewControllers[1] as! RegularNavigationViewController
        map.unvalid()
    }
    
    func valid() {
        let map = viewControllers[1] as! RegularNavigationViewController
        map.valid()
    }
    
    func showButtons() {
        let ar = viewControllers[0] as! ARNavigationViewController
        UIView.animate(withDuration: 0.2) { [weak ar] in
            guard let ar else { return }
            ar.mapButton.alpha = 0.5
        }
    }
    
    private func voice(for _step: Int, skipPreText: Bool = false) {
        guard let delegate, !delegate.isMute() else { return }
        guard let currentStep else { return }
        guard let steps =  routes?.first?.steps, !steps.isEmpty else { return }
        let step = steps[currentStep < steps.count ? currentStep : steps.count - 1]
        let preText = skipPreText ? "" : "\(NSLocalizedString("in", comment: "")) \(Int(locationManager.location!.distance(from: CLLocation(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)))) \(NSLocalizedString("meters", comment: ""))"
        let text =  currentStep == 0 && step.instructions.isEmpty ? NSLocalizedString("start here", comment: "") : step.instructions
        let voiceText = "\(preText) \(text)"
        viewModel.voiceText(string: voiceText)
    }
    
    func voice(enabled: Bool) {
        if enabled {
            voice(for: currentStep, skipPreText: true)
        }
        else {
            viewModel.stopVoice()
        }
    }
    
    //MARK: -  @IBActions
    
    @IBAction func didClickOnList(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        listTableViewAnimationConstraint.constant = sender.isSelected ? 115 : 40
        listButton.alpha = sender.isSelected ? 1 : 0.5
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self else { return }
            listTableView.alpha = sender.isSelected ? 0.7 : 0
            view.layoutIfNeeded()
        }
    }
}

//MARK: - Extensions

extension NavigationTabViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
        
        cell.contentView.backgroundColor = currentStep == indexPath.row ? .lightGray : .white
        
        return cell
    }
}

extension NavigationTabViewController: NavigationViewControllerDelegate {
    func resetMapCamera(view: NavigationViewController) {
        self.listTableView.reloadData()
        self.listTableView.scrollToRow(at: .init(row: self.currentStep, section: 0), at: .top, animated: false)
        view.reCenter()
    }
}
