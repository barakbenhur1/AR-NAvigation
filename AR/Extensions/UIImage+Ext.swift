//
//  UIImage+Ext.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit

extension UIImageView {
    @IBInspectable var gifName: String {
        set {
            guard let gif = try? UIImage(gifName: newValue) else { return }
            setGifImage(gif)
        }
        get {
            return gifImage?.description ?? ""
        }
    }
}

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -origin.y, y: -origin.x,
                            width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return rotatedImage ?? self
        }

        return self
    }
}
