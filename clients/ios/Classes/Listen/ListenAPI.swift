//
//  ListenAPI.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// The library search filters for GET /listen/library (ListenAPI.swift).
struct ListenLibraryQuery: Equatable {
    var language: String
    var gender: String = ""
    var age: String = ""
    var accent: String = ""
    var useCase: String = ""
    var descriptive: String = ""
    var search: String = ""
    var sort: String = "popular"

    var parameters: [String: String] {
        var parameters: [String: String] = ["language": language, "sort": sort.isEmpty ? "popular" : sort]
        let optional = ["gender": gender, "age": age, "accent": accent, "use_case": useCase,
                        "descriptive": descriptive, "search": search.trimmingCharacters(in: .whitespacesAndNewlines)]
        for (key, value) in optional where !value.isEmpty {
            parameters[key] = value
        }
        return parameters
    }
}

/// ListenAPI.swift talks to apps/listen/views.py through the app delegate's AFNetworking session, so requests
/// carry the session cookie, User-Agent and Accept-Language like every other API call. POSTs are form-encoded.
final class ListenAPI {
    static let shared = ListenAPI()

    private var appDelegate: NewsBlurAppDelegate { NewsBlurAppDelegate.shared() }

    /// The server the app talks to, including custom servers set in preferences.
    var baseURL: String {
        let url = appDelegate.url ?? ""
        return url.isEmpty ? "https://www.newsblur.com" : url
    }

