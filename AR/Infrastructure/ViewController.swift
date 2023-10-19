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
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
        }
    }
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
        }
    }
    
    @IBOutlet weak var search: UISearchBar! {
        didSet {
            search.delegate = self
        }
    }
    
    @IBOutlet weak var go: UIButton!
    
    private weak var nav: NavigationViewController!
    
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
    
    private func setMap(location: CLLocationCoordinate2D) {
        if let circleCenter = circleCenter {
            mapView.removeOverlay(circleCenter)
        }
        
        circleCenter = MKCircle(center: location, radius: 20)
        mapView.addOverlay(circleCenter!)
        
        let mapCamera = MKMapCamera(lookingAtCenter: location, fromDistance: 2000, pitch: 0, heading: 0)
        mapView.setCamera(mapCamera, animated: true)
    }
    
    private func goToNavigationAction() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let nav = sb.instantiateViewController(withIdentifier: "Nav") as? NavigationViewController else { return }
        self.nav = nav
        nav.modalTransitionStyle = .crossDissolve
        nav.modalPresentationStyle = .fullScreen
        nav.to = to
        nav.location = locationManager.location
        show(nav, sender: nil)
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
        searchBar.text = ""
        to = nil
        if let location = locationManager.location?.coordinate {
            setMap(location: location)
        }
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchMap(textField: searchBar)
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let placemark = placeMarks[indexPath.row]
        to = CLLocation(latitude: placemark.placemark.coordinate.latitude, longitude: placemark.placemark.coordinate.longitude)
        search.text = placemark.placemark.name
        setMap(location: placemark.placemark.coordinate)
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
        if let name = self.placeMarks[indexPath.row].placemark.name {
            cell.place.text = " \(name)"
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
            setMap(location: location.coordinate)
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let circleRenderer = MKCircleRenderer(overlay: overlay)
        circleRenderer.strokeColor = .white.withAlphaComponent(0.8)
        circleRenderer.fillColor = .systemRed.withAlphaComponent(0.8)
        circleRenderer.lineWidth = 6
        return circleRenderer
    }
}
