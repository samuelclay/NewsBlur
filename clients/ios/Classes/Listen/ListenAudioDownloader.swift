//
//  ListenAudioDownloader.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// ListenAudioDownloader.swift fetches one segment's audio into a local file before it plays.
///
/// node/listen.coffee streams freshly generated audio as chunked audio/mpeg with no Content-Length and no Range
/// support, which AVPlayer only starts once the whole stream has arrived (about 5s for a title segment in
/// testing) and can't seek. A plain download finishes sooner (about 2s for the title-only first segment), and the
/// local file plays and seeks precisely. Cached segments redirect to presigned S3 URLs, which URLSession follows.
final class ListenAudioDownloader: NSObject {
    static let shared = ListenAudioDownloader()

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 180
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    /// Where downloaded segments live while a story plays; cleared when playback stops.
    let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ListenAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Downloads `url` to a local .mp3 file named after `name`. The completion runs on the main queue.
    @discardableResult
    func download(_ url: URL, name: String, completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionDownloadTask {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let destination = directory.appendingPathComponent(name).appendingPathExtension("mp3")
        let task = session.downloadTask(with: request) { location, response, error in
            let result: Result<URL, Error>
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                result = .failure(ListenAudioDownloadError.status(http.statusCode))
            } else if let location {
                do {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: location, to: destination)
                    let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? 0
                    result = size > 0 ? .success(destination) : .failure(ListenAudioDownloadError.empty)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(ListenAudioDownloadError.empty)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
        task.resume()
        return task
    }

    /// Removes every downloaded file, or only those whose names start with `prefix`.
    func removeFiles(withPrefix prefix: String? = nil) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            if let prefix, !file.lastPathComponent.hasPrefix(prefix) {
                continue
            }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        #if targetEnvironment(macCatalyst)
        return "NewsBlur Mac App v\(version)"
        #else
        return "NewsBlur iOS App v\(version)"
        #endif
    }
}

enum ListenAudioDownloadError: Error {
    case status(Int)
    case empty
}
