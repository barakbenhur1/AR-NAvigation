//
//  MKStep+EXT.swift
//  ARGo
//
//  Created by ברק בן חור on 11/11/2023.
//

import MapKit

extension MKRoute.Step {
    func getRegionFor(index: Int) -> CLCircularRegion {
        let point = polyline.points()[index]
        let radius = raduis(point: point, index: index)
        let region = createRegion(point: point, radius: radius)
        return region
    }
    
    private func raduis(point: MKMapPoint, index: Int) -> CGFloat {
        if index < polyline.pointCount - 1 {
            let nextPoint = polyline.points()[index + 1]
            return point.distance(to: nextPoint)
        }
        else {
            return 4
        }
    }
    
    private func createRegion(point: MKMapPoint, radius: CGFloat) -> CLCircularRegion {
        let region = CLCircularRegion(center: point.coordinate, radius: radius, identifier: "\(point.coordinate)")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}
