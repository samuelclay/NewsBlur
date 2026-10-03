// OnboardingViewController.swift replaces the legacy welcome/category/friends sequence.
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingFolderSummary: Identifiable {
    let name: String
    let feeds: [DiscoverPopularFeed]
    var id: String { name }
    var title: String { name.isEmpty ? "All Site Stories" : name }
}

struct OnboardingImportReceipt {
    let count: Int
    let folders: [OnboardingFolderSummary]
}

@MainActor
final class OnboardingAPI {
    static var session = URLSession.shared
    static func request(_ path: String, body: [String: String]? = nil) async throws -> [String: Any] {
        let base = NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com"
        guard let url = URL(string: base + path) else { throw error("Invalid server address.") }
        var request = URLRequest(url: url)
        request.setValue("NewsBlur iOS", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        }
        return try await send(request)
    }

    static func send(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw error("The server returned an unreadable response. Please try again.")
        }
        // OnboardingViewController.swift keeps social continuation tickets available on HTTP 400.
        if json["link_required"] as? Bool == true || json["username_required"] as? Bool == true { return json }
        guard (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) == true,
              (json["code"] as? Int ?? 1) >= 0 else {
            let errors = json["errors"] as? [String: Any]
            let details = errors?.values.flatMap { ($0 as? [String]) ?? [String(describing: $0)] }.joined(separator: " ")
            throw error(json["message"] as? String ?? details ?? "The request failed. Please try again.")
        }
        return json
    }

    static func error(_ message: String) -> NSError {
        NSError(domain: "NewsBlurOnboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func supportsBatchFeeds() async throws -> Bool {
        let base = NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com"
        guard let url = URL(string: base + "/reader/add_feeds") else { throw error("Invalid server address.") }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw error("The server could not be reached.") }
        if http.statusCode == 404 { return false }
        guard (200...299).contains(http.statusCode) else { throw error("The server could not be reached.") }
        // OnboardingViewController.swift probes without writing because older servers return the reader HTML for unknown routes.
        if http.mimeType == "text/html" { return false }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw error("The server returned an unreadable response.")
        }
        return json["batch_add_supported"] as? Bool == true
    }

    static func addFeedIDs(_ ids: [Int], folder: [String: String]) async throws -> [String: Any]? {
        let base = NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com"
        guard let url = URL(string: base + "/reader/add_feeds") else { throw error("Invalid server address.") }
        var body = folder
        body["feed_ids"] = String(decoding: try JSONEncoder().encode(ids), as: UTF8.self)
        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("NewsBlur iOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        // OnboardingViewController.swift falls back only when the endpoint is absent, never after an ambiguous write failure.
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            throw error("These feeds could not be added. Please try again.")
        }
        return json
    }

    static func importOPML(_ url: URL) async throws -> OnboardingImportReceipt {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 10 * 1024 * 1024 else { throw error("Choose an OPML file smaller than 10 MB.") }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw error("This file is empty. Choose an OPML export from your reader.") }
        let validator = OnboardingOPMLValidator()
        let parser = XMLParser(data: data)
        parser.delegate = validator
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), validator.isOPML else { throw error("This is not a valid OPML file. Choose an OPML export from your reader.") }
        let base = NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com"
        var request = URLRequest(url: URL(string: base + "/import/opml_upload")!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"subscriptions.opml\"\r\nContent-Type: text/xml\r\n\r\n".utf8)
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let json = try await send(request)
        let count = (json["payload"] as? [String: Any])?["feed_count"] as? Int ?? 0
        return OnboardingImportReceipt(count: count, folders: validator.folders.map {
            OnboardingFolderSummary(name: $0.key, feeds: Array($0.value.values))
        })
    }
}

private final class OnboardingOPMLValidator: NSObject, XMLParserDelegate {
    private var hasRoot = false
    var isOPML = false
    private var outlines: [String?] = []
    var folders: [String: [String: DiscoverPopularFeed]] = [:]
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        if !hasRoot { isOPML = elementName.lowercased() == "opml"; hasRoot = true }
        guard elementName.lowercased() == "outline" else { return }
        let title = attributeDict["text"] ?? attributeDict["title"] ?? ""
        if let address = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"] {
            let folder = outlines.compactMap { $0 }.joined(separator: " ▸ ")
            folders[folder, default: [:]][address] = DiscoverPopularFeed(feedId: address, feedDict: [
                "feed_title": title.isEmpty ? (URL(string: address)?.host ?? address) : title,
                "feed_address": address, "feed_link": attributeDict["htmlUrl"] ?? ""
            ])
            outlines.append(nil)
        } else {
            outlines.append(title.isEmpty ? nil : title)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.lowercased() == "outline", !outlines.isEmpty { outlines.removeLast() }
    }
}

@objc final class OnboardingViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private static var dismissedUsernames: Set<String> = []

    @objc static func shouldShow(forUsername username: String?) -> Bool {
        guard let username, !username.isEmpty else { return false }
        return !dismissedUsernames.contains(username) &&
            !UserDefaults.standard.bool(forKey: "onboarding_completed_" + username)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "onboarding-presentation"
        let host = UIHostingController(rootView: OnboardingView(onDismiss: { [weak self] in
            self?.recordDismissal()
            self?.dismiss(animated: true)
        }, onFinish: { [weak self] in
            if let username = NewsBlurAppDelegate.shared()?.activeUsername {
                UserDefaults.standard.set(true, forKey: "onboarding_completed_" + username)
            }
            self?.dismiss(animated: true)
        }))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isModalInPresentation = true
        navigationController?.isModalInPresentation = true
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (navigationController ?? self).presentationController?.delegate = self
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        recordDismissal()
    }

    private func recordDismissal() {
        // OnboardingViewController.swift lets an empty account stay in the reader after closing setup for this session.
        guard let username = NewsBlurAppDelegate.shared()?.activeUsername, !username.isEmpty else { return }
        Self.dismissedUsernames.insert(username)
    }
}

struct OnboardingFeed: Identifiable {
    let preview: DiscoverPopularFeed
    let source: String
    var url: String { preview.feedAddress }
    var title: String { preview.feedTitle }
    var id: String { url }

    @MainActor init?(entry: [String: Any]) {
        guard let preview = DiscoverSitesViewModel.parsePopularFeedEntry(entry) else { return nil }
        self.preview = preview
        source = entry["feed_type"] as? String ?? "rss"
    }

