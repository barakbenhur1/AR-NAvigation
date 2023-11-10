//
//  PickDestinationViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import MapKit
import CoreLocation
import GoogleMobileAds
import UserMessagingPlatform
import AdSupport

class PickDestinationViewModel: NSObject {
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        AdsManager.sheard.getBanner(banner: banner)
    }
    
    func requestTrackingAuthorization(success: @escaping () -> (), error: @escaping () -> ()) {
        LocationManager.requestTrackingAuthorization(success: success, error: error)
    }
}

class PickDestinationViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var adBannerView: CustomGADBannerView!
    @IBOutlet weak var mainStack: UIStackView!
    @IBOutlet weak var topStackView: UIStackView! {
        didSet {
            topStackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeSearch)))
        }
    }
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
        }
    }
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler)))
        }
    }
    
    @IBOutlet weak var search: UISearchBar! {
        didSet {
            search.delegate = self
        }
    }
    
    @IBOutlet weak var go: UIButton!
    
    //MARK: - Properties
    private var transportType: MKDirectionsTransportType = .walking
    
    private var locationManager: LocationManager!
    
    private var circleCenter: MKCircle?
    
    private var to: CLLocation! {
        didSet {
            go.isEnabled = to != nil
        }
    }
    
    private var placeMarks: [MKMapItem]!
    
    private let viewModel = PickDestinationViewModel()
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setAsRoot()
        didBecomeActiveNotification()
        handeleSearchView()
        handleTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager?.startUpdatingLocation()
        guard let adUnitID = adBannerView.adUnitID, !adUnitID.isEmpty else { return }
        loadBanner()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager?.stopUpdatingLocation()
    }
    
    //MARK: - Helpers
    private func didBecomeActiveNotification() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
            guard let self else { return }
            NotificationCenter.default.removeObserver(self)
            askPermissions()
        }
    }
    
    private func askPermissions() {
        if LocationManager.trackingAuthorizationStatus == .notDetermined  {
            let popup = UIAlertController(title: NSLocalizedString("App Tracking Transparency Approval", comment: ""), message: NSLocalizedString("App Tracking Transparency Approval text", comment: ""), preferredStyle: .alert)
            let ok = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { [weak self] _ in
                guard let self else { return }
                askApplePermissions()
            }
            popup.addAction(ok)
            present(popup, animated: true)
        }
        else {
            askApplePermissions()
        }
    }
    
    private func askApplePermissions() {
        viewModel.requestTrackingAuthorization { [weak self] in
            guard let self else { return }
            afterRequestTrackingAuthorization()
        } error: { [weak self] in
            guard let self else { return }
            afterRequestTrackingAuthorization()
        }
    }
    
    private func afterRequestTrackingAuthorization() {
        initAdBanner()
        handeleLocation()
    }
    
    private func setAsRoot() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.setRootViewController(vc: self)
    }
    
    private func initAdBanner() {
        adBannerView.adUnitID = AdMobUnitID.sheard.bannerID
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.delegate = adBannerView
        loadBanner()
    }
    
    private func loadBanner() {
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            adBannerView?.load(banner)
        }
    }
    
    private func handeleLocation() {
        locationManager = LocationManager()
        locationManager.trackDidChangeAuthorization { [weak self] staus in
            guard let self else { return }
            locationManager(locationManager, didChangeAuthorization: staus)
        }
    }
    
    private func handleTableView() {
        tableView.register(UINib(nibName: "PlaceTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
    
    private func handeleSearchView() {
        search.returnKeyType = .done
    }
    
    private func cleanSerach() {
        search.text = ""
        to = nil
        if let coordinate = locationManager.location?.coordinate {
            setMap(coordinate: coordinate)
        }
    }
    
    private func setMap(coordinate: CLLocationCoordinate2D) {
        LocationManager.getLocationName(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] address in
            self?.addPin(coordinate: coordinate, name: address)
        }
        let mapCamera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 2000, pitch: 0, heading: 0)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    private func goToNavigationAction() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let nav = sb.instantiateViewController(withIdentifier: "ScreenNav") as? ScreenNavigationViewController else { return }
        nav.modalTransitionStyle = .crossDissolve
        nav.modalPresentationStyle = .fullScreen
        nav.setInfo(destinationName: search.text ?? "", location: locationManager.location ?? .init(), to: to, transportType: transportType)
        show(nav, sender: nil)
    }
    
    private func addPin(coordinate: CLLocationCoordinate2D, name: String?) {
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = name
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(pin)
    }
    
    @objc private func closeSearch() {
        guard search.isFirstResponder else { return }
        cleanSerach()
        tableView.isHidden = true
        mapView.isHidden = false
        view.endEditing(true)
    }
    
    @objc func tapHandler(_ gRecognizer: UITapGestureRecognizer) {
        let location = gRecognizer.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        let toLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        LocationManager.getLocationName(from: toLocation) { [weak self] address in
            self?.search.text = address
            self?.addPin(coordinate: coordinate, name: address)
            self?.to = toLocation
        }
        view.endEditing(true)
    }
    
    @objc private func searchMap(textField: UISearchBar) {
        go.isEnabled = false
        
        let searchText = textField.text ?? ""
        
        guard !searchText.isEmpty else {
            tableView.isHidden = true
            mapView.isHidden = false
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = mapView.region
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self = self else { return }
            guard searchText == self.search.text else { return }
            guard let placemarks = response?.mapItems else { return }
            self.placeMarks = placemarks
            tableView.isHidden = false
            mapView.isHidden = true
            tableView.reloadData()
        }
    }
    
    private func locationManager(_ manager: LocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            guard let location = manager.location else { return }
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            mapView.setRegion(region, animated: true)
            setMap(coordinate: location.coordinate)
            locationManager.startUpdatingLocation()
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        default:
            let sb = UIStoryboard(name: "Main", bundle: nil)
            let locationApprovalViewController = sb.instantiateViewController(withIdentifier: "LocationApproval")
            locationApprovalViewController.modalTransitionStyle = .crossDissolve
            locationApprovalViewController.modalPresentationStyle = .fullScreen
            show(locationApprovalViewController, sender: nil)
        }
    }
    
    //-MARK: - @IBActions
    @IBAction func setTransportType(_ sender: UISegmentedControl) {
        self.transportType = sender.selectedSegmentIndex == 0 ? .walking : .automobile
    }
    
    @IBAction func goToNavigation(_ sender: UIButton) {
        goToNavigationAction()
    }
}

//-MARK: - Extensions
extension PickDestinationViewController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        cleanSerach()
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(searchMap(textField:)),
            object: searchBar)
        
        self.perform(
            #selector(searchMap(textField:)),
            with: searchBar,
            afterDelay: 0.2)
    }
}

extension PickDestinationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let placemark = placeMarks[indexPath.row]
        to = CLLocation(latitude: placemark.placemark.coordinate.latitude, longitude: placemark.placemark.coordinate.longitude)
        search.text = placemark.placemark.name
        setMap(coordinate: placemark.placemark.coordinate)
        tableView.isHidden = true
        mapView.isHidden = false
        view.endEditing(true)
    }
}

extension PickDestinationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return placeMarks?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? PlaceTableViewCell else { return UITableViewCell() }
        let placeMark = self.placeMarks[indexPath.row].placemark
        var text = ""
        if let city = placeMark.locality {
            text += "\(city) - "
        }
        if let name = placeMark.name {
            text += name
        }
        cell.place.text = text
        return cell
    }
}

extension PickDestinationViewController: MKMapViewDelegate { }
