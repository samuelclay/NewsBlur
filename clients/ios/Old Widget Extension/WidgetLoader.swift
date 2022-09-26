//
//  WidgetLoader.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-11-29.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import Foundation

/// Network loader for the widget.
class Loader: NSObject, URLSessionDataDelegate {
    typealias Completion = (Result<Data, Error>) -> Void
    
    private var completion: Completion
    
    private var receivedData = Data()
    
    init(url: URL, completion: @escaping Completion) {
        self.completion = completion
        
        super.init()
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "GET"
//        request.addValue(accept, forHTTPHeaderField: "Accept")
        
        let config = URLSessionConfiguration.background(withIdentifier: UUID().uuidString)
        config.sharedContainerIdentifier = "group.com.newsblur.NewsBlur-Group"
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        
        task.resume()
    }
    
    // MARK: - URL session delegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode) else {
                completionHandler(.cancel)
                return
        }
        
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("error: \(error.debugDescription)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("data: \(data)")
        
        receivedData.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completion(.failure(error))
        } else {
            completion(.success(receivedData))
        }
    }
}
