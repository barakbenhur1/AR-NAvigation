//
//  ScreenNavigationViewController.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import UIKit
import MapKit
import CoreLocation
import GoogleMobileAds

class ScreenNavigationViewController: UINavigationController {
    private var transportType: MKDirectionsTransportType = .walking
    private var to: CLLocation?
    private var location: CLLocation!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let confirm = segue.destination as? ConfirmRouteViewController {
            confirm.location = location
            confirm.to = to
        }
        else if let navigation = segue.destination as? NavigationContainerViewController {
            navigation.to = to
            navigation.transportType = transportType
            navigation.location = location
            navigation.to = to
            navigation.modalTransitionStyle = .crossDissolve
            navigation.modalPresentationStyle = .fullScreen
        }
    }

    func setInfo(location: CLLocation, to: CLLocation, transportType: MKDirectionsTransportType) {
        self.location = location
        self.transportType = transportType
        self.to = to
        performSegue(withIdentifier: "Confirm", sender: nil)
    }
}
