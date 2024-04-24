//
//  RegionManager.swift
//  ARGo
//
//  Created by ברק בן חור on 11/11/2023.
//

import CoreLocation
import MapKit

enum RegionState {
    case enter, exit, determine(region: CLRegion, state: CLRegionState)
}
typealias RegionTrack = (_ index: Int, _ count: Int, _ state: RegionState) -> ()
typealias UpdateLocation = (_ location: CLLocation) -> ()

class RegionManager: NSObject {
    private var locationManager: LocationManager!
    private var monitoredRegions: [[CLRegion]]!
    
    private var didTrackRegion: RegionTrack?
    private var didUpdateLocations: UpdateLocation?
    
    private lazy var currentRegion: (_ region: CLRegion, _ monitoredRegions: [[CLRegion]]) -> (index: Int, count: Int)? = { region, monitoredRegions in
        guard let region = region as? CLCircularRegion else { return nil }
        for i in 0..<monitoredRegions.count {
            guard let index = monitoredRegions[i].firstIndex(of: region) else { continue }
            return (index, monitoredRegions[i].count)
        }
        return nil
    }
    
    var location: CLLocation? {
        return locationManager.location
    }
    
    override init() {
        locationManager = LocationManager()
        monitoredRegions = []
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingHeading()
    }
    
    func stopMonitoringAllRegions() {
        monitoredRegions = []
        guard let monitoredRegions =  locationManager?.monitoredRegions else { return }
        for region in monitoredRegions {
            locationManager?.stopMonitoring(for: region)
        }
    }
    
    func startMonitoringRegions(with routes: [MKRoute]?) {
        guard let routes else { return }
        stopMonitoringAllRegions()
        guard let steps = routes.first?.steps else { return }
        for step in steps {
            monitoredRegions.append([])
            for i in 0..<step.polyline.pointCount {
                let region = step.createRegion(coordinate: step.polyline.points()[i].coordinate, radius: 2)
                locationManager.startMonitoring(for: region)
                monitoredRegions[monitoredRegions.count - 1].append(region)
            }
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
        locationManager.trackDidUpdateLocations { [weak self] locations in
            guard let self else { return }
            locationManager(locationManager, didUpdateLocations: locations)
        }
    }
    
    func trackRegion(track: @escaping RegionTrack) {
        didTrackRegion = track
    }
    
    func didUpdateLocations(track: @escaping UpdateLocation) {
        didUpdateLocations = track
    }
    
    func trackHeading(heding: @escaping TrackHeading) {
        locationManager.trackHeading(heding: heding)
    }
    
    private func locationManager(_ manager: LocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        didUpdateLocations?(location)
    }
    
    private func locationManager(_ manager: LocationManager, didEnterRegion region: CLRegion) {
        guard let current = getMonitoredRegionIndex(region: region) else { return }
        didTrackRegion?(current, monitoredRegions[current].count, .enter)
    }
    
    private func locationManager(_ manager: LocationManager, didExitRegion region: CLRegion) {
        guard let current = getMonitoredRegionIndex(region: region) else { return }
        didTrackRegion?(current, monitoredRegions[current].count, .exit)
    }
    
    private func locationManager(_ manager: LocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let current = getMonitoredRegionIndex(region: region) else { return }
        didTrackRegion?(current, monitoredRegions[current].count, .determine(region: region, state: state))
    }
    
    private func getMonitoredRegionIndex(region: CLRegion) -> Int? {
        for i in 0..<monitoredRegions.count {
            guard monitoredRegions[i].firstIndex(of: region) != nil else { continue }
            return i
        }
        
        return nil
    }
}
