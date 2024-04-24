//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import CoreLocation
import MapKit
import SwiftyGif
import GoogleMobileAds

class NavigationContainerViewModel: NSObject {    
    func getAd(adView: @escaping (GADInterstitialAd?) -> ()) {
        AdsManager.sheard.getAd(unitID: AdMobUnitID.sheard.interstitialNoRewardID, adView: adView)
    }
    
    func notifyWhenAdDismissed(dismiss: @escaping () -> ()) {
        AdsManager.sheard.adDidDismissFullScreenContent {
            dismiss()
        }
    }
}

class NavigationContainerViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var topWrraperView: UIView!
    @IBOutlet weak var containerWrraperView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoViewWrapper: UIView!
    @IBOutlet weak var arrivaTimelView: UIStackView!
    @IBOutlet weak var arrivalTime: UILabel!
    @IBOutlet weak var placeImage: UIImageView!
    @IBOutlet weak var walkingAnimation: UIImageView!
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var blur: UIVisualEffectView!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var clockImage: UIImageView! {
        didSet {
            guard let gif = try? UIImage(gifName: "clock") else { return }
            clockImage.setGifImage(gif)
        }
    }
    @IBOutlet weak var errorLabel: UILabel! {
        didSet {
            errorLabel.isHidden = errorLabel.text == ""
        }
    }
    @IBOutlet weak var muteButton: UIButton! {
        didSet {
            muteButton.isSelected = UserDefaults.standard.bool(forKey: "mute")
            muteButton.setImage(UIImage(systemName: "speaker.fill"), for: .normal)
            muteButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .selected)
            muteButton.alpha = muteButton.isSelected ? 0.5 : 1
        }
    }
    
    //MARK: - Properties
    private weak var navigationTabViewController: NavigationTabViewController!
    private var isValid: Bool!
    private let viewModel = NavigationContainerViewModel()
    var transportType: MKDirectionsTransportType = .walking
    var location: CLLocation?
    var to: CLLocation?
    
    var interstitial: GADInterstitialAd? {
        didSet {
            showAD()
        }
    }
    
    //MARK: - Life cycle
    override func viewDidLoad() {
        initUI()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let vc = segue.destination as? NavigationTabViewController else { return }
        navigationTabViewController = vc
        vc.delegate = self
        vc.to = to
        vc.start = location
        vc.transportType = transportType
    }
    
    //MARK: - Helpers
    
    private func initUI() {
        mainStackView.sendSubviewToBack(containerWrraperView)
        errorLabel.text = ""
        walkingAnimation.setGifImage(try! UIImage(gifName: transportType == .walking ? "walking" : "car"))
        
        LocationManager.getLocationName(from: to ?? .init(), completion: { [weak self] name in
            guard let self else { return }
            place.text = name
        })
        
        navigationTabViewController.startResorces()
    }
    
    private func setUI(directions: MKDirections, routes: [MKRoute]?, isFirstTime: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let route = routes?.first else { return }
            guard (isValid != nil && isValid) || route.steps.count >= 4 || route.distance >= 100 else {
                guard isValid == nil else { return }
                isValid = false
                setUiForUnValidRoute(isFirstTime: isFirstTime)
                return
            }
            isValid = true
            setUiForValidRoute(directions: directions, route: route, isFirstTime: isFirstTime)
        }
    }
    
    private func setUiForValidRoute(directions: MKDirections, route: MKRoute, isFirstTime: Bool) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let distance = "\(formatter.string(from: NSNumber(value: Int(route.distance)))!)\(NSLocalizedString("m", comment: ""))"
        let attr = NSMutableAttributedString(string: distance)
        attr.addAttribute(.font, value: UIFont.systemFont(ofSize: self.distance?.font.pointSize ?? 0), range: NSRange(location: distance.count - 1, length: 1))
        attr.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: distance.count - 1, length: 1))
        self.distance?.attributedText = attr
        
        directions.calculateETA { [weak self] response, error in
            guard let self else { return }
            if let timeInterval = response?.expectedTravelTime {
                let tmv = timeval(tv_sec: Int(timeInterval), tv_usec: 0)
                let time = Duration(tmv).formatted(.time(pattern: tmv.tv_sec < 60 ? .hourMinuteSecond : .hourMinute))
                arrivalTime.text = "\(NSLocalizedString("Arrival Time", comment: "")): \(time)"
            }
            guard isFirstTime else { return }
            getAd { [weak self] in
                guard let self else { return }
                showInfoView()
                navigationTabViewController.valid()
            }
        }
    }
    
    private func setUiForUnValidRoute(isFirstTime: Bool) {
        let label = UILabel()
        label.text = "\(NSLocalizedString("destination", comment: "")) \(NSLocalizedString("is to close", comment: ""))"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 26, weight: .light)
        label.numberOfLines = 2
        infoView.alpha = 0
        label.addTo(view: infoViewWrapper, leading: 100, trailing: -100)
        muteButton?.isHidden = true
        guard isFirstTime else { return }
        getAd { [weak self] in
            guard let self else { return }
            showInfoView()
            navigationTabViewController.unvalid()
        }
    }
    
    private func getAd(complition: @escaping () -> ()) {
        viewModel.notifyWhenAdDismissed(dismiss: complition)
        viewModel.getAd { [weak self] adView in
            guard let self else { return }
            interstitial = adView
        }
    }
    
    private func showAD() {
        guard let interstitial else { return }
        interstitial.present(fromRootViewController: self)
    }
    
    private func showInfoView() {
        infoViewWrapper.alpha = 1
    }
    
    //MARK: - @IBActions
    @IBAction func didMute(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = sender.isSelected ? 0.5 : 1
        UserDefaults.standard.set(sender.isSelected, forKey: "mute")
        navigationTabViewController.voice(enabled: !sender.isSelected)
    }
    
    @IBAction func didClickOnBack(_ sender: UIButton) {
        navigationTabViewController.closeResorces()
        dismiss(animated: true)
    }
}

//MARK: - Extensions
extension NavigationContainerViewController: TabBarViewControllerDelegate {
    func success(directions: MKDirections, routes: [MKRoute]?, isFirstTime: Bool) {
        errorLabel.text = ""
        setUI(directions: directions, routes: routes, isFirstTime: isFirstTime)
    }
    
    func error(error: Error, isFirstTime: Bool) {
        errorLabel.text = error.localizedDescription
        guard isFirstTime else { return }
        muteButton.isHidden = true
        navigationTabViewController.error()
    }
    
    func isMute() -> Bool {
        return UserDefaults.standard.bool(forKey: "mute")
    }
}
