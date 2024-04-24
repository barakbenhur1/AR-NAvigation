//
//  SettingsViewController.swift
//  ARGo
//
//  Created by ברק בן חור on 13/11/2023.
//

import UIKit
import AVFAudio
import GoogleMobileAds

typealias Option = (text: String, image: String)

internal class SettingsViewModel {
    private let synthesizer: AVSpeechSynthesizer!
    
    init() {
        synthesizer = AVSpeechSynthesizer()
    }
    
    func getBanner(banner: @escaping (GADRequest?) -> ()) {
        AdsManager.sheard.getBanner(banner: banner)
    }
    
    func voiceText(voiceID: String) {
        let utterance = AVSpeechUtterance(string: NSLocalizedString("hello", comment: ""))
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID)
        synthesizer.speak(utterance)
    }
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ChangeColorHeaderViewDelegate, UIColorPickerViewControllerDelegate, CheckMarkTableViewCellDelegate, UIScrollViewDelegate {
    @IBOutlet weak var adBannerView: CustomGADBannerView!
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
        }
    }
    
    private var changeColorHeaderView: HeaderViewWithButton! {
        didSet {
            changeColorHeaderView.type = .color
            changeColorHeaderView.delegate = self
            changeColorHeaderView.backgroundColor = .systemGray6
        }
    }
    
    private var voiceHeaderView: HeaderViewWithButton! {
        didSet {
            voiceHeaderView.type = .voice
            voiceHeaderView.delegate = self
            voiceHeaderView.backgroundColor = .systemGray6
        }
    }
    
    private lazy var voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
        let currentDesc = Locale.getDescription(id: Locale.current.identifier)?.components(separatedBy: " ").first
        let checkedDesc = Locale.getDescription(id: voice.language)?.components(separatedBy: " ").first
        return currentDesc == checkedDesc
    }
    
    private var isVoicesOpen = false
    private var settingsArray: [[Option]]!
    private var settingsArrayToDisplay: [[Option]]!
    private let viewModel = SettingsViewModel()
    
    override func viewDidLoad() {
        initBanner()
        buildOptions()
        changeColorHeaderView = HeaderViewWithButton()
        voiceHeaderView = HeaderViewWithButton()
        tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")
        tableView.register(UINib(nibName: "CheckMarkTableViewCell", bundle: nil), forCellReuseIdentifier: "CheckMarkTableViewCell")
        tableView.register(UINib(nibName: "RemoveAdsTableViewCell", bundle: nil), forCellReuseIdentifier: "RemoveAdsTableViewCell")
        tableView.reloadData()
    }
    
    private func buildOptions() {
        let firstOption = buildOption(textKey: "change color", imageKey: "changeColor")
        let secoundOption = buildOption(textKey: "change color", imageKey: "changeColor")
        let thirdOption = buildOption(textKey: "change AR arrow color", imageKey: "changeColor")
        let section0 = [firstOption, secoundOption, thirdOption]
        var section1 = [buildOption(textKey: "pick voice", imageKey:  "voiceArrow")]
        for voice in voices {
            let option = buildOption(textKey: voice.name, imageKey: "voiceImage")
            section1.append(option)
        }
        settingsArray = [section0, section1]
        settingsArrayToDisplay = settingsArray
    }
    
    private func getCircleColor(for key: String) -> UIColor {
        if let hex = UserDefaults.standard.value(forKey: key) as? String {
            return UIColor(hexString: hex)
        }
        return .systemYellow
    }
    
    private func buildOption(textKey: String, imageKey: String) -> Option {
        return Option(NSLocalizedString(textKey, comment: "") , imageKey)
    }
    
    private func initBanner() {
        adBannerView.adUnitID = AdMobUnitID.sheard.bannerSettings
        adBannerView.adSize = GADAdSizeFromCGSize(CGSize(width: view.frame.width, height: adBannerView.frame.height))
        adBannerView.rootViewController = self
        adBannerView.delegate = adBannerView
        loadBanner()
    }
    
    private func loadBanner() {
        viewModel.getBanner { [weak self] banner in
            guard let self else { return }
            adBannerView.load(banner)
            adBannerView.bannerViewDidReceiveAd { [weak self] in
                guard let self else { return }
                adBannerView.isHidden = false
            }
        }
    }
    
    @IBAction func didClickOnBack(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        let plus = SubscriptionService.shared.removedAdsPurchesd ? 0 : 1
        return settingsArrayToDisplay.count + plus
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return changeColorHeaderView.selected() ? 1 : 3
        case 1:
            return isVoicesOpen ? 1 + voices.count : 1
        default:
            return SubscriptionService.shared.removedAdsPurchesd ? 0 : 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 74
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return changeColorHeaderView
        case 1:
            return voiceHeaderView
        default:
            let header = HeaderViewWithButton()
            header.type = .purchases
            return header
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var returnedCell: UITableViewCell!
        
        let section = indexPath.section
        let row = indexPath.row
        
        guard section < settingsArrayToDisplay.count else {
            guard !SubscriptionService.shared.removedAdsPurchesd else { return UITableViewCell() }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "RemoveAdsTableViewCell") as? RemoveAdsTableViewCell else { return UITableViewCell() }
            cell.selectionStyle = .none
            return cell
        }
        
        let option = settingsArrayToDisplay[indexPath.section][indexPath.row]
        
        var text = option.text
        let image = option.image
        
        if section == 0 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell") as? SettingsTableViewCell else { return UITableViewCell() }
            cell.button.image = nil
            returnedCell = cell
            var key = ""
            if row == 0 {
                key = "mapRouteColor"
                if !changeColorHeaderView.selected() {
                    text = "\(text) \(NSLocalizedString("route", comment: "")) \(NSLocalizedString("map", comment: ""))"
                }
            }
            else if indexPath.row == 1 {
                key = "arRouteColor"
                text = "\(text) \(NSLocalizedString("route", comment: "")) \(NSLocalizedString("AR", comment: ""))"
            }
            else if indexPath.row == 2 {
                key = "arArrowColor"
            }
            
            let color = getCircleColor(for: key)
            cell.circle.backgroundColor = color
            cell.title.text = text
            if let gif = try? UIImage(gifName: image) {
                cell.button.setGifImage(gif)
            }
            
            returnedCell.selectionStyle = .default
        }
        else if section == 1 {
            if row == 0 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell") as? SettingsTableViewCell else { return UITableViewCell() }
                returnedCell = cell
                cell.button.image = nil
                cell.circle.backgroundColor = .clear
                cell.title.text = text
                cell.button.image = UIImage(named: image)
            }
            else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CheckMarkTableViewCell") as? CheckMarkTableViewCell else { return UITableViewCell() }
                returnedCell = cell
                cell.delegate = self
                cell.title.font = .init(name: "Noteworthy Light", size: 20.0)
                cell.title.text = text
                cell.button.image = UIImage(named: image)
                let selected = voices[row - 1].identifier == (UserDefaults.standard.string(forKey:"voiceID - \(Locale.getDescription(id: Locale.current.identifier)?.components(separatedBy: " ").first ?? "error")") ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier)
                cell.isSelected(selected)
            }
            
            returnedCell.selectionStyle = .none
        }
        
        return returnedCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let colorPicker = UIColorPickerViewController()
            let color = getCircleColor(for: indexPath.row == 0 ? "mapRouteColor" : indexPath.row == 1 ? "arRouteColor" : "arArrowColor")
            colorPicker.selectedColor = color
            colorPicker.delegate = self
            colorPicker.modalTransitionStyle = .crossDissolve
            colorPicker.modalPresentationStyle = .fullScreen
            colorPicker.view.tag = indexPath.row
            show(colorPicker, sender: nil)
        case 1:
            let indexPaths = (1..<1 + voices.count).map { IndexPath(row: $0, section: 1) }
            if indexPath.row == 0 {
                isVoicesOpen = !isVoicesOpen
                let cell = tableView.cellForRow(at: indexPath) as? SettingsTableViewCell
                cell?.button.rotateView(duration: 0.2)
                if isVoicesOpen {
                    tableView.insertRows(at: indexPaths, with: .fade)
                }
                else {
                    tableView.deleteRows(at: indexPaths, with: .fade)
                }
            }
            else {
                UserDefaults.standard.setValue(voices[indexPath.row - 1].identifier, forKey:"voiceID - \(Locale.getDescription(id: Locale.current.identifier)?.components(separatedBy: " ").first ?? "error")")
                voiceHeaderView.setUI()
                viewModel.voiceText(voiceID: voices[indexPath.row - 1].identifier)
                tableView.reloadRows(at: indexPaths, with: .fade)
            }
        default:
            guard !SubscriptionService.shared.removedAdsPurchesd else { return }
            removeAds()
        }
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard !continuously else { return }
        viewController.dismiss(animated: true)
        let hex = viewController.selectedColor.toHexString()
        switch viewController.view.tag {
        case 0:
            if changeColorHeaderView.selected() {
                UserDefaults.standard.setValue(hex, forKey: "mapRouteColor")
                UserDefaults.standard.setValue(hex, forKey: "arRouteColor")
                UserDefaults.standard.setValue(hex, forKey: "arArrowColor")
            }
            else {
                UserDefaults.standard.setValue(hex, forKey: "mapRouteColor")
            }
        case 1:
            UserDefaults.standard.setValue(hex, forKey: "arRouteColor")
        case 2:
            UserDefaults.standard.setValue(hex, forKey: "arArrowColor")
        default:
            break
        }
        
        tableView.reloadSections([0], with: .none)
    }
    
    func voice(view: HeaderViewWithButton) {
        guard let id = (UserDefaults.standard.string(forKey:"voiceID - \(Locale.getDescription(id: Locale.current.identifier)?.components(separatedBy: " ").first ?? "error")")) else { return }
        viewModel.voiceText(voiceID: id)
    }
    
    func didSelect(view: HeaderViewWithButton) {
        switch view.type {
        case .color:
            if view.selected() {
                tableView.deleteRows(at: [1, 2].map { .init(row: $0, section: 0) }, with: .fade)
                tableView.reloadRows(at: [0].map { .init(row: $0, section: 0) }, with: .fade)
            }
            else {
                tableView.insertRows(at: [1, 2].map { .init(row: $0, section: 0) }, with: .fade)
                tableView.reloadRows(at: [0, 1, 2].map { .init(row: $0, section: 0) }, with: .fade)
            }
        case .voice:
            tableView.scrollToRow(at: .init(row: 0, section: 1), at: .top, animated: true)
        case .purchases:
            return
        case .none:
            return
        }
    }
    
    func didPressOnPlay(cell: CheckMarkTableViewCell) {
        guard let index = tableView.indexPath(for: cell)?.row else { return }
        viewModel.voiceText(voiceID: voices[index - 1].identifier)
    }
    
    private func removeAds() {
        let loader = UIActivityIndicatorView()
        loader.backgroundColor = .white.withAlphaComponent(0.5)
        loader.style = .large
        loader.addTo(view: view)
        loader.startAnimating()
        
        let service = SubscriptionService.shared
        service.startWith(arrayOfIds: ["argo.removeAds"], sharedSecret: "") { [weak self] products in
            guard let product = products.first else { return }
            service.purchaseProduct(product: product) { ids in
                Task { [weak self] in
                    await service.handelePremium()
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        loadBanner()
                        loader.removeFromSuperview()
                        tableView.reloadData()
                    }
                }
            } failure: { error in
                loader.removeFromSuperview()
                print(error?.localizedDescription ?? "")
            } start: {}
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let cell = tableView.cellForRow(at: .init(row: 0, section: 1)), scrollView.contentOffset.y <= cell.frame.minY {
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                voiceHeaderView.button.alpha = 0
            }
        }
        else {
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                voiceHeaderView.button.alpha = 1
            }
        }
    }
}
