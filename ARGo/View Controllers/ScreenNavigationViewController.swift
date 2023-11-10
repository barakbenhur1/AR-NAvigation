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

class ScreenNavigationViewwModel: NSObject {
    func getAd(adView: @escaping ((GADInterstitialAd?) -> ())) {
        AdsManager.sheard.getAd(unitID: AdMobUnitID.sheard.endRouteinterstitialNoRewardID, adView: adView)
    }
}

class ScreenNavigationViewController: UINavigationController {
    private var transportType: MKDirectionsTransportType = .walking
    private var to: CLLocation?
    private var location: CLLocation!
    
    private let viewModel = ScreenNavigationViewwModel()
    
    var interstitial: GADInterstitialAd? {
        didSet {
            showAD()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getAd()
    }
    
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
    
    private func getAd() {
        viewModel.getAd { [weak self] adView in
            guard let self else { return }
            interstitial = adView
        }
    }
    
    private func showAD() {
        guard let interstitial else {
            return
        }
        interstitial.present(fromRootViewController: self)
    }
    
    func setInfo(location: CLLocation, to: CLLocation, transportType: MKDirectionsTransportType) {
        self.location = location
        self.transportType = transportType
        self.to = to
        performSegue(withIdentifier: "Confirm", sender: nil)
    }
}
