//
//  EnvironmentManager.swift
//  AR
//
//  Created by ברק בן חור on 23/10/2023.
//

import UIKit

class EnvironmentManager: NSObject {
    static let sheard = EnvironmentManager()
    private override init(){}
    
    var isDebug: Bool {
        get {
#if DEBUG
            return true
#else
            return false
#endif
        }
    }
}

