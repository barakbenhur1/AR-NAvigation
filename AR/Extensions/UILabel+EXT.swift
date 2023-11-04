//
//  UILabel+EXT.swift
//  AR
//
//  Created by ברק בן חור on 04/11/2023.
//

import UIKit

extension UILabel {
    @IBInspectable var localizedKey: String {
        set {
            text = NSLocalizedString(newValue, comment: "")
        }
        get {
            return ""
        }
    }
}
