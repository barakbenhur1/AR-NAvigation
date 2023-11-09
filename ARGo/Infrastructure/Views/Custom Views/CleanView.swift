//
//  CleanView.swift
//  RickAndMorty
//
//  Created by ברק בן חור on 26/08/2023.
//

import UIKit

class CleanView: UIView {
    @IBOutlet var contentView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        let desc = String(describing: type(of:self))
        let end = desc.range(of: "<")
        let name = String(desc[desc.startIndex..<(end?.lowerBound ?? desc.endIndex)])
        Bundle.main.loadNibNamed(name, owner: self, options: nil)
        contentView.fixInView(self)
    }
}