    init(preview: DiscoverPopularFeed) {
        self.preview = preview
        source = "rss"
    }
}

// OnboardingViewController.swift keeps setup progress alive after its sheet is dismissed.
@MainActor @objc final class OnboardingFeedLoading: NSObject, ObservableObject {
    @objc static let shared = OnboardingFeedLoading()
    @Published private(set) var isLoading = false
    @objc var loading: Bool { isLoading }
    private var work: Set<UUID> = []
    private var awaitingRefresh = false

    func beginWork() -> UUID {
        let token = UUID()
        work.insert(token)
        publish()
        return token
    }

    @discardableResult func finishWork(_ token: UUID) -> Bool {
        guard work.remove(token) != nil else { return false }
        requestRefresh()
        return true
    }

    func cancelWork(_ token: UUID) {
        guard work.remove(token) != nil else { return }
        publish()
    }

    func requestRefresh() {
        awaitingRefresh = true
        publish()
    }

    // FeedsObjCViewController.m calls this only after its latest response is rendered, or has failed.
    @objc func refreshDidFinish() {
        awaitingRefresh = false
        publish()
    }

    @objc func reset() {
        work.removeAll()
        awaitingRefresh = false
        publish()
    }

    private func publish() {
        let next = !work.isEmpty || awaitingRefresh
        guard isLoading != next else { return }
        isLoading = next
        NotificationCenter.default.post(name: Notification.Name("OnboardingFeedLoadingChanged"), object: self)
    }
}

@MainActor final class OnboardingBundles: ObservableObject {
    struct FailedBundle: Identifiable {
        let id = UUID()
        let folder: String
        let feeds: [OnboardingFeed]
        var existingFolder = false
    }

