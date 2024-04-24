//
//  LogsAPI.swift
//  ARGo
//
//  Created by Barak Ben Hur on 29/11/2023.
//

import Foundation
import UIKit

class LogsAPI: Network {
    private let time = 30.0
    private var logs: [String]!
    
    private let semaphore = DispatchSemaphore(value: 2)
    
    override init() {
        logs = []
        super.init()
        setupTimer()
    }
    
    private func safeAction(action: @escaping () -> ()) {
//        DispatchQueue.global().async { [weak self] in
//            guard let self else { return }
            semaphore.wait()
            action()
            semaphore.signal()
//        }
    }
    
    @discardableResult private func log(event: String) async -> (Result<Void, Error>?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/YYYY HH:mm:ss"
        let formattedDate = dateFormatter.string(from: Date())
        let parameters: [String: String] = ["id": "\(IDProvider.sheard.id)", "time": "\(formattedDate)", "os": await UIDevice.current.systemVersion, "text": event]
        return await mainNoUploadReqeset(taskName: "log", url: "\(baseUrl)/logs/", postParamsters: parameters)
    }
    
    func add(event: String) {
        safeAction { [weak self] in
            guard let self else { return }
            logs.append(event)
        }
    }
    
    private func sendLogs() {
        safeAction { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                guard !logs.isEmpty else { return }
                let event = logs.remove(at: 0)
                await log(event: event)
                sendLogs()
            }
        }
    }
    
    @objc private func setupTimer() {
        Timer.setTimer(key: "logs", time: time) { [weak self] in
            guard let self else { return }
            sendLogs()
        }
    }
    
    func willTerminateNotification() {
        Timer.stopTimers()
        sendLogs()
    }
}
