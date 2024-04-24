//
//  CheckMarkTableViewCell.swift
//  ARGo
//
//  Created by ברק בן חור on 13/11/2023.
//

import UIKit
import SDK

protocol CheckMarkTableViewCellDelegate: UIViewController {
    func didPressOnPlay(cell: CheckMarkTableViewCell)
}

class CheckMarkTableViewCell: UITableViewCell, TrackbleGesture {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var check: UIImageView!
    @IBOutlet weak var button: UIImageView! {
        didSet {
            button.isUserInteractionEnabled = true
            button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didPressOnPlay)))
        }
    }
    
    weak var delegate: CheckMarkTableViewCellDelegate?
    
    func isSelected(_ selected: Bool) {
        if selected {
            check.image = UIImage(systemName: "checkmark")
        }
        else {
            check.image = nil
        }
    }
    
    @objc private func didPressOnPlay() {
        delegate?.didPressOnPlay(cell: self)
    }
}
