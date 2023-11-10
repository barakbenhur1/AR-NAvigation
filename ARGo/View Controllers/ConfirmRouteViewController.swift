//
//  ConfirmRouteViewController.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import UIKit
import MapKit
import CoreLocation
import GoogleMobileAds

class ConfirmRouteViewModel: NSObject {
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        AdsManager.sheard.getBanner(banner: banner)
    }
}

class ConfirmRouteViewController: UIViewController {
    @IBOutlet weak var adBannerView: CustomGADBannerView!
    @IBOutlet weak var adBannerView2: CustomGADBannerView!
    @IBOutlet weak var confirmRouteViewWrraper: UIView!
    @IBOutlet weak var confirmRouteView: ConfirmRouteView!
    @IBOutlet weak var ar360: UIView!
    @IBOutlet weak var confrim: UIButton!
    @IBOutlet weak var back: UIButton!
    
    private let viewModel = ConfirmRouteViewModel()
    
    var location: CLLocation!
    var destinationName: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initButtons()
        initBanners()
        LocationManager.getLocationName(from: location ?? .init(), completion: { [weak self] name in
            guard let self else { return }
            confirmRouteView.from.text = name
            confirmRouteView.to.text = destinationName
            
            UIView.animate(withDuration: 1) { [weak self] in
                guard let self else { return }
                confirmRouteViewWrraper.alpha = 1
                ar360.alpha = 1
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBanners()
    }
    
    private func initButtons() {
        confrim.titleLabel?.font = .boldSystemFont(ofSize: 30)
        confrim.setTitle(NSLocalizedString("Confirm", comment: ""), for: .normal)
    }
    
    private func initBanners() {
        guard LocationManager.trackingAuthorizationStatusIsAllowed else { return }
        adBannerView.adUnitID = AdMobUnitID.sheard.banner1ID
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.delegate = adBannerView
        
        adBannerView2.adUnitID = AdMobUnitID.sheard.banner2ID
        adBannerView2.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView2.frame.height))
        adBannerView2.rootViewController = self
        adBannerView2.delegate = adBannerView2
        
        loadBanners()
    }
    
    private func loadBanners() {
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            adBannerView.load(banner)
        }
        
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            adBannerView2.load(banner)
        }
    }
    
    @IBAction func confirm(_ sender: UIButton) {
        navigationController?.performSegue(withIdentifier: "NavContainer", sender: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        dismiss(animated: true)
    }
}