    private let onSubscriptionsChanged: () -> Void
    init(onSubscriptionsChanged: @escaping () -> Void = { NewsBlurAppDelegate.shared()?.reloadFeedsView(false) }) {
        self.onSubscriptionsChanged = onSubscriptionsChanged
        recordExistingSubscriptions()
    }
    @Published var interests: [String] = []
    @Published var feeds: [OnboardingFeed] = []
    @Published var selection: Set<String> = []
    @Published var folder = ""
    @Published var busy = false
    @Published var catalogLoading = false
    @Published var message: String?
    @Published var added: Set<String> = []
    @Published private(set) var selectedBundleURLs: [String: Set<String>] = [:]
    @Published private var summaryFeeds: [String: [String: DiscoverPopularFeed]] = [:]
    @Published private var importedURLs: Set<String> = []
    @Published private(set) var alreadySubscribed: Set<String> = []
    @Published var queued: Set<String> = []
    @Published var failedBundles: [FailedBundle] = []
    @Published var icons: [String: [DiscoverPopularFeed]] = [:]
    @Published var iconLoadFailed = false
    @Published var retryingIcons = false
    private var generation = UUID()
    private var candidateTasks: [String: Task<OnboardingCatalogSelector.Selection, Error>] = [:]
    private var candidateCache: [String: OnboardingCatalogSelector.Selection] = [:]
    private var candidateProgress: [String: [[String: Any]]] = [:]
    private var activeCandidateKey: String?
    private lazy var iconLoader = OnboardingIconLoader(base: NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com", session: OnboardingAPI.session)
    private var iconTasks: [String: Task<Void, Never>] = [:]
    private var failedIconKeys: Set<String> = []
    private var subscriptionTask: Task<Void, Never>?
    private var batchEndpointSupported: Bool?
    private var subscribedFeedIDs: Set<String> = []

    var folderSummaries: [OnboardingFolderSummary] {
        let accepted = added.union(queued).union(importedURLs)
        return summaryFeeds.compactMap { name, feeds in
            let included = feeds.values.filter { accepted.contains($0.feedAddress) }
                .sorted { $0.feedTitle.localizedStandardCompare($1.feedTitle) == .orderedAscending }
            return included.isEmpty ? nil : OnboardingFolderSummary(name: name, feeds: included)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var summaryFeedCount: Int {
        Set(folderSummaries.flatMap { $0.feeds.map(\.feedAddress) }).count
    }

    func recordImport(_ receipt: OnboardingImportReceipt) {
        let existing = NewsBlurAppDelegate.shared()?.dictFeeds as? [AnyHashable: [String: Any]] ?? [:]
        let previews = existing.map { DiscoverPopularFeed(feedId: String(describing: $0.key), feedDict: $0.value) }
        for folder in receipt.folders {
            for feed in folder.feeds {
                importedURLs.insert(feed.feedAddress)
                summaryFeeds[folder.name, default: [:]][feed.feedAddress] =
                    previews.first { $0.feedAddress == feed.feedAddress } ?? feed
            }
        }
    }

    func refreshSummaryIcons() async {
        guard !importedURLs.isEmpty else { return }
        let username = NewsBlurAppDelegate.shared()?.activeUsername
        let server = NewsBlurAppDelegate.shared()?.url
        let existing = NewsBlurAppDelegate.shared()?.dictFeeds as? [AnyHashable: [String: Any]] ?? [:]
        let previews = existing.map { DiscoverPopularFeed(feedId: String(describing: $0.key), feedDict: $0.value) }
        // OnboardingViewController.swift reuses the reader refresh and the bounded icon loader for imported sites.
        await withTaskGroup(of: (String, DiscoverPopularFeed)?.self) { group in
            for (folder, feeds) in summaryFeeds {
                for feed in feeds.values where feed.faviconData?.isEmpty != false {
                    guard let canonical = previews.first(where: { $0.feedAddress == feed.feedAddress }) else { continue }
                    group.addTask { [iconLoader] in
                        guard let icon = await iconLoader.image(canonical.id) else { return nil }
                        var data = canonical.rawFeedDict
                        data["favicon"] = icon
                        return (folder, DiscoverPopularFeed(feedId: canonical.id, feedDict: data))
                    }
                }
            }
            for await result in group {
                guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                      server == NewsBlurAppDelegate.shared()?.url else { continue }
                if let (folder, feed) = result { summaryFeeds[folder]?[feed.feedAddress] = feed }
            }
        }
    }

    private func recordExistingSubscriptions() {
        let existing = NewsBlurAppDelegate.shared()?.dictFeeds as? [AnyHashable: [String: Any]] ?? [:]
        for (id, feed) in existing {
            subscribedFeedIDs.insert(String(describing: id))
            if let address = feed["feed_address"] as? String { alreadySubscribed.insert(address) }
        }
    }

    func prepareToRead() {
        OnboardingFeedLoading.shared.requestRefresh()
        onSubscriptionsChanged()
    }

    func loadCatalog() async {
        guard interests.isEmpty, !catalogLoading else { return }
        catalogLoading = true
        message = nil
        defer { catalogLoading = false }
        do {
            let result = try await OnboardingAPI.request("/discover/popular_feeds?type=all&limit=1")
            interests = OnboardingCatalogSelector.canonicalInterests(result["categories"] as? [String] ?? [])
        } catch { message = error.localizedDescription }
    }

    private static func query(interest: String?, source: String, limit: Int, stories: Bool) -> String {
        var query = URLComponents()
        query.queryItems = [URLQueryItem(name: "type", value: source), URLQueryItem(name: "limit", value: String(limit)),
                            URLQueryItem(name: "exclude_subscribed", value: "false"),
                            URLQueryItem(name: "staleness", value: "year"),
                            URLQueryItem(name: "include_stories", value: stories ? "true" : "false")]
        if let interest { query.queryItems?.append(URLQueryItem(name: "category", value: interest)) }
        return "/discover/popular_feeds?" + (query.percentEncodedQuery ?? "")
    }

    func loadIcons(_ interest: String?) async {
        let key = interest ?? ""
        guard (icons[key]?.count ?? 0) < 5 else { return }
        if let task = iconTasks[key] { await task.value; return }
        let task = Task { await populateIcons(interest) }
        iconTasks[key] = task
        await task.value
        iconTasks[key] = nil
    }

    private func populateIcons(_ interest: String?) async {
        let key = interest ?? ""
        if let candidates = OnboardingIconCatalog.cards[OnboardingIconCatalog.key(for: interest)] {
            let loader = iconLoader
            await withTaskGroup(of: (OnboardingIconCatalog.Feed, String?).self) { group in
                for feed in candidates.prefix(5) {
                    group.addTask { (feed, await loader.image(feed.id)) }
                }
                for await (feed, image) in group { appendIcon(feed, image: image, key: key) }
            }
            // OnboardingViewController.swift requests spares only for missing or duplicate icons.
            for feed in candidates.dropFirst(5).prefix(5) where (icons[key]?.count ?? 0) < 5 {
                appendIcon(feed, image: await loader.image(feed.id), key: key)
            }
        } else {
            do {
                let pool = try await candidatePool(for: interest)
                icons[key] = pool.icons.compactMap(DiscoverSitesViewModel.parsePopularFeedEntry)
            } catch { /* OnboardingViewController.swift exposes the failed category through Retry icons. */ }
        }
        if (icons[key]?.count ?? 0) < 5 { failedIconKeys.insert(key) }
        else { failedIconKeys.remove(key) }
        iconLoadFailed = !failedIconKeys.isEmpty
    }

    private func appendIcon(_ feed: OnboardingIconCatalog.Feed, image: String?, key: String) {
        guard (icons[key]?.count ?? 0) < 5, let image,
              let fingerprint = OnboardingCatalogSelector.iconFingerprint(image),
              !(icons[key] ?? []).contains(where: { $0.id == feed.id || $0.faviconData.flatMap(OnboardingCatalogSelector.iconFingerprint) == fingerprint }),
              let preview = DiscoverSitesViewModel.parsePopularFeedEntry(feed.entry(favicon: image)) else { return }
        icons[key, default: []].append(preview)
    }

    func retryIcons() async {
        guard !retryingIcons else { return }
        retryingIcons = true
        defer { retryingIcons = false }
        iconLoader = OnboardingIconLoader(base: NewsBlurAppDelegate.shared()?.url ?? "https://www.newsblur.com", session: OnboardingAPI.session)
        for key in failedIconKeys { await loadIcons(key.isEmpty ? nil : key) }
    }

    func load(_ interest: String? = nil) async {
        let current = UUID()
        let key = OnboardingIconCatalog.key(for: interest)
        generation = current
        activeCandidateKey = key
        busy = true
        message = nil
        feeds = []
        selection = []
        folder = interest.map(OnboardingCatalogSelector.displayTitle) ?? "My Favorites"
        defer { if generation == current { busy = false } }
        appendCandidateCards(candidateProgress[key] ?? [], for: key)
        do {
            let pool = try await withTaskCancellationHandler {
                try await candidatePool(for: interest)
            } onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, generation == current else { return }
                    generation = UUID()
                    activeCandidateKey = nil
                    busy = false
                }
            }
            guard generation == current, !Task.isCancelled else { return }
            appendCandidateCards(pool.feeds, for: key)
            icons[interest ?? ""] = pool.icons.compactMap(DiscoverSitesViewModel.parsePopularFeedEntry)
        } catch { if generation == current { message = error.localizedDescription } }
    }

    private func appendCandidateCards(_ entries: [[String: Any]], for key: String) {
        var retained = candidateProgress[key] ?? []
        var seen = Set(retained.map(OnboardingCatalogSelector.address))
        retained.append(contentsOf: entries.filter { seen.insert(OnboardingCatalogSelector.address($0)).inserted }.prefix(max(0, 15 - retained.count)))
        candidateProgress[key] = retained
        guard activeCandidateKey == key else { return }
        let visible = Set(feeds.map(\.url))
        let additional = retained.compactMap(OnboardingFeed.init(entry:)).filter { !visible.contains($0.url) }
        recordExistingSubscriptions()
        alreadySubscribed.formUnion(additional.filter { subscribedFeedIDs.contains($0.preview.id) }.map(\.url))
        // OnboardingViewController.swift only selects newly arriving cards, preserving every existing user choice.
        selection.formUnion(Set(additional.map(\.url)).subtracting(added).subtracting(queued).subtracting(alreadySubscribed))
        feeds.append(contentsOf: additional)
    }

    private func candidatePool(for interest: String?) async throws -> OnboardingCatalogSelector.Selection {
        let key = OnboardingIconCatalog.key(for: interest)
        if let cached = candidateCache[key] { return cached }
        if let task = candidateTasks[key] { return try await task.value }
        let task = Task { [self] in
            var entries: [[String: Any]] = []
            var lastError: Error?
            // OnboardingViewController.swift reserves three slots per source while five requests run together.
            await withTaskGroup(of: Result<[String: Any], Error>.self) { group in
                for source in ["rss", "newsletter", "youtube", "reddit", "podcast"] {
                    let path = Self.query(interest: interest.map(OnboardingCatalogSelector.canonicalInterest), source: source, limit: 20, stories: true)
                    group.addTask {
                        do { return .success(try await OnboardingAPI.request(path)) }
                        catch { return .failure(error) }
                    }
                }
                for await response in group {
                    switch response {
                    case .success(let result):
                        if interests.isEmpty { interests = OnboardingCatalogSelector.canonicalInterests(result["categories"] as? [String] ?? []) }
                        let incoming = result["feeds"] as? [[String: Any]] ?? []
                        entries.append(contentsOf: incoming)
                        let validated = await Task.detached(priority: .userInitiated) {
                            OnboardingCatalogSelector.select(incoming, interest: interest).feeds
                        }.value
                        appendCandidateCards(Array(validated.prefix(3)), for: key)
                    case .failure(let error): lastError = error
                    }
                }
            }
            var pool = await Task.detached(priority: .userInitiated) { OnboardingCatalogSelector.select(entries, interest: interest) }.value
            if pool.icons.count < 5 {
                let categories: [String?] = interest.map { OnboardingCatalogSelector.categoryAliases(for: $0).map(Optional.some) } ?? [nil]
                for category in categories {
                    do {
                        let result = try await OnboardingAPI.request(Self.query(interest: category, source: "all", limit: 80, stories: true))
                        entries.append(contentsOf: result["feeds"] as? [[String: Any]] ?? [])
                    } catch { lastError = error }
                }
                pool = await Task.detached(priority: .userInitiated) { OnboardingCatalogSelector.select(entries, interest: interest) }.value
            }
            if pool.icons.count < 5 {
                entries = await hydrateMissingIcons(in: entries)
                pool = await Task.detached(priority: .userInitiated) { OnboardingCatalogSelector.select(entries, interest: interest) }.value
            }
            guard pool.icons.count >= 5 else {
                throw lastError ?? OnboardingAPI.error("These feeds aren’t ready yet. Please try again.")
            }
            appendCandidateCards(pool.feeds, for: key)
            pool.feeds = candidateProgress[key] ?? pool.feeds
            return pool
        }
        candidateTasks[key] = task
        do {
            let result = try await task.value
            candidateCache[key] = result
            candidateTasks[key] = nil
            return result
        } catch {
            candidateTasks[key] = nil
            throw error
        }
    }

    private func hydrateMissingIcons(in entries: [[String: Any]]) async -> [[String: Any]] {
        let missing = await Task.detached(priority: .utility) {
            entries.indices.filter {
                OnboardingCatalogSelector.hasEnglishStories(entries[$0]) &&
                OnboardingCatalogSelector.hasRecentStories(entries[$0]) &&
                OnboardingCatalogSelector.favicon(entries[$0]).flatMap(OnboardingCatalogSelector.iconFingerprint) == nil &&
                !(entries[$0]["thumbnail_url"] as? String ?? "").isEmpty
            }.prefix(12)
        }.value
        var hydrated = entries
        for index in missing {
            guard let address = entries[index]["thumbnail_url"] as? String, let url = URL(string: address),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { continue }
            do {
                let (data, response) = try await OnboardingAPI.session.data(for: URLRequest(url: url, timeoutInterval: 5))
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 2_000_000 else { continue }
                let encoded = data.base64EncodedString()
                guard await Task.detached(priority: .utility, operation: { OnboardingCatalogSelector.iconFingerprint(encoded) }).value != nil else { continue }
                var feed = hydrated[index]["feed"] as? [String: Any] ?? hydrated[index]
                feed["favicon"] = encoded
                hydrated[index]["feed"] = feed
            } catch { continue }
        }
        return hydrated
    }

    // OnboardingViewController.swift captures the selection before starting work so another bundle is independent.
    @discardableResult
    func queueSubscriptions(interest: String? = nil) -> Task<Void, Never>? {
        let destination = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = feeds.filter { selection.contains($0.url) && !queued.contains($0.url) && !added.contains($0.url) && !alreadySubscribed.contains($0.url) }
        guard !chosen.isEmpty, !destination.isEmpty else { return nil }
        selectedBundleURLs[interest ?? "", default: []].formUnion(chosen.map(\.url))
        return enqueue(chosen, into: destination, selectionGeneration: generation)
    }

    func categoryStatus(_ interest: String?) -> String? {
        let urls = selectedBundleURLs[interest ?? ""] ?? []
        let completed = urls.intersection(added).count
        let pending = urls.intersection(queued).count
        let count = completed + pending
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? "feed" : "feeds") \(pending > 0 ? "selected" : "added")"
    }

