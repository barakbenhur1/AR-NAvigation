//
//  FloatingPoint+EXT.swift
//  ARGo
//
//  Created by Barak Ben Hur on 30/11/2023.
//

import Foundation

extension FloatingPoint {
    func toRadians() -> Self {
        return self * .pi / 180
    }
    
    func toDegrees() -> Self {
        return self * 180 / .pi
    }
}
