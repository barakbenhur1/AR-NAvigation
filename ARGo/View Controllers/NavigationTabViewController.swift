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

struct NavigationError: Error {}

//MARK: - Protocols
protocol TabBarViewController: UIViewController {
    func setRoutes(routes: [MKRoute])
    func setDestination(endPoint: CLLocation)
    func goToStep(index: Int)
    func reCenter()
    var step: Int? { get set }
}

protocol TabBarViewControllerDelegate: UIViewController {
    func success(directions: MKDirections, routes: [MKRoute]?, isFirstTime: Bool)
    func error(error: Error, isFirstTime: Bool)
    func isMute() -> Bool
}

internal class NavigationTabViewModel: NSObject {
    private let synthesizer: AVSpeechSynthesizer!
    private var timers: [String: Timer?]!
    
    override init() {
        timers = [:]
        synthesizer = AVSpeechSynthesizer()
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
        AdsManager.sheard.getAd(unitID: AdMobUnitID.sheard.endRouteInterstitialNoRewardID, adView: adView)
    }
    
    func notifyWhenAdDismissed(dismiss: @escaping () -> ()) {
        AdsManager.sheard.adDidDismissFullScreenContent {
            dismiss()
        }
    }
    
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        AdsManager.sheard.getBanner(banner: banner)
    }
    
    func setNavigtionInfoTimer(time: CGFloat ,to: CLLocation?, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()) {
        stopTimer(key: "setNavigtionInfoTimer")
        setTimer(key: "setNavigtionInfoTimer",time: time) { [weak self] in
            guard let self else { return }
            calculateNavigtionInfo(to: to, transportType: transportType, success: success, error: error)
        }
    }
    
    func calculateNavigtionInfo(to: CLLocation?, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()) {
        guard let destinationLocation = to?.coordinate else {
            error(NavigationError())
            return
        }
        NavigationManager.calculateNavigtionInfo(to: destinationLocation, transportType: transportType, success: success, error: error)
    }
    
    func voiceText(string: String?) {
        guard let string else { return }
        let utterance = AVSpeechUtterance(string: string)
        utterance.voice = getVoice() ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
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
    
    private func getVoice() -> AVSpeechSynthesisVoice? {
        if let voiceID = UserDefaults.standard.string(forKey:"voiceID - \(Locale.getDescription(id: Locale.current.identifier)?.components(separatedBy: " ").first ?? "error")") {
           return AVSpeechSynthesisVoice(identifier: voiceID)
        }
        return nil
    }
}

class NavigationTabViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var adBannerView: CustomGADBannerView!
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
    @IBOutlet weak var adHeightConstraint: NSLayoutConstraint!
    private var viewControllers: [TabBarViewController]!
    private var loader: LoaderView!
    private var regionManager: RegionManager!
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
    private var isValid: Bool!
    
    weak var delegate: TabBarViewControllerDelegate?
    var transportType: MKDirectionsTransportType = .walking
    var to: CLLocation?
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loader = LoaderView()
        loader.type = .new
        loader.addTo(view: view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        listTableView.reloadData()
    }
    
    private func setUserOnRouteCheckTimer() {
        viewModel.setTimer(key: "isOnRute", time: 5) { [weak self] in
            guard let self else { return }
            guard let userLocation = regionManager.location else { return }
            guard let route = routes.first else { return }
            guard !location(userLocation, isOn: route) else { return }
            reroute()
        }
    }
    
    private func handeleRegionManager() {
        regionManager = RegionManager()
        regionManager?.startUpdatingLocation()
        
        regionManager?.trackRegion { [weak self] index, count, state in
            guard let self else { return }
            switch state {
            case .enter:
                isStartReroutingAllowed = true
                currentStep = index
                voice(for: currentStep)
            case .exit:
                isStartReroutingAllowed = true
            case .determine(let region, let state):
                guard let region = region as? CLCircularRegion else { return }
                guard state == .inside else { return }
                guard index == 1 && count > 1 else { return }
                guard currentStep == 0 else { return }
                isStartReroutingAllowed = regionManager.location!.distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)) < 34
                currentStep = index
                guard let isValid, isValid else { return }
                voice(for: currentStep)
            }
        }
        
        regionManager?.didUpdateLocations { [weak self] location in
            guard let self else { return }
            guard let to else { return }
            guard location.distance(from: to) <= 10 else { return }
            viewModel.voiceText(string: routes.first?.steps.last?.instructions)
            viewModel.stopTimers()
            stopMonitoringAllRegions()
            let ar = viewControllers[0] as! ARNavigationViewController
            ar.arrived()
            let map = viewControllers[1] as! RegularNavigationViewController
            map.arrived()
            listButton.isHidden = true
            listTableView.isHidden = true
            getAd {/* [weak self] in*/
//                guard let self else { return }
            }
        }
    }
    
    private func getAd(complition: @escaping () -> ()) {
        viewModel.notifyWhenAdDismissed(dismiss: complition)
        viewModel.getAd { [weak self] adView in
            guard let self else { return }
            guard let adView else { return }
            showAD(interstitial: adView)
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
        tabBar.view.isHidden = true
        tabBar.tabBar.tintColor = .black
        let map = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "map") as! RegularNavigationViewController
        let ar = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ar") as! ARNavigationViewController
        viewControllers = [ar, map]
        tabBar.setViewControllers(viewControllers, animated: true)
        tabBar.view.addTo(view: view)
        view.sendSubviewToBack(tabBar.view)
        
        map.delegate = self
        ar.delegate = self
    }
    
    private func getRoutes() {
        viewModel.calculateNavigtionInfo(to: to, transportType: transportType) { [weak self]  directions, routes in
            guard let self else { return }
            delegate?.success(directions: directions, routes: routes, isFirstTime: true)
            updateRoutes(routes: routes)
        } error: { [weak self]  error in
            guard let self else { return }
            delegate?.error(error: error, isFirstTime: true)
        }
    }
    
    private func setupNavigtionInfoTimer() {
        viewModel.setNavigtionInfoTimer(time: 1.3, to: to, transportType: transportType) { [weak self] directions, routes in
            guard let self else { return }
            delegate?.success(directions: directions, routes: routes, isFirstTime: false)
        } error: { [weak self] error in
            guard let self = self else { return }
            delegate?.error(error: error, isFirstTime: false)
        }
    }
    
    private func stopMonitoringAllRegions() {
        regionManager?.stopUpdatingLocation()
        regionManager?.stopMonitoringAllRegions()
    }
    
    private func startMonitoringRegions() {
        regionManager?.startUpdatingLocation()
        regionManager?.startMonitoringRegions(with: self.routes)
    }
    
    private func showAD(interstitial: GADInterstitialAd) {
        interstitial.present(fromRootViewController: self)
    }
    
    private func updateRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
        
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
        regionManager?.stopUpdatingLocation()
        regionManager.stopMonitoringAllRegions()
        viewModel.stopTimers()
        let ar = viewControllers[0] as! ARNavigationViewController
        ar.removeRoute()
        let map = viewControllers[1] as! RegularNavigationViewController
        map.removeRoute()
        loader.type = .reroute
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
        viewModel.setTimer(key: "isRerouteAllowed", time: 15, repeats: false) { [weak self] in
            guard let self else { return }
            self.isRerouteAllowed = true
            self.isStartReroutingAllowed = true
        }
    }
    
    private func loadBanner() {
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            adBannerView.load(banner)
            adBannerView.bannerViewDidReceiveAd { [weak self] in
                guard let self else { return }
                adBannerView.isHidden = false
            }
        }
    }
    
    //MARK: - Public Helpers
    
    func startResorces() {
        handeleRegionManager()
        handeleTabBar()
        handeleTableView()
        setDestination()
        getRoutes()
    }
    
    func closeResorces() {
        regionManager?.stopUpdatingLocation()
        stopMonitoringAllRegions()
        viewModel.stopTimers()
        viewModel.stopVoice()
    }
    
    func unvalid() {
        isValid = false
        view.isUserInteractionEnabled = false
        viewModel.stopVoice()
        viewModel.stopTimers()
        tabBar.selectedIndex = 1
        let ar = viewControllers[0] as! ARNavigationViewController
        ar.unvalid()
        
        let map = viewControllers[1] as! RegularNavigationViewController
        tabBar.view.isHidden = false
        listButton.isHidden = true
        tabBar.tabBar.isHidden = true
        map.unvalid()
        loader.isHidden = true
        
        if let delegate, !delegate.isMute() {
            let text = "\(NSLocalizedString("destination", comment: "")) \(NSLocalizedString("is to close", comment: ""))"
            viewModel.voiceText(string: text)
        }
        
        guard LocationManager.trackingAuthorizationStatusIsAllowed else { return }
        adBannerView.adUnitID = AdMobUnitID.sheard.bannerToCloseID
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.delegate = adBannerView
        loadBanner()
    }
    
    func valid() {
        isValid = true
        loader.setGif()
        setupNavigtionInfoTimer()
        voice(for: currentStep ?? 0)
        hideLoader()
        let ar = viewControllers[0] as! ARNavigationViewController
        ar.valid()
    }
    
    func error() {
        loader.type = .error
        viewModel.voiceText(string: LoaderType.error.getInfo().text)
    }
    
    private func hideLoader() {
        loader.setGif()
        listButton.isHidden = false
        loader.isHidden = true
        tabBar.view.isHidden = false
    }
    
    private func voice(for stepIndex: Int, skipPreText: Bool = false) {
        guard let delegate, !delegate.isMute() else { return }
        guard let steps =  routes?.first?.steps, !steps.isEmpty else { return }
        let currentStep = stepIndex
        let step = steps[currentStep < steps.count ? currentStep : steps.count - 1]
        let preText = skipPreText ? "" : "\(NSLocalizedString("in", comment: "")) \(Int(regionManager.location!.distance(from: CLLocation(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)))) \(NSLocalizedString("meters", comment: ""))"
        let text =  currentStep == 0 && step.instructions.isEmpty ? NSLocalizedString("start here", comment: "") : step.instructions
        let voiceText = "\(preText) \(text)"
        viewModel.voiceText(string: voiceText)
    }
    
    func voice(enabled: Bool) {
        if enabled {
            guard let currentStep else { return }
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
