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

class NavigationViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var topWrraperView: UIView!
    @IBOutlet weak var containerWrraperView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var arrivaTimelView: UIStackView!
    @IBOutlet weak var arrivalTime: UILabel!
    @IBOutlet weak var walkingAnimation: UIImageView!
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var rerouteLoader: UIStackView!
    @IBOutlet weak var errorLabel: UILabel! {
        didSet {
            errorLabel.isHidden = errorLabel.text == ""
        }
    }
    
    //MARK: - Properties
    private weak var navigationTabViewController: NavigationTabViewController!
    var destinationName: String?
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
        vc.transportType = transportType
    }
    
    //MARK: - Helpers
    private func showAD() {
        guard let interstitial = interstitial else {
            mainStackView.isUserInteractionEnabled = true
            return
        }
        interstitial.fullScreenContentDelegate = self
        interstitial.present(fromRootViewController: self)
    }
    
    private func initUI() {
        mainStackView.sendSubviewToBack(containerWrraperView)
        mainStackView.isUserInteractionEnabled = false
        errorLabel.text = ""
        walkingAnimation.setGifImage(try! UIImage(gifName: transportType == .walking ? "walking" : "car"))
        place.text = self.destinationName
        muteButton.isSelected = UserDefaults.standard.bool(forKey: "mute")
        muteButton.alpha = muteButton.isSelected ? 0.5 : 1
    }
    
    private func setUI(directions: MKDirections, routes: [MKRoute]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let route = routes?.first else { return }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let distance = "\(formatter.string(from: NSNumber(value: Int(route.distance)))!)\(NSLocalizedString("m", comment: ""))"
            let attr = NSMutableAttributedString(string: distance)
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: self.distance.font.pointSize), range: NSRange(location: distance.count - 1, length: 1))
            attr.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: distance.count - 1, length: 1))
            self.distance.attributedText = attr
            
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.walkingAnimation.alpha = 1
                self?.distance.alpha = 1
            }
            
            directions.calculateETA { [weak self] response, error in
                guard let timeInterval = response?.expectedTravelTime else { return }
                let tmv = timeval(tv_sec: Int(timeInterval), tv_usec: 0)
                let time = Duration(tmv).formatted(.time(pattern: .hourMinute))
                self?.arrivalTime.text = "\(NSLocalizedString("Arrival Time", comment: "")): \(time)"
                
                UIView.animate(withDuration: 0.3) { [weak self] in
                    self?.arrivaTimelView.alpha = 1
                }
            }
        }
    }
    
    //MARK: - @IBActions
    @IBAction func didMute(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        sender.alpha = sender.isSelected ? 0.5 : 1
        UserDefaults.standard.set(sender.isSelected, forKey: "mute")
        
        guard !sender.isSelected else { return }
        navigationTabViewController.voice()
    }
    
    @IBAction func didClickOnBack(_ sender: UIButton) {
        navigationTabViewController.closeResorces()
        dismiss(animated: true)
    }
}

//MARK: - Extensions
extension NavigationViewController: GADFullScreenContentDelegate {
    /// Tells the delegate that the ad failed to present full screen content.
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad did fail to present full screen content.")
        mainStackView.isUserInteractionEnabled = true
    }
    
    /// Tells the delegate that the ad will present full screen content.
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad will present full screen content.")
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2) { [weak self] in
            self?.mainStackView.isUserInteractionEnabled = true
        }
    }
    
    /// Tells the delegate that the ad dismissed full screen content.
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
    }
}

extension NavigationViewController: TabBarViewControllerDelegate {
    func success(directions: MKDirections, routes: [MKRoute]?) {
        errorLabel.text = ""
        setUI(directions: directions, routes: routes)
        rerouteLoader.superview?.alpha = 0
    }
    
    func error(error: Error) {
        errorLabel.text = error.localizedDescription
        rerouteLoader.superview?.alpha = 0
    }
    
    func reroute() {
        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.rerouteLoader.superview?.alpha = 1
        }
    }
    
    func isMute() -> Bool {
        return UserDefaults.standard.bool(forKey: "mute")
    }
}
