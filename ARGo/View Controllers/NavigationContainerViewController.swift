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

class NavigationContainerViewController: UIViewController {
    //MARK: - @IBOutlets
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var topWrraperView: UIView!
    @IBOutlet weak var containerWrraperView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoViewWrapper: UIView!
    @IBOutlet weak var infoWrapperViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var arrivaTimelView: UIStackView!
    @IBOutlet weak var arrivalTime: UILabel!
    @IBOutlet weak var placeImage: UIImageView!
    @IBOutlet weak var walkingAnimation: UIImageView!
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var errorLabel: UILabel! {
        didSet {
            errorLabel.isHidden = errorLabel.text == ""
        }
    }
    
    //MARK: - Properties
    private weak var navigationTabViewController: NavigationTabViewController!
    private var isValid: Bool!
    var transportType: MKDirectionsTransportType = .walking
    var location: CLLocation?
    var to: CLLocation?
    
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
    
    private func initUI() {
        mainStackView.sendSubviewToBack(containerWrraperView)
        errorLabel.text = ""
        walkingAnimation.setGifImage(try! UIImage(gifName: transportType == .walking ? "walking" : "car"))
        muteButton.isSelected = UserDefaults.standard.bool(forKey: "mute")
        muteButton.setImage(UIImage(systemName: "speaker.fill"), for: .normal)
        muteButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .selected)
        muteButton.alpha = muteButton.isSelected ? 0.5 : 1
        
        LocationManager.getLocationName(from: to ?? .init(), completion: { [weak self] name in
            guard let self else { return }
            place.text = name
        })
        
        isValid = false
    }
    
    private func setUI(directions: MKDirections, routes: [MKRoute]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let route = routes?.first else { return }
            guard isValid || route.steps.count >= 4 || route.distance >= 100 else {
                setUiForUnValidRoute()
                return
            }
            isValid = true
            setUiForValidRoute(directions: directions, route: route)
        }
    }
    
    private func setUiForValidRoute(directions: MKDirections, route: MKRoute) {
        navigationTabViewController.valid()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let distance = "\(formatter.string(from: NSNumber(value: Int(route.distance)))!)\(NSLocalizedString("m", comment: ""))"
        let attr = NSMutableAttributedString(string: distance)
        attr.addAttribute(.font, value: UIFont.systemFont(ofSize: self.distance?.font.pointSize ?? 0), range: NSRange(location: distance.count - 1, length: 1))
        attr.addAttribute(.foregroundColor, value: UIColor.systemGray, range: NSRange(location: distance.count - 1, length: 1))
        self.distance?.attributedText = attr
        
        directions.calculateETA { [weak self] response, error in
            guard let self, let timeInterval = response?.expectedTravelTime else { return }
            let tmv = timeval(tv_sec: Int(timeInterval), tv_usec: 0)
            let time = Duration(tmv).formatted(.time(pattern: tmv.tv_sec < 60 ? .hourMinuteSecond : .hourMinute))
            arrivalTime.text = "\(NSLocalizedString("Arrival Time", comment: "")): \(time)"
            
            navigationTabViewController.listButton.isHidden = false
            infoWrapperViewTopConstraint.constant = 0
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.infoViewWrapper.alpha = 1
                self?.view.layoutIfNeeded()
            }
            
            navigationTabViewController.showButtons()
        }
    }
    
    private func setUiForUnValidRoute() {
        navigationTabViewController.unvalid()
        let label = UILabel()
        label.text = "\(NSLocalizedString("destination", comment: "")) \(NSLocalizedString("is to close", comment: ""))"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20)
        
        label.addTo(view: infoView)
        infoView?.alpha = 1
        muteButton?.isHidden = true
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
    func success(directions: MKDirections, routes: [MKRoute]?) {
        errorLabel.text = ""
        setUI(directions: directions, routes: routes)
    }
    
    func error(error: Error) {
        errorLabel.text = error.localizedDescription
    }
    
    func isMute() -> Bool {
        return UserDefaults.standard.bool(forKey: "mute")
    }
}
