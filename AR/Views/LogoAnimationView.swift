//
//  LogoAnimationView.swift
//  The One
//
//  Created by ברק בן חור on 16/04/2022.
//

import UIKit
import SwiftyGif

class LogoAnimationView: UIView {
    
    var logoGifImageView: UIImageView!
    
    var delegate: SwiftyGifDelegate? = nil {
        didSet {
            logoGifImageView.delegate = delegate
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        logoGifImageView = try? UIImageView(gifImage: UIImage(gifName: "luanch"))
        backgroundColor = .black
        addSubview(logoGifImageView!)
        logoGifImageView?.contentMode = .scaleAspectFit
        logoGifImageView?.translatesAutoresizingMaskIntoConstraints = false
        logoGifImageView?.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        logoGifImageView?.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        logoGifImageView?.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        logoGifImageView?.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
    }
}
