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
import AppTrackingTransparency

class PickDestinationViewModel: NSObject {
    private var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }
    
    private var trackingAuthorizationStatusIsAllowed: Bool {
        return trackingAuthorizationStatus == .authorized || trackingAuthorizationStatus == .notDetermined
    }
    
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        guard trackingAuthorizationStatusIsAllowed else {
            banner(nil)
            return
        }
        banner(GADRequest())
    }
    
    func getAd(adView: @escaping ((GADInterstitialAd?) -> ())) {
        guard trackingAuthorizationStatusIsAllowed else {
            adView(nil)
            return
        }
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: ADMobIDProvider.sheard.interstitialNoRewardID, request: request, completionHandler: { ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                adView(nil)
                return
            }
            adView(ad)
        })
    }
    
    func requestTrackingAuthorization(success: @escaping () -> (), error: @escaping () -> ()) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .notDetermined:
                        success()
                    case .denied, .restricted:
                        error()
                    @unknown default:
                        error()
                    }
                }
            }
        }
    }
}

class PickDestinationViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var adBannerView: GADBannerView!
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
        askPermissions()
        handeleSearchView()
        handleTableView()
        handeleLocation()
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
    private func askPermissions() {
        viewModel.requestTrackingAuthorization { [weak self] in
            guard let self else { return }
            initAdBanner()
        } error: { [weak self] in
            guard let self else { return }
            gotoAppPrivacySettings()
        }
    }
    
    private func initAdBanner() {
        adBannerView.adUnitID = ADMobIDProvider.sheard.bannerID
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.delegate = self
        loadBanner()
    }
    
    private func loadBanner() {
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            guard let banner else { return }
            adBannerView?.load(banner)
        }
    }
    
    private func handeleLocation() {
        locationManager = LocationManager()
        locationManager.startUpdatingLocation()
        locationManager.trackDidChangeAuthorization { [weak self] staus in
            guard let self else { return }
            locationManager(locationManager, didChangeAuthorization: staus)
        }
    }
    
    private func gotoAppPrivacySettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            assertionFailure("Not able to open App privacy settings")
            return
        }
        
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
        getLocationName(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] address in
            self?.addPin(coordinate: coordinate, name: address)
        }
        let mapCamera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 2000, pitch: 0, heading: 0)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    private func goToNavigationAction() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let nav = sb.instantiateViewController(withIdentifier: "Nav") as? NavigationContainerViewController else { return }
        
        viewModel.getAd { adView in
            nav.interstitial = adView
        }
        
        nav.modalTransitionStyle = .crossDissolve
        nav.modalPresentationStyle = .fullScreen
        nav.transportType = transportType
        nav.to = to
        nav.location = locationManager.location
        nav.destinationName = search.text
        show(nav, sender: nil)
    }
    
    private func addPin(coordinate: CLLocationCoordinate2D, name: String?) {
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = name
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(pin)
    }
    
    private func getLocationName(from location: CLLocation, completion: @escaping (_ address: String?)-> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            guard let placemarks = placemarks,
                  let address = placemarks.first?.name else {
                completion(nil)
                return
            }
            completion(address)
        }
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
        getLocationName(from: toLocation) { [weak self] address in
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
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        default:
            break
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

extension PickDestinationViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("bannerViewDidReceiveAd")
        bannerView.isHidden = false
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("bannerView:didFailToReceiveAdWithError: \(error.localizedDescription)")
    }
    
    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        print("bannerViewDidRecordImpression")
    }
    
    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        print("bannerViewWillPresentScreen")
    }
    
    func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
        print("bannerViewWillDIsmissScreen")
    }
    
    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        print("bannerViewDidDismissScreen")
    }
}
