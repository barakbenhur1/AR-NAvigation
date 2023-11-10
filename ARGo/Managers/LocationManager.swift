//
//  swift
//  AR
//
//  Created by ברק בן חור on 05/11/2023.
//

import CoreLocation
import AppTrackingTransparency

typealias TrackAuthorization = (_ status: CLAuthorizationStatus) -> ()
typealias TrackLocation = (_ locations: [CLLocation]) -> ()
typealias TrackEnterRegion = (_ region: CLRegion) -> ()
typealias TrackExitRegionn = (_ region: CLRegion) -> ()
typealias TrackRegionState = (_ state: CLRegionState, _ region: CLRegion) -> ()

class LocationManager: CLLocationManager {
    private var didChangeAuthorization: TrackAuthorization?
    private var didUpdateLocations: TrackLocation?
    private var didEnterRegion: TrackEnterRegion?
    private var didExitRegion: TrackExitRegionn?
    private var didDetermineState: TrackRegionState?

    static var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }
    
    static var trackingAuthorizationStatusIsAllowed: Bool {
        return trackingAuthorizationStatus == .authorized || trackingAuthorizationStatus == .notDetermined
    }
    
    override init() {
        super.init()
        allowsBackgroundLocationUpdates = true
        desiredAccuracy = kCLLocationAccuracyBestForNavigation
        distanceFilter = kCLDistanceFilterNone
        headingFilter = kCLHeadingFilterNone
        pausesLocationUpdatesAutomatically = false
        delegate = self
        requestWhenInUseAuthorization()
        requestAlwaysAuthorization()
    }
    
    override func startUpdatingLocation() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestWhenInUseAuthorization()
            requestAlwaysAuthorization()
            return
        }
        super.startUpdatingLocation()
    }
    
    func trackDidChangeAuthorization(status: @escaping TrackAuthorization) {
        didChangeAuthorization = status
    }
    
    func trackDidUpdateLocations(locations: @escaping TrackLocation) {
        didUpdateLocations = locations
    }
    
    func trackDidEnterRegion(region: @escaping TrackEnterRegion) {
        didEnterRegion = region
    }
    
    func trackDidExitRegion(region: @escaping TrackExitRegionn) {
        didExitRegion = region
    }
    
    func trackDidDetermineState(state: @escaping TrackRegionState) {
        didDetermineState = state
    }
    
    static func requestTrackingAuthorization(success: @escaping () -> (), error: @escaping () -> ()) {
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
    
    static func getLocationName(from location: CLLocation, completion: @escaping (_ address: String?)-> Void) {
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
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        didChangeAuthorization?(status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        didUpdateLocations?(locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        didEnterRegion?(region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        didExitRegion?(region)
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        didDetermineState?(state, region)
    }
}
