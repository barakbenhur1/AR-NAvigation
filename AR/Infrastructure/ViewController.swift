//
//  ViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import MapKit
import CoreLocation
import GoogleMobileAds

class ViewController: UIViewController {
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
    
    private weak var nav: NavigationViewController!
    
    private var transportType: MKDirectionsTransportType = .walking
    
    private var locationManager: CLLocationManager!
    
    private var circleCenter: MKCircle?
    
    private var to: CLLocation! {
        didSet {
            go.isEnabled = to != nil
        }
    }
    
    private var placeMarks: [MKMapItem]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initAdBanner()
        requestLocation()
        handeleSearchView()
        handleTableView()
    }
    
    private func initAdBanner() {
        let id = "ca-app-pub-6040820758186818/6333220506"
        adBannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716" // replace with id when realsing to store
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.load(GADRequest())
        adBannerView.delegate = self
    }
    
    private func requestLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
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
    
    @objc private func closeSearch() {
        guard search.isFirstResponder else { return }
        cleanSerach()
        tableView.isHidden = true
        mapView.isHidden = false
        view.endEditing(true)
    }
    
    @IBAction func setTransportType(_ sender: UISegmentedControl) {
        self.transportType = sender.selectedSegmentIndex == 0 ? .walking : .automobile
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
        guard let nav = sb.instantiateViewController(withIdentifier: "Nav") as? NavigationViewController else { return }
        self.nav = nav
        
        getAd { adView in
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
    
    private func getAd(adView: @escaping ((GADInterstitialAd?) -> ())) {
        let request = GADRequest()
        //        let id = "ca-app-pub-6040820758186818/6333220506"
        let testID = "ca-app-pub-3940256099942544/4411468910"
        
        //  replace testID with id when realsing to store
        GADInterstitialAd.load(withAdUnitID: testID,
                               request: request,
                               completionHandler: { ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            adView(ad)
        }
        )
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
    
    @IBAction func goToNavigation(_ sender: UIButton) {
        goToNavigationAction()
    }
}

extension ViewController: UISearchBarDelegate {
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

extension ViewController: UITableViewDelegate {
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

extension ViewController: UITableViewDataSource {
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

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
}

extension ViewController: MKMapViewDelegate { }

extension ViewController: GADBannerViewDelegate {
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
