// WidgetSource.swift keeps each widget's selection and cached stories independent.
import Foundation
import CryptoKit

struct WidgetSourceCatalog {
    static let group = "group.com.newsblur.NewsBlur-Group"
    static let key = "widget:source_catalog"
    static let faviconKey = "widget:source_favicons"
    let feeds: [String: [String: Any]]
    let folders: [String: [String]]
    private let hasCachedCatalog: Bool
    private let favicons: [String: String]

    init(dictionary: [String: Any], favicons: [String: String] = [:]) {
        hasCachedCatalog = dictionary["feeds"] is [String: [String: Any]]
        feeds = dictionary["feeds"] as? [String: [String: Any]] ?? [:]
        self.favicons = favicons
        let flat = dictionary["flat_folders"] as? [String: [Any]] ?? [:]
        folders = flat.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .mapValues { $0.compactMap { ($0 as? NSNumber)?.stringValue ?? $0 as? String } }
    }

    static func load(defaults: UserDefaults? = UserDefaults(suiteName: group)) -> Self {
        let dictionary = matchingDictionary(forKey: key, defaults: defaults) ?? [:]
        let icons = matchingDictionary(forKey: faviconKey, defaults: defaults)?["favicons"] as? [String: String] ?? [:]
        return Self(dictionary: dictionary, favicons: icons)
    }

    private static func matchingDictionary(forKey key: String, defaults: UserDefaults?) -> [String: Any]? {
        guard let username = defaults?.string(forKey: "share:username"),
              let host = defaults?.string(forKey: "share:host") else { return nil }
        let data = defaults?.data(forKey: key) ?? Data()
        let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        // WidgetSource.swift rejects a catalog belonging to a previously signed-in account.
        guard dictionary["username"] as? String == username,
              dictionary["host"] as? String == host else { return nil }
        return dictionary
    }

    func favicon(for feed: String) -> Data? {
        guard feeds[feed] != nil,
              let encoded = favicons[feed] ?? feeds[feed]?["favicon"] as? String,
              let data = Data(base64Encoded: encoded), !data.isEmpty else { return nil }
        return data
    }

    static func store(dictionary: [String: Any], username: String, host: String, defaults: UserDefaults) {
        guard defaults.string(forKey: "share:username") == username,
              defaults.string(forKey: "share:host") == host,
              let feeds = dictionary["feeds"] as? [String: [String: Any]] else { return }
        var icons: [String: String] = [:]
        var catalogFeeds = feeds
        for (id, feed) in feeds {
            if let encoded = feed["favicon"] as? String, let data = Data(base64Encoded: encoded), !data.isEmpty {
                icons[id] = encoded
            }
            catalogFeeds[id]?.removeValue(forKey: "favicon")
        }
        // WidgetSource.swift keeps icons separate because NewsBlurAppDelegate.m republishes an iconless catalog.
        let catalogDictionary: [String: Any] = ["username": username, "host": host, "feeds": catalogFeeds,
                                                "flat_folders": dictionary["flat_folders"] ?? [:]]
        if let data = try? JSONSerialization.data(withJSONObject: catalogDictionary) { defaults.set(data, forKey: key) }
        storeFavicons(icons, username: username, host: host, defaults: defaults)
    }

    static func storeFavicons(_ icons: [String: Any], username: String, host: String, defaults: UserDefaults) {
        guard defaults.string(forKey: "share:username") == username,
              defaults.string(forKey: "share:host") == host else { return }
        let feeds = load(defaults: defaults).feeds
        var cached = matchingDictionary(forKey: faviconKey, defaults: defaults)?["favicons"] as? [String: String] ?? [:]
        let encodedIcons = icons.compactMapValues { $0 as? String }
        cached.merge(encodedIcons.filter { Data(base64Encoded: $0.value)?.isEmpty == false }) { _, new in new }
        cached = cached.filter { feeds[$0.key] != nil }
        let dictionary: [String: Any] = ["username": username, "host": host, "favicons": cached]
        if let data = try? JSONSerialization.data(withJSONObject: dictionary) { defaults.set(data, forKey: faviconKey) }
    }

    static func refresh(includeFavicons: Bool = true) async {
        guard let defaults = UserDefaults(suiteName: group),
              let host = defaults.string(forKey: "share:host"),
              let token = defaults.string(forKey: "share:token"), !token.isEmpty,
              let username = defaults.string(forKey: "share:username"),
              var components = URLComponents(string: host + "/reader/feeds") else { return }
        components.queryItems = [URLQueryItem(name: "flat", value: "true"),
                                 URLQueryItem(name: "update_counts", value: "false"),
                                 URLQueryItem(name: "secret_token", value: token)]
        guard let url = components.url else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.httpShouldHandleCookies = false
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              dictionary["user"] as? String == username,
              dictionary["feeds"] is [String: [String: Any]],
              defaults.string(forKey: "share:token") == token,
              defaults.string(forKey: "share:host") == host else { return }
        store(dictionary: dictionary, username: username, host: host, defaults: defaults)
        // WidgetSource.swift batches icons in one server query during timeline refresh, never in the picker.
        guard includeFavicons, var iconComponents = URLComponents(string: host + "/reader/favicons") else { return }
        iconComponents.queryItems = [URLQueryItem(name: "secret_token", value: token)]
        guard let iconURL = iconComponents.url else { return }
        var iconRequest = URLRequest(url: iconURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        iconRequest.httpShouldHandleCookies = false
        guard let (iconData, iconResponse) = try? await URLSession.shared.data(for: iconRequest),
              (iconResponse as? HTTPURLResponse)?.statusCode == 200,
              let icons = (try? JSONSerialization.jsonObject(with: iconData)) as? [String: Any],
              defaults.string(forKey: "share:token") == token else { return }
        storeFavicons(icons, username: username, host: host, defaults: defaults)
    }

    static func loadForPicker(defaults: UserDefaults?, refresh: () async -> Void) async -> Self {
        let cached = load(defaults: defaults)
        if cached.hasCachedCatalog { return cached }
        await refresh()
        return load(defaults: defaults)
    }

    func feedIDs(for source: String) -> [String] {
        if source == "all" { return feeds.keys.sorted() }
        if source.hasPrefix("feed:") {
            let id = String(source.dropFirst(5))
            return feeds[id] == nil ? [] : [id]
        }
        guard source.hasPrefix("folder:") else { return [] }
        let folder = String(source.dropFirst(7))
        guard folders[folder] != nil else { return [] }
        // WidgetSource.swift includes descendants using the server's full folder-path separator.
        let ids = folders.filter { $0.key == folder || $0.key.hasPrefix(folder + " - ") }
            .flatMap { $0.value }
        return Set(ids).filter { feeds[$0] != nil }.sorted()
    }

    static func cacheFilename(host: String, username: String, source: String, feedIDs: [String]) -> String {
        let identity = [host, username, source] + feedIDs.sorted()
        let data = (try? JSONEncoder().encode(identity)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + ".json"
    }
}