    func subscribe() async {
        await queueSubscriptions()?.value
    }

    func retry(_ failure: FailedBundle) {
        failedBundles.removeAll { $0.id == failure.id }
        let chosen = failure.feeds.filter { !queued.contains($0.url) && !added.contains($0.url) }
        guard !chosen.isEmpty else { return }
        _ = enqueue(chosen, into: failure.folder, selectionGeneration: generation, existingFolder: failure.existingFolder)
    }

    @discardableResult
    func queueSearchResult(_ feed: DiscoverPopularFeed, folder: String) -> Task<Void, Never>? {
        guard !queued.contains(feed.feedAddress), !added.contains(feed.feedAddress), !alreadySubscribed.contains(feed.feedAddress) else { return nil }
        return enqueue([OnboardingFeed(preview: feed)], into: folder, selectionGeneration: generation, existingFolder: true)
    }

    private func enqueue(_ chosen: [OnboardingFeed], into destination: String, selectionGeneration: UUID,
                         existingFolder: Bool = false) -> Task<Void, Never> {
        let username = NewsBlurAppDelegate.shared()?.activeUsername
        let server = NewsBlurAppDelegate.shared()?.url
        let previous = subscriptionTask
        let chosenURLs = Set(chosen.map(\.url))
        for feed in chosen { summaryFeeds[destination, default: [:]][feed.url] = feed.preview }
        failedBundles = failedBundles.compactMap { failure in
            let remaining = failure.feeds.filter { !chosenURLs.contains($0.url) }
            return remaining.isEmpty ? nil : FailedBundle(folder: failure.folder, feeds: remaining, existingFolder: failure.existingFolder)
        }
        queued.formUnion(chosenURLs)
        selection.subtract(chosenURLs)
        message = nil
        let loadingToken = OnboardingFeedLoading.shared.beginWork()
        let task = Task { [self] in
            await previous?.value
            var failures: [OnboardingFeed] = []
            var successes = 0
            var individual = chosen
            let known = chosen.filter { (Int($0.preview.id) ?? 0) > 0 }
            if !known.isEmpty {
                guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                      server == NewsBlurAppDelegate.shared()?.url else {
                    queued.subtract(chosenURLs)
                    OnboardingFeedLoading.shared.cancelWork(loadingToken)
                    return
                }
                do {
                    if batchEndpointSupported == nil { batchEndpointSupported = try await OnboardingAPI.supportsBatchFeeds() }
                    let path = existingFolder && !destination.isEmpty ? destination.components(separatedBy: " ▸ ") : []
                    var body = ["folder_path": String(decoding: try JSONEncoder().encode(path), as: UTF8.self)]
                    if !existingFolder { body["new_folder"] = destination }
                    if batchEndpointSupported == true,
                       let response = try await OnboardingAPI.addFeedIDs(known.compactMap { Int($0.preview.id) }, folder: body) {
                        guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                              server == NewsBlurAppDelegate.shared()?.url else {
                            queued.subtract(chosenURLs)
                            OnboardingFeedLoading.shared.cancelWork(loadingToken)
                            return
                        }
                        let results = response["results"] as? [[String: Any]] ?? []
                        let successfulIDs = Set(results.filter { ($0["code"] as? Int ?? -1) == 1 }.compactMap { $0["feed_id"] as? Int })
                        for feed in known {
                            if Int(feed.preview.id).map(successfulIDs.contains) == true {
                                added.insert(feed.url)
                                successes += 1
                            } else { failures.append(feed) }
                            queued.remove(feed.url)
                        }
                        let knownURLs = Set(known.map(\.url))
                        individual.removeAll { knownURLs.contains($0.url) }
                    }
                } catch {
                    failures.append(contentsOf: known)
                    let knownURLs = Set(known.map(\.url))
                    queued.subtract(knownURLs)
                    individual.removeAll { knownURLs.contains($0.url) }
                }
            }
            for feed in individual {
                // OnboardingViewController.swift never continues queued subscriptions in another account.
                guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                      server == NewsBlurAppDelegate.shared()?.url else {
                    queued.subtract(chosenURLs)
                    OnboardingFeedLoading.shared.cancelWork(loadingToken)
                    return
                }
                do {
                    let body: [String: String]
                    if existingFolder {
                        let path = destination.isEmpty ? [] : destination.components(separatedBy: " ▸ ")
                        body = ["url": feed.url, "folder_path": String(decoding: try JSONEncoder().encode(path), as: UTF8.self)]
                    } else {
                        body = ["url": feed.url, "new_folder": destination, "folder_path": "[]"]
                    }
                    _ = try await OnboardingAPI.request("/reader/add_url", body: body)
                    guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                          server == NewsBlurAppDelegate.shared()?.url else {
                        queued.subtract(chosenURLs)
                        OnboardingFeedLoading.shared.cancelWork(loadingToken)
                        return
                    }
                    added.insert(feed.url)
                    successes += 1
                } catch { failures.append(feed) }
                queued.remove(feed.url)
            }
            guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                  server == NewsBlurAppDelegate.shared()?.url else {
                OnboardingFeedLoading.shared.cancelWork(loadingToken)
                return
            }
            if !failures.isEmpty {
                failedBundles.append(FailedBundle(folder: destination, feeds: failures, existingFolder: existingFolder))
                if generation == selectionGeneration { selection.formUnion(failures.map(\.url)) }
            }
            if generation == selectionGeneration {
                message = failures.isEmpty ? "Added \(successes) feeds\(destination.isEmpty ? "" : " to " + destination)."
                    : "Added \(successes) feeds. \(failures.count) could not be added. You can retry them below."
            }
            if OnboardingFeedLoading.shared.finishWork(loadingToken) { onSubscriptionsChanged() }
        }
        subscriptionTask = task
        return task
    }
}