    /// Stream URLs are either relative (/listen/stream/<job>.mp3 on the NewsBlur server) or presigned S3 URLs.
    func resolve(_ urlString: String) -> URL? {
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }
        let path = urlString.hasPrefix("/") ? urlString : "/" + urlString
        return URL(string: baseURL + path)
    }

    func manifest(storyHash: String, language: String?, voiceId: String?,
                  completion: @escaping (Result<ListenManifest, ListenAPIError>) -> Void) {
        var parameters = ["story_hash": storyHash]
        if let language, !language.isEmpty { parameters["language"] = language }
        if let voiceId, !voiceId.isEmpty { parameters["voice_id"] = voiceId }
        post("/listen/manifest", parameters: parameters, parse: { ListenManifest(json: $0) }, completion: completion)
    }

    func segment(manifestId: String, index: Int,
                 completion: @escaping (Result<ListenSegmentLocation, ListenAPIError>) -> Void) {
        post("/listen/segment", parameters: ["manifest_id": manifestId, "index": String(index)], parse: { [weak self] json in
            guard let self, let urlString = ListenJSON.string(json["url"]), let url = self.resolve(urlString) else { return nil }
            return ListenSegmentLocation(index: ListenJSON.int(json["index"]) ?? index, url: url,
                                         cached: ListenJSON.bool(json["cached"]) ?? false,
                                         duration: ListenJSON.double(json["duration"]),
                                         usage: ListenUsage(json: json["usage"]))
        }, completion: completion)
    }

    /// About ten seconds of the story (or a sample sentence) in the given voice and delivery.
    func preview(voiceId: String, storyHash: String?, language: String?, delivery: ListenDeliverySettings?,
                 completion: @escaping (Result<ListenVoicePreview, ListenAPIError>) -> Void) {
        var parameters = ["voice_id": voiceId]
        if let storyHash, !storyHash.isEmpty { parameters["story_hash"] = storyHash }
        if let language, !language.isEmpty { parameters["language"] = language }
        if let delivery {
            parameters.merge(delivery.previewParameters) { _, new in new }
        }
        post("/listen/preview", parameters: parameters, parse: { [weak self] json in
            guard let self, let urlString = ListenJSON.string(json["url"]), let url = self.resolve(urlString) else { return nil }
            return ListenVoicePreview(url: url, text: ListenJSON.string(json["text"]) ?? "",
                                      voice: ListenVoice(json: json["voice"]), usage: ListenUsage(json: json["usage"]))
        }, completion: completion)
    }

    func voices(language: String?, completion: @escaping (Result<ListenVoicesCatalog, ListenAPIError>) -> Void) {
        var parameters: [String: String] = [:]
        if let language, !language.isEmpty { parameters["language"] = language }
        get("/listen/voices", parameters: parameters, parse: { ListenVoicesCatalog(json: $0) }, completion: completion)
    }

    func library(query: ListenLibraryQuery, page: Int,
                 completion: @escaping (Result<ListenLibraryPage, ListenAPIError>) -> Void) {
        var parameters = query.parameters
        parameters["page"] = String(page)
        get("/listen/library", parameters: parameters, parse: { ListenLibraryPage(json: $0) }, completion: completion)
    }

    /// Listening analytics: audio played since the last report. Errors are dropped after one retry.
    func progress(manifestId: String, seconds: TimeInterval, speed: Double, finished: Bool, attempt: Int = 0) {
        var parameters = ["manifest_id": manifestId,
                          "seconds": String(format: "%.1f", max(0, seconds)),
                          "speed": String(format: "%.2f", speed)]
        if finished {
            parameters["finished"] = "true"
        }
        appDelegate.post(baseURL + "/listen/progress", parameters: parameters, success: nil, failure: { [weak self] _, _ in
            guard attempt == 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.progress(manifestId: manifestId, seconds: seconds, speed: speed, finished: finished, attempt: 1)
            }
        })
    }

    func usage(completion: @escaping (Result<ListenUsage, ListenAPIError>) -> Void) {
        get("/listen/usage", parameters: [:], parse: { ListenUsage(json: $0["usage"]) }, completion: completion)
    }

    // MARK: - Transport

    private func get<T>(_ path: String, parameters: [String: String], parse: @escaping ([String: Any]) -> T?,
                        completion: @escaping (Result<T, ListenAPIError>) -> Void) {
        appDelegate.get(baseURL + path, parameters: parameters, success: { [weak self] _, response in
            self?.finish(response, parse: parse, completion: completion)
        }, failure: { [weak self] _, error in
            self?.fail(error ?? URLError(.unknown), completion: completion)
        })
    }

    private func post<T>(_ path: String, parameters: [String: String], parse: @escaping ([String: Any]) -> T?,
                         completion: @escaping (Result<T, ListenAPIError>) -> Void) {
        appDelegate.post(baseURL + path, parameters: parameters, success: { [weak self] _, response in
            self?.finish(response, parse: parse, completion: completion)
        }, failure: { [weak self] _, error in
            self?.fail(error ?? URLError(.unknown), completion: completion)
        })
    }

    private func finish<T>(_ response: Any?, parse: ([String: Any]) -> T?,
                           completion: (Result<T, ListenAPIError>) -> Void) {
        guard let json = ListenJSON.dictionary(response) else {
            completion(.failure(.invalidResponse))
            return
        }
        if let failure = Self.failure(from: json) {
            completion(.failure(failure))
            return
        }
        guard let value = parse(json) else {
            completion(.failure(.invalidResponse))
            return
        }
        completion(.success(value))
    }

    private func fail<T>(_ error: Error, completion: (Result<T, ListenAPIError>) -> Void) {
        // AFNetworking keeps a non-2xx response body; apps/listen/views.py may have explained the failure there.
        let nsError = error as NSError
        if let data = nsError.userInfo["com.alamofire.serialization.response.error.data"] as? Data,
           let json = ListenJSON.dictionary(try? JSONSerialization.jsonObject(with: data)),
           let failure = Self.failure(from: json) {
            completion(.failure(failure))
            return
        }
        NSLog("Listen request failed: %@", nsError)
        completion(.failure(.network(error)))
    }

    private static func failure(from json: [String: Any]) -> ListenAPIError? {
        guard let code = ListenJSON.int(json["code"]), code < 0 else { return nil }
        let message = ListenJSON.string(json["message"]).flatMap { $0.isEmpty ? nil : $0 }
            ?? NBLocalization.text("Listening isn't available right now.")
        return ListenAPIError(reason: ListenJSON.string(json["reason"]), message: message,
                              usage: ListenUsage(json: json["usage"]))
    }
}
