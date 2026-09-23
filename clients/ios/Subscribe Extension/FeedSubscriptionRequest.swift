import Foundation

enum FeedSubscriptionError: LocalizedError {
    case invalidURL
    case signInRequired
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Share an RSS feed or website URL from Safari to subscribe."
        case .signInRequired:
            return "Open NewsBlur and sign in, then share this link again."
        case .server(let message):
            return message
        case .invalidResponse:
            return "NewsBlur could not confirm the subscription. Please try again."
        }
    }
}

struct FeedSubscriptionRequest {
    static func selectableFolders(_ folders: [String]) -> [String] {
        // AddSiteViewModel.swift excludes these navigation entries from subscription destinations.
        let excluded: Set<String> = [
            "saved_searches", "saved_stories", "read_stories", "widget_stories",
            "river_blurblogs", "river_global", "trending:well_read", "trending:long_reads", "trending:good_reads",
            "dashboard", "daily_briefing", "discover_sites", "infrequent", "everything"
        ]
        return ["everything"] + folders.filter { !excluded.contains($0) }
    }

    static func remoteURL(_ value: Any?) -> URL? {
        let text: String
        if let url = value as? URL {
            text = url.absoluteString
        } else if let string = value as? String {
            text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return nil
        }
        guard let url = URL(string: text),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              !text.contains(where: { $0.isWhitespace }) else { return nil }
        return url
    }

    static func make(url: URL, host: String, token: String, folder: String = "", newFolder: String = "") throws -> URLRequest {
        guard remoteURL(url) != nil else { throw FeedSubscriptionError.invalidURL }
        guard let base = remoteURL(host), !token.isEmpty,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw FeedSubscriptionError.signInRequired
        }
        components.query = nil
        components.fragment = nil
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encodedToken = token.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedFolder = folder.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedNewFolder = newFolder.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw FeedSubscriptionError.invalidURL
        }
        let path = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.percentEncodedPath = (path.isEmpty ? "" : "/" + path) + "/api/add_url/\(encodedToken)"
        guard let endpoint = components.url else { throw FeedSubscriptionError.signInRequired }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        // utils/feed_functions.py requires a string folder name; empty selects the top level.
        var body = "url=\(encodedURL)&folder=\(encodedFolder)"
        if !newFolder.isEmpty { body += "&new_folder=\(encodedNewFolder)" }
        request.httpBody = Data(body.utf8)
        return request
    }

    static func feedID(data: Data, statusCode: Int) throws -> String {
        guard (200..<300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 { throw FeedSubscriptionError.signInRequired }
            throw FeedSubscriptionError.server("NewsBlur could not subscribe right now (HTTP \(statusCode)). Please try again.")
        }
        guard var text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw FeedSubscriptionError.invalidResponse
        }
        // apps/api/views.py add_site wraps its JSON response in parentheses without a callback.
        if text.hasPrefix("("), text.hasSuffix(")") {
            text = String(text.dropFirst().dropLast())
        }
        guard let body = text.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let code = result["code"] as? Int else { throw FeedSubscriptionError.invalidResponse }
        guard code > 0 else {
            let message = result["message"] as? String ?? ""
            throw FeedSubscriptionError.server(message.isEmpty ? "NewsBlur could not subscribe. Open NewsBlur to check your account, then try again." : message)
        }
        let identifier: String
        if let number = result["usersub"] as? Int {
            identifier = String(number)
        } else if let string = result["usersub"] as? String {
            identifier = string
        } else {
            throw FeedSubscriptionError.invalidResponse
        }
        guard let value = Int(identifier), value > 0 else { throw FeedSubscriptionError.invalidResponse }
        return String(value)
    }
}
