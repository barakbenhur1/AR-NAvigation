//
//  ADMobIDProvider.swift
//  AR
//
//  Created by ברק בן חור on 23/10/2023.
//

import UIKit

internal class AdMobUnitID: NSObject {
    static let sheard = AdMobUnitID()
    
    var appStartID = {
        return EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-6040820758186818/1051099507"
    }()
    
    var bannerID = {
        return  EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-6040820758186818/5705947815"
    }()
    
    var banner1ID = {
        return  EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-6040820758186818/9583161805"
    }()
    
    var banner2ID = {
        return  EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-6040820758186818/2213853963"
    }()
    
    var bannerToCloseID = {
        return  EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-6040820758186818/5237093818"
    }()
    
    var interstitialNoRewardID = {
        return EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-6040820758186818/1854659688"
    }()
    
    var endRouteInterstitialNoRewardID = {
        return EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-6040820758186818/2880122273"
    }()
    
    private override init() {}
}
