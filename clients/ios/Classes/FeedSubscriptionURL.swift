import Foundation

// FeedSubscriptionURL.swift keeps link parsing independent of app and extension lifecycle.
enum FeedSubscriptionURL {
    static func parse(_ url: URL) -> URL? {
        let scheme = url.scheme?.lowercased()
        if scheme == "newsblur" {
            guard url.host?.lowercased() == "subscribe",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let value = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let target = URL(string: value) else { return nil }
            return webURL(target)
        }
        guard scheme == "feed" || scheme == "feeds" else { return nil }
        let value = String(url.absoluteString.dropFirst((scheme?.count ?? 0) + 1))
        if value.hasPrefix("//") {
            return URL(string: (scheme == "feeds" ? "https:" : "http:") + value).flatMap(webURL)
        }
        return URL(string: value).flatMap(webURL)
    }

    static func webURL(_ url: URL) -> URL? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func feedID(in response: [String: Any]) -> String? {
        guard let code = response["code"] as? Int, code > 0,
              let feed = response["feed"] as? [String: Any] else { return nil }
        let id = (feed["id"] as? NSNumber)?.stringValue ?? feed["id"] as? String
        guard let id, let number = Int(id), number > 0 else { return nil }
        return id
    }
}