// OnboardingViewController.swift gives the initial catalog request one calm, full-width loading state.
private actor OnboardingIconLoader {
    private let base: String
    private let session: URLSession
    private var tasks: [String: Task<String?, Never>] = [:]
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(base: String, session: URLSession) { self.base = base; self.session = session }

    // OnboardingViewController.swift shares requests within a presentation and caps live downloads at eight.
    func image(_ id: String) async -> String? {
        if let task = tasks[id] { return await task.value }
        let task = Task<String?, Never> {
            await acquire()
            defer { release() }
            var components = URLComponents(string: base + "/reader/favicons")!
            components.queryItems = [URLQueryItem(name: "feed_ids", value: id)]
            var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("NewsBlur iOS", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let image = json[id] as? String,
                  OnboardingCatalogSelector.iconFingerprint(image) != nil else { return nil }
            return image
        }
        tasks[id] = task
        return await task.value
    }

    private func acquire() async {
        if active < 8 { active += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty { active -= 1 }
        else { waiting.removeFirst().resume() }
    }
}

private struct OnboardingCatalogLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(DiscoverColors.cardBackground.opacity(0.5)).frame(width: 116, height: 116)
                Circle().stroke(DiscoverColors.textSecondary.opacity(0.1), lineWidth: 2)
                Circle().trim(from: 0, to: 0.24)
                    .stroke(DiscoverColors.textSecondary.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 2.4).repeatForever(autoreverses: false), value: rotating)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(DiscoverColors.textSecondary.opacity(0.7))
            }.frame(width: 88, height: 88).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Loading interests").font(.title3.weight(.medium))
                Text("Finding feeds for you to explore.")
                    .font(.subheadline).foregroundStyle(DiscoverColors.textSecondary)
            }.multilineTextAlignment(.center)
        }
        .padding(32).frame(maxWidth: .infinity, minHeight: 320)
        .background(DiscoverColors.cardBackground.opacity(0.28), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.catalogLoading")
        .onAppear { rotating = true }
    }
}

