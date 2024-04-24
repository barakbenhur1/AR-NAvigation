//
//  Network.swift
//  The One
//
//  Created by ברק בן חור on 31/07/2022.
//

import UIKit
import AVFAudio

typealias Status = [String: Int]

class Network: NSObject {
    
    var currentUrl: String { get { return baseUrl } }
    
    private enum HTTP {
        enum Error: LocalizedError {
            case invalidResponse
            case badStatusCode
            case missingData
            case noAuth
            case unknown
        }
    }
    
    internal lazy var baseUrl = { "https://argo-mn31.onrender.com" }()
    
    internal override init() {}
    
    internal func mainNoUploadReqeset<T>(taskName: String, url: String, postParamsters: [String: String]? = nil, allowMulti: Bool = false) async -> (Result<T, Error>)  {
        return await withCheckedContinuation({ [weak self] c in
            guard let self else { return c.resume(returning: .failure(HTTP.Error.unknown)) }
            guard !url.isEmpty else { return handele(error: HTTP.Error.badStatusCode, c: c) }
            guard let url = URL(string: url) else { return handele(error: HTTP.Error.badStatusCode, c: c) }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpMethod = postParamsters != nil ? "POST" : "GET"
            if let params = postParamsters {
                let json = try? JSONSerialization.data(withJSONObject: params)
                request.httpBody = json
            }
            handeleTask(taskName: taskName, request: request, c: c)
        })
    }
    
    private func handeleTask<T>(taskName: String, request: URLRequest, c: CheckedContinuation<Result<T, any Error>, Never>) {
        print("\(taskName):")
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self else { return c.resume(returning: .failure(HTTP.Error.unknown)) }
            guard let data = data else { return handele(error: HTTP.Error.missingData, c: c) }
            guard error == nil else { return handele(error: error!, c: c) }
            if let status = String(data: data, encoding: String.Encoding.utf8) { return handele(status: status, c: c) }
            do {
                guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? T else { return handele(error: HTTP.Error.invalidResponse, c: c) }
                handele(result: result, c: c)
            }
            catch {
                handele(error: error, c: c)
            }
        }
        task.resume()
    }
    
    private func handele<T>(error: Error, c: CheckedContinuation<Result<T, any Error>, Never>) {
        print(error.localizedDescription)
        c.resume(returning: .failure(error))
    }
    
    private func handele<T>(result: T, c: CheckedContinuation<Result<T, any Error>, Never>) {
        print("result: \(result)")
        c.resume(returning: .success(result))
    }
    
    private func handele<T>(status: String, c: CheckedContinuation<Result<T, any Error>, Never>) {
        print("status: \(status)")
        c.resume(returning: .success(Void() as! T))
    }
}
