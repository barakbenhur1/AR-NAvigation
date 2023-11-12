//
//  LoaderView.swift
//  AR
//
//  Created by ברק בן חור on 08/11/2023.
//

import UIKit

enum LoaderType {
    case new, reroute
    
    func getText() -> String {
        switch self {
        case .new:
            return NSLocalizedString("calculating route", comment: "")
        case .reroute:
            return NSLocalizedString("reroute", comment: "")
        }
    }
}

class LoaderView: CleanView {
    @IBOutlet weak var text: UILabel!
    @IBOutlet weak var gif: UIImageView! {
        didSet {
            setGif()
        }
    }
    
    func setGif() {
        guard let image = try? UIImage(gifName: "route") else { return }
        gif.setGifImage(image)
        gif.contentMode = .scaleAspectFill
    }
    
    var type: LoaderType = .new {
        didSet {
            text.text = type.getText()
        }
    }
}