private struct OnboardingView: View {
    let onDismiss: () -> Void
    let onFinish: () -> Void
    @StateObject private var bundles = OnboardingBundles()
    @StateObject private var discovery = DiscoverSitesViewModel(session: OnboardingAPI.session)
    @State private var step = 0
    @State private var showImporter = false
    @State private var importing = false
    @State private var importMessage: String?
    @State private var selectedInterest: String?
    @State private var interestSearch = ""
    @State private var showBundle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .headline) private var cardHeight = 164.0
    private let contentWidth: CGFloat = 760
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)] }
    private var query: String { interestSearch.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matchingInterests: [String] {
        bundles.interests.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            DiscoverColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if step == 0 {
                        importPage
                        discoveryPage
                    } else {
                        finishedPage
                    }
                }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
                    .frame(maxWidth: contentWidth).frame(maxWidth: .infinity)
            }.id(step)
                .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if step == 0 {
                    Button("Continue") { showCompletion() }
                        .buttonStyle(OnboardingPrimaryButton())
                } else {
                    Button("Start reading") {
                        bundles.prepareToRead()
                        onFinish()
                    }.buttonStyle(OnboardingPrimaryButton())
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity).background(DiscoverColors.background)
        }
        .foregroundColor(DiscoverColors.textPrimary)
        .onAppear { NewsBlurAppDelegate.shared()?.feedsViewController.syncNotifier?.isPresentationSuppressed = true }
        .onDisappear { NewsBlurAppDelegate.shared()?.feedsViewController.syncNotifier?.isPresentationSuppressed = false }
        .onChange(of: bundles.added) { discovery.addedFeedURLs.formUnion($0) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FinishedLoadingFeedsNotification"))) { _ in
            Task { await bundles.refreshSummaryIcons() }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml, .xml, .data]) { result in
            switch result {
            case .success(let url):
                let username = NewsBlurAppDelegate.shared()?.activeUsername
                let server = NewsBlurAppDelegate.shared()?.url
                let loadingToken = OnboardingFeedLoading.shared.beginWork()
                importing = true
                importMessage = nil
                Task {
                    do {
                        let receipt = try await OnboardingAPI.importOPML(url)
                        importMessage = "\(receipt.count) feeds queued for import. Your folders come along too. You can keep going while NewsBlur imports them."
                        if username == NewsBlurAppDelegate.shared()?.activeUsername,
                           server == NewsBlurAppDelegate.shared()?.url {
                            bundles.recordImport(receipt)
                            if OnboardingFeedLoading.shared.finishWork(loadingToken) { bundles.prepareToRead() }
                        } else { OnboardingFeedLoading.shared.cancelWork(loadingToken) }
                    } catch {
                        importMessage = error.localizedDescription
                        OnboardingFeedLoading.shared.cancelWork(loadingToken)
                    }
                    importing = false
                }
            case .failure(let error): importMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(uiImage: UIImage(named: "logo_512.png") ?? UIImage(systemName: "sun.max.fill")!)
                    .resizable().frame(width: 36, height: 36)
                Text("NewsBlur").font(.title3.bold())
                Spacer(minLength: 8)
                Text("\(step + 1) / 2").font(.subheadline.monospacedDigit())
                    .foregroundStyle(DiscoverColors.textSecondary)
                Button {
                    bundles.prepareToRead()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(DiscoverColors.cardBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close import and discovery")
            }
            HStack(spacing: 6) {
                ForEach(0..<2) { index in
                    Capsule().fill(index <= step ? DiscoverColors.textSecondary : DiscoverColors.border.opacity(0.5)).frame(height: 3)
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)
        .frame(maxWidth: contentWidth).frame(maxWidth: .infinity)
        .background(DiscoverColors.background)
    }

    private func showCompletion() {
        step = 1
        bundles.prepareToRead()
    }

    private var importPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    importDescription.fixedSize()
                    Spacer(minLength: 0)
                    importButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    importDescription
                    importButton
                }
            }
            if importing { ProgressView("Uploading your feeds…") }
            if let importMessage { Text(importMessage).font(.subheadline).accessibilityIdentifier("onboarding.import.status") }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscoverColors.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }

    private var importDescription: some View {
        HStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(DiscoverColors.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Already have feeds?").font(.headline)
                Text("Bring your feeds and folders from another reader.")
                    .font(.subheadline).foregroundStyle(DiscoverColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var importButton: some View {
        Button("Import OPML") { showImporter = true }
            .font(.subheadline.weight(.semibold)).buttonStyle(.plain)
            .padding(.horizontal, 16).frame(height: 44)
            .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DiscoverColors.border, lineWidth: 1))
            .fixedSize().disabled(importing)
    }

    private var discoveryPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            discoveryHeader
            if bundles.iconLoadFailed {
                HStack(spacing: 10) {
                    Text("Some feed icons couldn’t load.").foregroundStyle(DiscoverColors.textSecondary)
                    Spacer(minLength: 0)
                    if bundles.retryingIcons { ProgressView() }
                    Button("Retry icons") { Task { await bundles.retryIcons() } }
                        .disabled(bundles.retryingIcons)
                }.font(.subheadline)
            }
            if bundles.catalogLoading && bundles.interests.isEmpty { OnboardingCatalogLoader() }
            if let message = bundles.message, bundles.interests.isEmpty {
                Text(message).font(.subheadline)
                Button("Try again") { Task { await bundles.loadCatalog() } }
            }
            LazyVGrid(columns: columns, spacing: 16) {
                if query.isEmpty && !bundles.interests.isEmpty { bundleCard("A little of everything", interest: nil, symbol: "sparkles") }
                ForEach(matchingInterests, id: \.self) { interest in
                    bundleCard(OnboardingCatalogSelector.displayTitle(interest), interest: interest, symbol: bundleSymbol(interest))
                }
            }
            if !query.isEmpty { searchResults }
            subscriptionStatus
            if !bundles.added.isEmpty {
                Label("\(bundles.added.count) feeds added.", systemImage: "checkmark.circle.fill").foregroundColor(DiscoverColors.textSecondary)
            }
        }
        .task { await bundles.loadCatalog() }
        .sheet(isPresented: $showBundle) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Choose feeds for your folder").font(.title.bold())
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill").foregroundStyle(DiscoverColors.textSecondary)
                                .accessibilityHidden(true)
                            TextField("Folder name", text: $bundles.folder).font(.title3.bold())
                                .submitLabel(.done)
                                .accessibilityLabel("Bundle folder name")
                                .accessibilityIdentifier("onboarding.bundleFolder")
                        }.padding(16)
                            .background(DiscoverColors.textFieldBackground, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DiscoverColors.border, lineWidth: 1))
                        ForEach(bundles.feeds) { feed in
                            DiscoverFeedCardView(feed: feed.preview, showStories: true, selection: Binding(
                                get: { bundles.selection.contains(feed.url) },
                                set: { selected in
                                    if selected { bundles.selection.insert(feed.url) }
                                    else { bundles.selection.remove(feed.url) }
                                }), selectionStatus: bundles.added.contains(feed.url) || bundles.alreadySubscribed.contains(feed.url) ? "Added" : bundles.queued.contains(feed.url) ? "Queued" : nil)
                            .environmentObject(discovery)
                        }
                        if bundles.busy {
                            HStack(spacing: 14) {
                                ProgressView().tint(DiscoverColors.textSecondary)
                                Text(bundles.feeds.isEmpty ? "Loading feeds to choose from…" : "Loading more feeds…").font(.subheadline)
                                    .foregroundStyle(DiscoverColors.textSecondary)
                                Spacer(minLength: 0)
                            }.padding(24).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                                .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityIdentifier("onboarding.bundleLoading")
                        }
                        if !bundles.busy && bundles.feeds.isEmpty {
                            Text("No feeds to show yet. Try another interest or search all sites.")
                            Button("Try again") { Task { await bundles.load(selectedInterest) } }
                        }
                        if let message = bundles.message { Text(message).font(.subheadline) }
                        subscriptionStatus
                    }.padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(DiscoverColors.background)
                .safeAreaInset(edge: .bottom) {
                    if !bundles.busy || !bundles.feeds.isEmpty {
                        Button(bundleActionTitle) {
                            if bundles.queueSubscriptions(interest: selectedInterest) != nil { showBundle = false }
                        }
                            .accessibilityIdentifier("onboarding.addBundle")
                            .buttonStyle(OnboardingPrimaryButton()).padding().background(DiscoverColors.background)
                            .disabled(bundles.selection.isEmpty || bundles.folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationTitle(selectedInterest.map(OnboardingCatalogSelector.displayTitle) ?? "A little of everything").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBundle = false } } }
            }.foregroundColor(DiscoverColors.textPrimary).interactiveDismissDisabled()
        }
    }

    private var bundleActionTitle: String {
        let count = bundles.selection.count
        let folder = bundles.folder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard count > 0 else { return "Select feeds to add" }
        guard !folder.isEmpty else { return "Name your folder to continue" }
        return "Add \(count) \(count == 1 ? "feed" : "feeds") to “\(folder)” folder"
    }

    private var discoveryHeader: some View {
        HStack(spacing: 16) {
            if !searchFocused || horizontalSizeClass == .regular {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore interests").font(.title2.weight(.semibold))
                        .fixedSize(horizontal: true, vertical: false)
                    if !bundles.interests.isEmpty {
                        Text("\(bundles.interests.count) categories to choose from")
                            .font(.caption).foregroundStyle(DiscoverColors.textSecondary)
                    }
                }.accessibilityIdentifier("onboarding.categoryHeading")
            }
            Spacer(minLength: 0)
            searchField.frame(maxWidth: searchFocused ? .infinity : 240)
        }
    }

    private var searchField: some View {

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(DiscoverColors.textSecondary)
            TextField("", text: $interestSearch)
                .focused($searchFocused)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).accessibilityLabel("Search interests and sites")
                .onChange(of: interestSearch) { discovery.searchAutocomplete(query: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if !interestSearch.isEmpty {
                Button { interestSearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(DiscoverColors.textSecondary).accessibilityLabel("Clear search")
            }
        }.padding(.horizontal, 14).frame(minWidth: 76).frame(height: 44)
            .background(DiscoverColors.textFieldBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DiscoverColors.border, lineWidth: 1))
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !discovery.searchState.isSearching && !discovery.searchState.results.isEmpty {
                Text("Sites").font(.headline).foregroundStyle(DiscoverColors.textSecondary)
                ForEach(discovery.searchState.results) { result in
                    let feed = DiscoverPopularFeed(autocompleteResult: result)
                    if bundles.queued.contains(feed.feedAddress) {
                        Label("Adding \(feed.feedTitle)…", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        DiscoverFeedCardView(feed: feed, onAddFeed: { feed in
                            bundles.queueSearchResult(feed, folder: discovery.selectedFolder)
                        }).environmentObject(discovery)
                    }
                }
            }
            if discovery.searchState.isSearching { ProgressView("Searching sites…") }
            if let error = discovery.searchState.errorMessage {
                Text(error).font(.subheadline).foregroundStyle(DiscoverColors.errorText)
                Button("Try search again") { discovery.searchAutocomplete(query: query) }
            } else if !discovery.searchState.isSearching && discovery.searchState.results.isEmpty && matchingInterests.isEmpty {
                Text("No interests or sites found. Try another search.").foregroundStyle(DiscoverColors.textSecondary)
            }
        }
    }

    private var subscriptionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(bundles.failedBundles) { failure in
                HStack {
                    Text("\(failure.feeds.count) feeds couldn’t be added\(failure.folder.isEmpty ? "" : " to " + failure.folder).")
                    Spacer()
                    Button("Retry") { bundles.retry(failure) }
                }.font(.subheadline)
            }
        }
    }

    private func bundleCard(_ title: String, interest: String?, symbol: String) -> some View {
        let status = bundles.categoryStatus(interest)
        let highlight = DiscoverColors.themedColor(light: 0x3B6863, sepia: 0x3B6863, medium: 0xA3CBC3, dark: 0xA3CBC3)
        return Button {
            selectedInterest = interest
            showBundle = true
            Task { await bundles.load(interest) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: symbol).font(.system(size: 23, weight: .regular))
                        .foregroundStyle(DiscoverColors.textSecondary).frame(width: 30)
                        .accessibilityHidden(true)
                    Text(interest == nil ? title : title.localizedCapitalized).font(.headline).foregroundColor(DiscoverColors.textPrimary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach((bundles.icons[interest ?? ""] ?? []).prefix(5)) { feed in
                        DiscoverFeedIconView(feed: feed)
                            .frame(width: 28, height: 28).padding(3)
                            .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 9))
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            .accessibilityHidden(true)
                    }
                    ForEach(0..<max(0, 5 - (bundles.icons[interest ?? ""]?.count ?? 0)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 7).fill(DiscoverColors.border.opacity(0.45))
                            .frame(width: 28, height: 28).padding(3).accessibilityHidden(true)
                    }
                }.frame(height: 34, alignment: .leading)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: bundles.icons[interest ?? ""]?.count ?? 0)
                Label(status ?? " ", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(highlight)
                    .opacity(status == nil ? 0 : 1).accessibilityHidden(status == nil)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).frame(height: cardHeight, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: 16).fill(DiscoverColors.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 16).fill(status == nil ? Color.clear : highlight.opacity(0.1)))
                }
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(status == nil ? DiscoverColors.border.opacity(0.45) : highlight.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.interest.\(interest ?? "all")")
        .accessibilityValue(status ?? (bundles.icons[interest ?? ""].map { "\($0.count) sources" } ?? "Loading sources"))
        .task { await bundles.loadIcons(interest) }
    }

    private func bundleSymbol(_ interest: String) -> String {
        let name = interest.lowercased()
        for (word, symbol) in [("tech", "cpu"), ("science", "atom"), ("food", "fork.knife"), ("design", "paintpalette"),
                               ("travel", "globe.americas"), ("music", "music.note"), ("sport", "figure.run"),
                               ("news", "newspaper"), ("art", "paintbrush.pointed"), ("business", "chart.line.uptrend.xyaxis"),
                               ("game", "gamecontroller"), ("book", "books.vertical"), ("nature", "leaf"), ("space", "moon.stars"),
                               ("architecture", "building.2"), ("agriculture", "leaf"), ("autom", "car"),
                               ("career", "briefcase"), ("comedy", "theatermasks"), ("anime", "sparkles")] {
            if name.contains(word) { return symbol }
        }
        return "square.stack.3d.up"
    }

    private var completionAccent: Color {
        DiscoverColors.themedColor(light: 0x3B6863, sepia: 0x3B6863, medium: 0xA3CBC3, dark: 0xA3CBC3)
    }

    private var finishedPage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(completionAccent.opacity(0.05)).frame(width: 108, height: 108)
                    Circle().fill(completionAccent.opacity(0.1)).frame(width: 82, height: 82)
                    Image(systemName: "checkmark").font(.system(size: 30, weight: .medium))
                        .foregroundStyle(completionAccent)
                }.accessibilityHidden(true)
                Text("You’re all set up.").font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(bundles.summaryFeedCount == 0
                     ? "Your reader is ready. Add feeds anytime from Add + Discover Sites."
                     : "A reading list that’s yours. Everything you chose, in one place.")
                    .font(.body).foregroundStyle(DiscoverColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 8)

            if !bundles.folderSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your reading list").font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(bundles.summaryFeedCount) \(bundles.summaryFeedCount == 1 ? "feed" : "feeds")")
                            .font(.subheadline.weight(.medium)).foregroundStyle(completionAccent)
                    }
                    ForEach(bundles.folderSummaries) { folder in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: folder.name.isEmpty ? "globe" : "folder.fill")
                                    .foregroundStyle(completionAccent)
                                Text(folder.title).font(.headline)
                                Spacer(minLength: 8)
                                Text("\(folder.feeds.count)").font(.caption.monospacedDigit())
                                    .foregroundStyle(DiscoverColors.textSecondary)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 36), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(folder.feeds, id: \.feedAddress) { feed in
                                    completionFeedIcon(feed)
                                        .frame(width: 36, height: 36)
                                        .background(DiscoverColors.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                                        .accessibilityLabel(feed.feedTitle)
                                }
                            }
                            Text(folder.feeds.map(\.feedTitle).joined(separator: " · "))
                                .font(.caption).foregroundStyle(DiscoverColors.textSecondary)
                                .lineLimit(2)
                        }.accessibilityElement(children: .combine)
                            .accessibilityIdentifier("onboarding.summary.folder.\(folder.name)")
                    }
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityIdentifier("onboarding.summary")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Stay connected").font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiscoverColors.textSecondary).padding(.horizontal, 4)
                VStack(spacing: 0) {
                    completionLink(title: "NewsBlur Forum", subtitle: "Ask questions and share ideas", destination: "https://forum.newsblur.com", avatar: nil)
                    Divider().padding(.leading, 80)
                    completionLink(title: "@samuelclay on X", subtitle: "From the creator of NewsBlur", destination: "https://x.com/samuelclay", avatar: "onboarding-samuel")
                    Divider().padding(.leading, 80)
                    completionLink(title: "@NewsBlur on X", subtitle: "News and updates", destination: "https://x.com/NewsBlur", avatar: "logo_512.png")
                }.background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 22))
            }
            subscriptionStatus
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func completionFeedIcon(_ feed: DiscoverPopularFeed) -> some View {
        if feed.faviconData?.isEmpty == false || feed.faviconUrl?.isEmpty == false {
            DiscoverFeedIconView(feed: feed).frame(width: 24, height: 24)
        } else {
            Text(String(feed.feedTitle.prefix(1)).uppercased()).font(.headline)
                .foregroundStyle(completionAccent)
        }
    }

    private func completionLink(title: String, subtitle: String, destination: String, avatar: String?) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 16) {
                Group {
                    if let avatar {
                        Image(uiImage: UIImage(named: avatar)!)
                            .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                            .overlay(alignment: .bottomTrailing) {
                                Image("onboarding-x").resizable().scaledToFit().frame(width: 10, height: 10)
                                    .padding(4).background(DiscoverColors.cardBackground, in: Circle())
                                    .foregroundStyle(DiscoverColors.textPrimary).offset(x: 3, y: 3)
                            }
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 21))
                            .foregroundStyle(completionAccent).frame(width: 44, height: 44)
                            .background(completionAccent.opacity(0.1), in: Circle())
                    }
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(DiscoverColors.textPrimary)
                    Text(subtitle).font(.subheadline).foregroundStyle(DiscoverColors.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiscoverColors.textSecondary).accessibilityHidden(true)
            }.padding(20).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
    }

}

struct OnboardingPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
            .foregroundColor(.white).background(Color(red: 0.25, green: 0.40, blue: 0.39).opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
