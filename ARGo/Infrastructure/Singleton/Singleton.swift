//
//  Singleton.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import UIKit

class Singleton: NSObject {

   static let shared = Singleton()

    private override init(){}

//   private let internalQueue = DispatchQueue(label: "com.singletioninternal.queue",
//                                             qos: .default,
//                                             attributes: .concurrent)
}
