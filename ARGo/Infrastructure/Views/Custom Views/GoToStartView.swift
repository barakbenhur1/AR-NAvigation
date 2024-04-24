//
//  GoTOStart.swift
//  ARGo
//
//  Created by Barak Ben Hur on 02/12/2023.
//

import UIKit

class GoToStartView: CleanView {
    deinit {
        stackViewWrpper.stopBlinking()
        blur.stopBlinking()
        stack.stopBlinking()
    }
    
    override var isHidden: Bool {
        didSet {
            if isHidden {
                stackViewWrpper.stopBlinking()
                blur.stopBlinking()
                stack.stopBlinking()
            }
            else {
                stackViewWrpper.blink()
                blur.blink()
                stack.blink(flip: true)
            }
        }
    }
    
    @IBOutlet weak var blur: UIVisualEffectView! {
        didSet {
            blur.clipsToBounds = true
            blur.layer.cornerRadius = blur.frame.height / 2
        }
    }
    
    @IBOutlet weak var stack: UIStackView!
    
    @IBOutlet weak var stackViewWrpper: UIView! {
        didSet {
            stackViewWrpper.clipsToBounds = true
            stackViewWrpper.layer.cornerRadius = stackViewWrpper.frame.height / 2
            stackViewWrpper.layer.borderColor = UIColor.systemRed.cgColor
            stackViewWrpper.layer.borderWidth = 2
            stackViewWrpper.dropShadow(color: .black, opacity: 0.6, offSet: .init(width: 1, height: 1))
        }
    }
    
    @IBOutlet weak var title: UILabel! {
        didSet {
            title.font = .init(name: "Noteworthy Bold", size: 30)
            title.textColor = .systemRed
            title.textAlignment = .center
            title.text = NSLocalizedString("go to start", comment: "")
        }
    }
    
    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            imageView.image = UIImage(named: "start")
        }
    }
}
