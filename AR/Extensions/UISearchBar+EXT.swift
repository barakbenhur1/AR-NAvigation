//
//  UITextView+EXT.swift
//  AR
//
//  Created by ברק בן חור on 04/11/2023.
//

import UIKit

extension UISearchBar {
    @IBInspectable var localizedPalceHolderKey: String {
        set {
            placeholder = NSLocalizedString(newValue, comment: "")
        }
        get {
            return ""
        }
    }
}
