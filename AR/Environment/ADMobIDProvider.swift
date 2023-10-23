//
//  ADMobIDProvider.swift
//  AR
//
//  Created by ברק בן חור on 23/10/2023.
//

import UIKit

class ADMobIDProvider: NSObject {
    static let sheard = ADMobIDProvider()
    private override init(){}
    
    var bannerID = {
        return  EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-6040820758186818/5705947815"
    }()
    
    var interstitialID = {
        return EnvironmentManager.sheard.isDebug ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-6040820758186818/6333220506"
    }()
}
