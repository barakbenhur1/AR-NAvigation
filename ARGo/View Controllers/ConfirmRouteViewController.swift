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
    @IBOutlet weak var confrimView: UIView!
    @IBOutlet weak var back: UIButton!
    
    private let viewModel = ConfirmRouteViewModel()
    
    var location: CLLocation!
    var to: CLLocation!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initButtons()
        initBanners()
        setInfo()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBanners()
    }
    
    private func setInfo() {
        confirmRouteView.from.alpha = 0
        confirmRouteView.to.alpha = 0
        
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            confirmRouteView.from.alpha = 1
            confirmRouteView.to.alpha = 1
        }
        
        LocationManager.getLocationName(from: location ?? .init(), completion: { [weak self] name in
            guard let self else { return }
            confirmRouteView.from.text = name
        })
        
        LocationManager.getLocationName(from: to ?? .init(), completion: { [weak self] name in
            guard let self else { return }
            confirmRouteView.to.text = name
        })
    }
    
    private func initButtons() {
        let confrim = UIButton()
        confrim.setTitle(NSLocalizedString("Confirm", comment: ""), for: .normal)
        confrim.setTitleColor(.init(hexString: "#387F41"), for: .normal)
        confrim.backgroundColor = .init(hexString: "#323232")
        confrim.titleLabel?.font = .boldSystemFont(ofSize: 24)
        confrim.cornerRadius = 10
        confrim.addTo(view: confrimView)
        confrim.addTarget(self, action: #selector(confirm(sender:)), for: .touchUpInside)
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
    
    @objc func confirm(sender: UIButton) {
        sender.setTitleColor(.init(hexString: "#387F41").withAlphaComponent(0.6), for: .normal)
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) { [weak self] in
            sender.setTitleColor(.init(hexString: "#387F41").withAlphaComponent(0.9), for: .normal)
            guard let self else { return }
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                navigationController?.performSegue(withIdentifier: "NavContainer", sender: nil)
            }
        }
    }
    
    @IBAction func back(_ sender: UIButton) {
        dismiss(animated: true)
    }
}
