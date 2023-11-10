//
//  UIViewControler+EXT.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import UIKit

extension UIViewController {
    static func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
            
        } else if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
            
        } else if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return base
    }
}
