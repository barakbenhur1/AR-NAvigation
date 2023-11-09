//
//  MKPolyline+EXT.swift
//  ARGo
//
//  Created by ברק בן חור on 09/11/2023.
//

import UIKit
import MapKit

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        let pointCount = pointCount
        let points = points()
        
        for i in 0..<pointCount {
            let coordinate = points[i].coordinate
            coordinates.append(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        
        return coordinates
    }
}
