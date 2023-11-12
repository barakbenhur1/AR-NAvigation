//
//  AdsManager.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import GoogleMobileAds

internal class AdsManager: NSObject {
    static let sheard = AdsManager()
    private var adDidDismissFullScreenContent: (() -> ())?
    
    private override init() {}
    
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        guard LocationManager.trackingAuthorizationStatusIsAllowed else {
            banner(nil)
            return
        }
        banner(GADRequest())
    }
    
    func getAd(unitID: String, adView: @escaping ((GADInterstitialAd?) -> ())) {
        guard LocationManager.trackingAuthorizationStatusIsAllowed else {
            adView(nil)
            adDidDismissFullScreenContent?()
            return
        }
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: unitID, request: request, completionHandler: { [weak self] ad, error in
            guard let self else { return }
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                adView(nil)
                return
            }
            ad?.fullScreenContentDelegate = self
            adView(ad)
        })
    }
    
    func adDidDismissFullScreenContent(complition: @escaping () -> ()) {
        adDidDismissFullScreenContent = complition
    }
}

extension AdsManager: GADFullScreenContentDelegate {
    /// Tells the delegate that the ad will present full screen content.
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }
    
    /// Tells the delegate that the ad failed to present full screen content.
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad did fail to present full screen content.")
        adDidDismissFullScreenContent?()
    }
    
    /// Tells the delegate that the ad dismissed full screen content.
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        adDidDismissFullScreenContent?()
    }
}
