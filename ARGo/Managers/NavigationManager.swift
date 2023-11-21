//
//  NavigationManager.swift
//  ARGo
//
//  Created by Barak Ben Hur on 20/11/2023.
//

import MapKit

class NavigationManager: NSObject {
    static func calculateNavigtionInfo(to: CLLocationCoordinate2D, transportType: MKDirectionsTransportType, success: @escaping (_ directions: MKDirections, _ routes: [MKRoute]?) -> (), error: @escaping (_ error: Error) -> ()){
        let destinationPlacemark = MKPlacemark(coordinate: to)
        
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        // Create a request for directions for walking
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destinationItem
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        // Get directions using MKDirections
        let directions = MKDirections(request: request)
        
        directions.calculate { response, err in
            if let err = err {
                error(err)
            }
            else {
                success(directions, response?.routes)
            }
        }
    }
}
