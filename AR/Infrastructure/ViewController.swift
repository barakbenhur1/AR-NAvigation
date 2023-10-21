//
//  ViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
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
        requestLocation()
        handeleSearchView()
        handleTableView()
    }
    
    func requestLocation() {
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
        getLocationName(from: CLLocation(coordinate: coordinate, altitude: 0)) { [weak self] address in
            self?.addPin(coordinate: coordinate, name: address)
        }
        let mapCamera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 2000, pitch: 0, heading: 0)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    private func goToNavigationAction() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let nav = sb.instantiateViewController(withIdentifier: "Nav") as? NavigationViewController else { return }
        self.nav = nav
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
    
    @objc func tapHandler(_ gRecognizer: UITapGestureRecognizer) {
        let location = gRecognizer.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        let toLocation = CLLocation(coordinate: coordinate, altitude: 0)
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
        if let city = placeMark.locality, let name = placeMark.name {
            cell.place.text = "\(city) - \(name)"
        }
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

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
    }
}
