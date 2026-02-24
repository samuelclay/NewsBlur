//
//  AddSiteViewModel.swift
//  NewsBlur
//
//  Created by Claude on 2026-02-23.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import Foundation
import Combine

struct AutocompleteResult: Identifiable {
    let id: String
    let label: String
    let value: String
    let numSubscribers: Int
    let favicon: String?
    let lastStorySecondsAgo: Int?

    init(dict: [String: Any]) {
        self.label = dict["feed_title"] as? String ?? dict["label"] as? String ?? ""
        self.value = dict["feed_address"] as? String ?? dict["value"] as? String ?? ""
        self.numSubscribers = dict["num_subscribers"] as? Int ?? dict["subs"] as? Int ?? 0
        self.favicon = dict["favicon"] as? String
        self.lastStorySecondsAgo = dict["last_story_seconds_ago"] as? Int
        self.id = self.value
    }
}

@available(iOS 15.0, *)
@MainActor
class AddSiteViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var autocompleteResults: [AutocompleteResult] = []
    @Published var selectedFolder: String = ""
    @Published var newFolderName: String = ""
    @Published var showAddFolder: Bool = false
    @Published var isSearching: Bool = false
    @Published var isAdding: Bool = false
    @Published var errorMessage: String?
    @Published var addedSuccess: Bool = false

    var onResultsAppeared: (() -> Void)?
    var onResultsCleared: (() -> Void)?

    private let appDelegate = NewsBlurAppDelegate.shared()!
    private var searchCache: [String: [AutocompleteResult]] = [:]
    private var debounceTimer: Timer?

    var displayFolder: String {
        selectedFolder.isEmpty ? "— Top Level —" : extractFolderName(selectedFolder)
    }

    var folders: [String] {
        guard let allFolders = appDelegate.dictFoldersArray as? [String] else { return [] }
        let excluded: Set<String> = [
            "saved_searches", "saved_stories", "read_stories", "widget_stories",
            "river_blurblogs", "river_global", "dashboard", "infrequent", "everything"
        ]
        return allFolders.filter { !excluded.contains($0) }
    }

    func folderDisplayName(_ folder: String) -> String {
        let components = folder.components(separatedBy: " \u{25B8} ")
        let name = components.last ?? folder
        let indent = String(repeating: "    ", count: components.count - 1)
        return indent + name
    }

    private func extractFolderName(_ folder: String) -> String {
        if let range = folder.range(of: " \u{25B8} ", options: .backwards) {
            return String(folder[range.upperBound...])
        }
        return folder
    }

    func onSearchTextChanged() {
        debounceTimer?.invalidate()
        errorMessage = nil

        if searchText.isEmpty {
            let hadResults = !autocompleteResults.isEmpty
            autocompleteResults = []
            if hadResults {
                onResultsCleared?()
            }
            return
        }

        if let cached = searchCache[searchText] {
            autocompleteResults = cached
            return
        }

        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSiteAddress()
            }
        }
    }

    func selectAutocompleteResult(_ result: AutocompleteResult) {
        searchText = result.value
        autocompleteResults = []
        onResultsCleared?()
    }

    func reset() {
        searchText = ""
        autocompleteResults = []
        selectedFolder = ""
        newFolderName = ""
        showAddFolder = false
        isSearching = false
        isAdding = false
        errorMessage = nil
        addedSuccess = false
        searchCache = [:]
    }

    private func checkSiteAddress() {
        let term = searchText
        guard !term.isEmpty else { return }

        isSearching = true

        let baseURL = appDelegate.url ?? "https://www.newsblur.com"
        let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        guard let url = URL(string: "\(baseURL)/rss_feeds/feed_autocomplete?term=\(encoded)&v=2&format=full&limit=10") else {
            isSearching = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSearching = false

                guard let data = data, error == nil else { return }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                let queryTerm = json["term"] as? String ?? ""
                let feeds = json["feeds"] as? [[String: Any]] ?? []
                let results = feeds.map { AutocompleteResult(dict: $0) }

                self.searchCache[queryTerm] = results

                if self.searchText == queryTerm {
                    let hadNoResults = self.autocompleteResults.isEmpty
                    self.autocompleteResults = results
                    if hadNoResults && results.count > 1 {
                        self.onResultsAppeared?()
                    }
                }
            }
        }.resume()
    }

    func addSite() {
        let urlText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlText.isEmpty else { return }

        isAdding = true
        errorMessage = nil
        autocompleteResults = []

        let baseURL = appDelegate.url ?? "https://www.newsblur.com"
        guard let url = URL(string: "\(baseURL)/reader/add_url") else {
            isAdding = false
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parentFolder: String
        if let range = selectedFolder.range(of: " \u{25B8} ", options: .backwards) {
            parentFolder = String(selectedFolder[range.upperBound...])
        } else if selectedFolder.contains("Top Level") || selectedFolder.isEmpty {
            parentFolder = ""
        } else {
            parentFolder = selectedFolder
        }

        var bodyParts = [
            "folder=\(parentFolder.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "url=\(urlText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        ]
        if showAddFolder && !newFolderName.isEmpty {
            bodyParts.append("new_folder=\(newFolderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isAdding = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Failed to add site"
                    return
                }

                let code = json["code"] as? Int ?? 0
                if code == -1 {
                    self.errorMessage = json["message"] as? String ?? "Failed to add site"
                } else {
                    self.addedSuccess = true
                }
            }
        }.resume()
    }
}
