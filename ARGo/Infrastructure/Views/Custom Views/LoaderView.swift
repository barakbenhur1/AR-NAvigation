//
//  LoaderView.swift
//  AR
//
//  Created by ברק בן חור on 08/11/2023.
//

import UIKit

enum LoaderType {
    case new, reroute, error
    
    func getInfo() -> (text: String, gif: String) {
        switch self {
        case .new:
            return (NSLocalizedString("calculating route", comment: ""), "route")
        case .reroute:
            return (NSLocalizedString("reroute", comment: ""), "route")
        case .error:
            return (NSLocalizedString("something went wrong", comment: ""), "error")
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
        let info = type.getInfo()
        guard let image = try? UIImage(gifName: info.gif) else { return }
        gif.setGifImage(image)
        gif.contentMode = .scaleAspectFill
    }
    
    var type: LoaderType = .new {
        didSet {
            let info = type.getInfo()
            text.text = info.text
            guard let image = try? UIImage(gifName: info.gif) else { return }
            gif.setGifImage(image)
            gif.contentMode = type == .error ? .scaleAspectFit : .scaleAspectFill
        }
    }
}
