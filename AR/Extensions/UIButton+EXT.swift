//
//  UIButton+EXT.swift
//  AR
//
//  Created by ברק בן חור on 04/11/2023.
//

import UIKit

extension UIButton {
    @IBInspectable var localizedKey: String {
        set {
            setTitle(NSLocalizedString(newValue, comment: ""), for: .normal)
        }
        get {
            return ""
        }
    }
}
