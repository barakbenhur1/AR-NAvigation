//
//  swift
//  AR
//
//  Created by ברק בן חור on 05/11/2023.
//

import CoreLocation
import AppTrackingTransparency
import AdSupport
import UserMessagingPlatform
import UIKit

typealias TrackAuthorization = (_ status: CLAuthorizationStatus) -> ()
typealias TrackLocation = (_ locations: [CLLocation]) -> ()
typealias TrackEnterRegion = (_ region: CLRegion) -> ()
typealias TrackExitRegionn = (_ region: CLRegion) -> ()
typealias TrackRegionState = (_ state: CLRegionState, _ region: CLRegion) -> ()
typealias TrackHeading = (_ heading: CLHeading) -> ()

class LocationManager: CLLocationManager {
    private var didChangeAuthorization: TrackAuthorization?
    private var didUpdateLocations: TrackLocation?
    private var didEnterRegion: TrackEnterRegion?
    private var didExitRegion: TrackExitRegionn?
    private var didDetermineState: TrackRegionState?
    private var didUpdateHeading: TrackHeading?
    
    private let responedQueue = DispatchQueue.main
    
    static var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }
    
    static var trackingAuthorizationStatusIsAllowed: Bool {
        return !SubscriptionService.shared.removedAdsPurchesd && (trackingAuthorizationStatus == .authorized || trackingAuthorizationStatus == .notDetermined)
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
    
    func trackHeading(heding: @escaping TrackHeading) {
        didUpdateHeading = heding
    }
    
    static func askAdsPermission(view: UIViewController, success: @escaping () -> (), error: @escaping (Error) -> ()) {
        // Create a UMPRequestParameters object.
        let parameters = UMPRequestParameters()
        // Set tag for under age of consent. false means users are not under age
        // of consent.
        let debugSettings = UMPDebugSettings()
        parameters.debugSettings = debugSettings
        
        parameters.tagForUnderAgeOfConsent = false
        
        // Request an update for the consent information.
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { requestConsentError in
            if let consentError = requestConsentError {
                // Consent gathering failed.
                return print("Error: \(consentError.localizedDescription)")
            }
            
            UMPConsentForm.loadAndPresentIfRequired(from: view) { loadAndPresentError in
                if let consentError = loadAndPresentError {
                    // Consent gathering failed.
                    error(consentError)
                }
                
                // Consent has been gathered.
                if UMPConsentInformation.sharedInstance.canRequestAds {
                    success()
                }
            }
        }
        
        // Check if you can initialize the Google Mobile Ads SDK in parallel
        // while checking for new consent information. Consent obtained in
        // the previous session can be used to request ads.
        if UMPConsentInformation.sharedInstance.canRequestAds {
            success()
        }
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
        responedQueue.async { [weak self] in
            guard let self else { return }
            didChangeAuthorization?(status)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        responedQueue.async { [weak self] in
            guard let self else { return }
            didUpdateLocations?(locations)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        responedQueue.async { [weak self] in
            guard let self else { return }
            didEnterRegion?(region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        responedQueue.async { [weak self] in
            guard let self else { return }
            didExitRegion?(region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        responedQueue.async { [weak self] in
            guard let self else { return }
            didDetermineState?(state, region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        responedQueue.async { [weak self] in
            guard let self else { return }
            didUpdateHeading?(newHeading)
        }
    }
}
