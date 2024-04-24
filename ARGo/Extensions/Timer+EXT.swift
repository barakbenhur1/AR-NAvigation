//
//  Timer+EXT.swift
//  ARGo
//
//  Created by Barak Ben Hur on 29/11/2023.
//

import Foundation

extension Timer {
    private static var timersDict: [String :[String: Timer]] = [:]
    
    static func stopTimers(for classKey: String = #file) {
        timersDict[classKey]?.values.forEach({ timer in timer.invalidate() })
        timersDict[classKey] = [:]
    }
    
    static func stopTimer(for classKey: String = #file, key: String) {
        let timer = timersDict[classKey]?[key]
        timer?.invalidate()
        timersDict[classKey]?[key] = nil
    }
    
    static func setTimer(for classKey: String = #file, key: String, time: CGFloat, repeats: Bool = true, function: @escaping () -> ()) {
        let timer = Timer(timeInterval: time, repeats: repeats, block: { timer in function() })
        if timersDict[classKey] == nil { timersDict[classKey] = [:] }
        timersDict[classKey]?[key] = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
