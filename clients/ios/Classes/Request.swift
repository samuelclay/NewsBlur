//
//  Request.swift
//  NewsBlur
//
//  Created by David Sinclair on 2025-03-26.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

import Foundation

enum RequestError: Error {
    case invalidJSON
}

/// Network request manager.
class Request: NSObject {
    typealias Completion = (Result<Any, Error>) -> Void
    
    private var completion: Completion
    
    private var receivedData = Data()
    
    private var networkOperationIdentifier: String?
    
    let appDelegate = NewsBlurAppDelegate.shared!
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }
    
    enum ContentType: String {
        case html = "text/html"
        case json = "application/json"
    }
    
    @discardableResult
    init(method: Method = .post, endpoint: String, parameters: [String : Any], contentType: ContentType = .html, completion: @escaping Completion) {
        self.completion = completion
        
        if method == .get {
            fatalError("Request doesn't support GET yet")
        }
        
        super.init()
        
        guard let baseURL = URL(string: appDelegate.url) else {
            return
        }
        
        let url = baseURL.appendingPathComponent(endpoint, isDirectory: true)
        
        var request = URLRequest(url: url)
        
        request.httpMethod = method.rawValue
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        
        request.setValue("\(contentType.rawValue); charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(contentType.rawValue); charset=utf-8", forHTTPHeaderField: "Accept")
        
        let config = URLSessionConfiguration.default
        config.sharedContainerIdentifier = "group.com.newsblur.NewsBlur-Group"
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        
        networkOperationIdentifier = appDelegate.beginNetworkOperation()
        
        task.resume()
    }
}

// MARK: - URL session delegate

extension Request: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            completionHandler(.cancel)
            return
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        NSLog("error: \(error.debugDescription)")
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("🚧 \(dataTask.currentRequest?.url?.path ?? "?") data: \(data)")
        
        receivedData.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        appDelegate.endNetworkOperation(networkOperationIdentifier)
        
        DispatchQueue.main.async {
            if let error {
                self.completion(.failure(error))
            } else if let value = try? JSONSerialization.jsonObject(with: self.receivedData) {
                self.completion(.success(value))
            } else {
                self.completion(.failure(RequestError.invalidJSON))
            }
        }
    }
}
