//
//  CLLocation+EXT.swift
//  AR
//
//  Created by ברק בן חור on 22/10/2023.
//

import UIKit
import CoreLocation
import MapKit

extension CLLocation {
    private func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    private func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
    func getBearingBetweenTwoPoints1(point1 : CLLocation, point2 : CLLocation) -> Double {
        let lat1 = degreesToRadians(degrees: point1.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: point1.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: point2.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: point2.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }
    
    func isInRange(coordinates: [CLLocationCoordinate2D], distanceInMeters: Double) -> Bool {
        for count in 0..<coordinates.count - 1 {
            let distance = checkSegmentDistance(coordinates: coordinates, index: count)
            if distance <= distanceInMeters {
                return true
            }
        }
        
        return false
    }
    
    private func checkSegmentDistance(coordinates: [CLLocationCoordinate2D], index: Int) -> CGFloat {
        let startCoordinate = coordinates[index]
        let endCoordinate = coordinates[index + 1]
        let segment = MKPolyline(coordinates: [startCoordinate, endCoordinate], count: 2)
        
        let segmentLocation = CLLocation(latitude: segment.coordinate.latitude, longitude: segment.coordinate.longitude)
        let distance = segmentLocation.distance(from: self)
        
        return distance
    }
}
