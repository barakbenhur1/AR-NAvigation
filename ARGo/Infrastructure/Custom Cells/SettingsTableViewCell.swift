//
//  SettingsTableViewCell.swift
//  ARGo
//
//  Created by ברק בן חור on 13/11/2023.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var button: UIImageView!
    @IBOutlet weak var circle: UIImageView! {
        didSet {
            circle.cornerRadius = circle.frame.height / 2
        }
    }
}
