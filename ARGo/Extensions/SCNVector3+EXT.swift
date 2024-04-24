//
//  SCNVector3+EXT.swift
//  ARGo
//
//  Created by Barak Ben Hur on 30/11/2023.
//

import Foundation
import SceneKit

extension SCNVector3 {
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
    }
}
