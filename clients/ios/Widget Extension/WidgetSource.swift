// WidgetSource.swift keeps each widget's selection and cached stories independent.
import Foundation
import CryptoKit

enum WidgetLink {
    case background
    case story(feedID: String, hash: String, site: [String: String]?)
    case status(String)

    func url(source: String) -> URL {
        var link = URLComponents(string: "newsblurwidget://")!
        var items = [URLQueryItem(name: "source", value: source)]
        switch self {
        case .background:
            link.host = "open"
        case let .status(error):
            items.append(URLQueryItem(name: "error", value: error))
        case let .story(feedID, hash, site):
            items.append(URLQueryItem(name: "feedId", value: feedID))
            items.append(URLQueryItem(name: "storyHash", value: hash))
            if let title = site?["feed_title"] {
                items.append(URLQueryItem(name: "siteTitle", value: title))
            }
            if let address = site?["feed_address"] {
                items.append(URLQueryItem(name: "siteAddress", value: address))
            }
        }
        link.queryItems = items
        return link.url!
    }
}

enum WidgetStorySource: String, CaseIterable {
    case infrequent
    case widelyRead = "trending:well_read"
    case longReads = "trending:long_reads"
    case goodReads = "trending:good_reads"

    var trendingType: String? {
        self == .infrequent ? nil : String(rawValue.dropFirst("trending:".count))
    }

    static func requestPath(source: String, feedIDs: [String], page: Int, limit: Int, storiesPerMonth: Int) -> String {
        let paging = "page=\(page)&limit=\(limit)&order=newest&read_filter=unread"
        if let trendingType = Self(rawValue: source)?.trendingType {
            return "/reader/trending_stories/?\(paging)&trending_type=\(trendingType)&widget=true"
        }
        let threshold = source == Self.infrequent.rawValue ? String(storiesPerMonth) : "false"
        let feeds = feedIDs.map { "&f=\($0)" }.joined()
        return "/reader/river_stories_widget/?\(paging)&include_hidden=false&thumbnail_size=192&infrequent=\(threshold)\(feeds)"
    }
}

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

    private func encodedFavicon(for feed: String) -> String? {
        guard let metadata = feeds[feed] else { return nil }
        return favicons[feed] ?? metadata["favicon"] as? String
    }

    func favicon(for feed: String) -> Data? {
        guard let encoded = encodedFavicon(for: feed),
              let data = Data(base64Encoded: encoded), !data.isEmpty else { return nil }
        return data
    }

    func pickerSites(matching search: String) -> [(id: String, name: String, favicon: Data?)] {
        let matches = feeds.compactMap { id, feed -> (id: String, name: String)? in
            let title = feed["feed_title"] as? String ?? id
            guard search.isEmpty || title.localizedStandardContains(search) else { return nil }
            return (id, title)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // WidgetConfiguration.swift sends the entire options list between devices in one reply.
        // Use feed symbols when inline images would add more than 128 KiB to that reply.
        let encodedBytes = matches.reduce(0) { $0 + (encodedFavicon(for: $1.id)?.utf8.count ?? 0) }
        let includeIcons = encodedBytes <= 128 * 1024 * 4 / 3
        return matches.map { ($0.id, $0.name, includeIcons ? favicon(for: $0.id) : nil) }
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
        if source == "all" || source == WidgetStorySource.infrequent.rawValue { return feeds.keys.sorted() }
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
