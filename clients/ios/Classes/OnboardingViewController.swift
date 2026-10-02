// OnboardingViewController.swift replaces the legacy welcome/category/friends sequence.
import SwiftUI
import UniformTypeIdentifiers

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

    static func importOPML(_ url: URL) async throws -> Int {
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
        return (json["payload"] as? [String: Any])?["feed_count"] as? Int ?? 0
    }
}

private final class OnboardingOPMLValidator: NSObject, XMLParserDelegate {
    private var hasRoot = false
    var isOPML = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        if !hasRoot { isOPML = elementName.lowercased() == "opml"; hasRoot = true }
    }
}

@objc final class OnboardingViewController: UIViewController {
    @objc static func shouldShow(forUsername username: String?) -> Bool {
        guard let username, !username.isEmpty else { return false }
        return !UserDefaults.standard.bool(forKey: "onboarding_completed_" + username)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: OnboardingView(onDiscover: { [weak self] in
            let discover = DiscoverSitesViewController()
            self?.navigationController?.pushViewController(discover, animated: true)
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
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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
    }

    private let onSubscriptionsChanged: () -> Void
    init(onSubscriptionsChanged: @escaping () -> Void = { NewsBlurAppDelegate.shared()?.reloadFeedsView(false) }) {
        self.onSubscriptionsChanged = onSubscriptionsChanged
    }
    @Published var interests: [String] = []
    @Published var feeds: [OnboardingFeed] = []
    @Published var selection: Set<String> = []
    @Published var folder = ""
    @Published var busy = false
    @Published var catalogLoading = false
    @Published var message: String?
    @Published var added: Set<String> = []
    @Published var queued: Set<String> = []
    @Published var failedBundles: [FailedBundle] = []
    @Published var icons: [String: [DiscoverPopularFeed]] = [:]
    private var generation = UUID()
    private var iconRequests: Set<String> = []
    private var subscriptionTask: Task<Void, Never>?

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
            interests = result["categories"] as? [String] ?? []
        } catch { message = error.localizedDescription }
    }

    private static func query(interest: String?, source: String, limit: Int, stories: Bool) -> String {
        var query = URLComponents()
        query.queryItems = [URLQueryItem(name: "type", value: source), URLQueryItem(name: "limit", value: String(limit)),
                            URLQueryItem(name: "exclude_subscribed", value: "true"),
                            URLQueryItem(name: "include_stories", value: stories ? "true" : "false")]
        if let interest { query.queryItems?.append(URLQueryItem(name: "category", value: interest)) }
        return "/discover/popular_feeds?" + (query.percentEncodedQuery ?? "")
    }

    func loadIcons(_ interest: String?) async {
        let key = interest ?? ""
        guard icons[key] == nil, iconRequests.insert(key).inserted else { return }
        defer { iconRequests.remove(key) }
        var previews: [DiscoverPopularFeed] = []
        // OnboardingViewController.swift requests only visible cards, caching one real feed per source.
        for source in ["rss", "newsletter", "youtube", "reddit", "podcast"] {
            if Task.isCancelled { return }
            do {
                let result = try await OnboardingAPI.request(Self.query(interest: interest, source: source, limit: 1, stories: false))
                for entry in result["feeds"] as? [[String: Any]] ?? [] {
                    if let feed = DiscoverSitesViewModel.parsePopularFeedEntry(entry),
                       !previews.contains(where: { $0.feedAddress == feed.feedAddress }) { previews.append(feed) }
                }
            } catch {
                if Task.isCancelled { return }
            }
        }
        if !previews.isEmpty { icons[key] = previews }
    }

    func load(_ interest: String? = nil) async {
        let current = UUID()
        generation = current
        busy = true
        message = nil
        feeds = []
        selection = []
        folder = interest ?? "My favorites"
        defer { if generation == current { busy = false } }
        do {
            var mixed: [OnboardingFeed] = []
            var seen: Set<String> = []
            // OnboardingViewController.swift balances sources and reuses Discovery's complete story previews.
            for source in ["rss", "newsletter", "youtube", "reddit", "podcast"] {
                let result = try await OnboardingAPI.request(Self.query(interest: interest, source: source, limit: 3, stories: true))
                guard generation == current else { return }
                if interests.isEmpty { interests = result["categories"] as? [String] ?? [] }
                for entry in result["feeds"] as? [[String: Any]] ?? [] {
                    if let feed = OnboardingFeed(entry: entry), seen.insert(feed.url).inserted {
                        mixed.append(feed)
                        if !added.contains(feed.url), !queued.contains(feed.url) { selection.insert(feed.url) }
                    }
                }
                feeds = mixed
            }
            var representedSources: Set<String> = []
            icons[interest ?? ""] = mixed.filter { representedSources.insert($0.source).inserted }.map(\.preview)
        } catch { if generation == current { message = error.localizedDescription } }
    }

    // OnboardingViewController.swift captures the selection before starting work so another bundle is independent.
    @discardableResult
    func queueSubscriptions() -> Task<Void, Never>? {
        let destination = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = feeds.filter { selection.contains($0.url) && !queued.contains($0.url) && !added.contains($0.url) }
        guard !chosen.isEmpty, !destination.isEmpty else { return nil }
        return enqueue(chosen, into: destination, selectionGeneration: generation)
    }

    func subscribe() async {
        await queueSubscriptions()?.value
    }

    func retry(_ failure: FailedBundle) {
        failedBundles.removeAll { $0.id == failure.id }
        let chosen = failure.feeds.filter { !queued.contains($0.url) && !added.contains($0.url) }
        guard !chosen.isEmpty else { return }
        _ = enqueue(chosen, into: failure.folder, selectionGeneration: generation)
    }

    private func enqueue(_ chosen: [OnboardingFeed], into destination: String, selectionGeneration: UUID) -> Task<Void, Never> {
        let username = NewsBlurAppDelegate.shared()?.activeUsername
        let server = NewsBlurAppDelegate.shared()?.url
        let previous = subscriptionTask
        let chosenURLs = Set(chosen.map(\.url))
        failedBundles = failedBundles.compactMap { failure in
            let remaining = failure.feeds.filter { !chosenURLs.contains($0.url) }
            return remaining.isEmpty ? nil : FailedBundle(folder: failure.folder, feeds: remaining)
        }
        queued.formUnion(chosenURLs)
        selection.subtract(chosenURLs)
        message = nil
        let loadingToken = OnboardingFeedLoading.shared.beginWork()
        let task = Task { [self] in
            await previous?.value
            var failures: [OnboardingFeed] = []
            var successes = 0
            for feed in chosen {
                // OnboardingViewController.swift never continues queued subscriptions in another account.
                guard username == NewsBlurAppDelegate.shared()?.activeUsername,
                      server == NewsBlurAppDelegate.shared()?.url else {
                    queued.subtract(chosenURLs)
                    OnboardingFeedLoading.shared.cancelWork(loadingToken)
                    return
                }
                do {
                    _ = try await OnboardingAPI.request("/reader/add_url", body: [
                        "url": feed.url, "new_folder": destination, "folder_path": "[]"
                    ])
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
                failedBundles.append(FailedBundle(folder: destination, feeds: failures))
                if generation == selectionGeneration { selection.formUnion(failures.map(\.url)) }
            }
            if generation == selectionGeneration {
                message = failures.isEmpty ? "Added \(successes) feeds to \(destination)."
                    : "Added \(successes) feeds. \(failures.count) could not be added. You can retry them below."
            }
            if OnboardingFeedLoading.shared.finishWork(loadingToken) { onSubscriptionsChanged() }
        }
        subscriptionTask = task
        return task
    }
}

private struct OnboardingView: View {
    let onDiscover: () -> Void
    let onFinish: () -> Void
    @StateObject private var bundles = OnboardingBundles()
    @StateObject private var discovery = DiscoverSitesViewModel()
    @ObservedObject private var feedLoading = OnboardingFeedLoading.shared
    @State private var step = 0
    @State private var showImporter = false
    @State private var importing = false
    @State private var importMessage: String?
    @State private var selectedInterest: String?
    @State private var interestSearch = ""
    @State private var showBundle = false
    private let titles = ["Make room for curiosity.", "You’re all set up."]

    var body: some View {
        ZStack {
            DiscoverColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(uiImage: UIImage(named: "logo_512.png") ?? UIImage(systemName: "sun.max.fill")!).resizable().frame(width: 40, height: 40)
                        Text("NewsBlur").font(.title3.bold())
                        Spacer()
                        Text("\(step + 1) / 2").font(.subheadline.monospacedDigit()).foregroundStyle(DiscoverColors.textSecondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(0..<2) { index in Capsule().fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2)).frame(height: 4) }
                    }
                    Text(titles[step]).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    if step == 0 {
                        importPage
                        discoveryPage
                    } else { finishedPage }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.id(step)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if step == 0 {
                    Button("Continue") { showCompletion() }
                        .buttonStyle(OnboardingPrimaryButton())
                    HStack {
                        Spacer()
                        Button("Skip this step") { showCompletion() }
                    }
                } else {
                    if feedLoading.isLoading { loadingIndicator }
                    Button("Start reading") {
                        bundles.prepareToRead()
                        onFinish()
                    }.buttonStyle(OnboardingPrimaryButton())
                    Button("Back to feeds") { step = 0 }
                }
            }.padding(.horizontal, 24).padding(.vertical, 12).frame(maxWidth: 620)
                .frame(maxWidth: .infinity).background(DiscoverColors.background)
        }
        .foregroundColor(DiscoverColors.textPrimary)
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
                        let count = try await OnboardingAPI.importOPML(url)
                        importMessage = "\(count) feeds queued for import. Your folders come along too. You can keep going while NewsBlur imports them."
                        if username == NewsBlurAppDelegate.shared()?.activeUsername,
                           server == NewsBlurAppDelegate.shared()?.url {
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

    private func showCompletion() {
        step = 1
        bundles.prepareToRead()
    }

    private var importPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "tray.and.arrow.down.fill").font(.title2).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bring your feeds with you").font(.headline)
                    Text("Import feeds and folders from an OPML export.").font(.subheadline).foregroundStyle(DiscoverColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Button { showImporter = true } label: { Label("Import OPML", systemImage: "doc.badge.plus") }
                .buttonStyle(.bordered).disabled(importing)
            if importing { ProgressView("Uploading your feeds…") }
            if let importMessage { Text(importMessage).font(.subheadline).accessibilityIdentifier("onboarding.import.status") }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscoverColors.cardBackground).clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var discoveryPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A few good sources can open up a whole new world. Choose an interest to build your first folder.").font(.title3).foregroundStyle(DiscoverColors.textSecondary)
            Button(action: onDiscover) { Label("Search all sites and sources", systemImage: "magnifyingglass") }
                .padding().frame(maxWidth: .infinity).background(DiscoverColors.cardBackground).clipShape(RoundedRectangle(cornerRadius: 14))
            TextField("Find an interest", text: $interestSearch).textFieldStyle(.roundedBorder).accessibilityLabel("Find an interest")
            if bundles.catalogLoading { ProgressView("Finding your next favorites…") }
            if let message = bundles.message, bundles.interests.isEmpty {
                Text(message).font(.subheadline)
                Button("Try again") { Task { await bundles.loadCatalog() } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                if interestSearch.isEmpty { bundleCard("A little of everything", interest: nil, symbol: "sparkles") }
                ForEach(bundles.interests.filter { interestSearch.isEmpty || $0.localizedCaseInsensitiveContains(interestSearch) }, id: \.self) { interest in
                    bundleCard(interest, interest: interest, symbol: bundleSymbol(interest))
                }
            }
            subscriptionStatus
            if !bundles.added.isEmpty {
                Label("\(bundles.added.count) feeds added. Your new folders are ready.", systemImage: "checkmark.circle.fill").foregroundColor(.accentColor)
            }
        }
        .task { await bundles.loadCatalog() }
        .sheet(isPresented: $showBundle) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Make this bundle yours.").font(.title.bold())
                        Text("Keep the feeds you like. We’ll put them in a folder you can rename anytime.").foregroundStyle(DiscoverColors.textSecondary)
                        TextField("Folder name", text: $bundles.folder).font(.title3.bold()).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Bundle folder name").disabled(bundles.busy)
                        if bundles.busy { ProgressView("Working on your feeds…") }
                        ForEach(bundles.feeds) { feed in
                            DiscoverFeedCardView(feed: feed.preview, showStories: true, selection: Binding(
                                get: { bundles.selection.contains(feed.url) },
                                set: { selected in
                                    if selected { bundles.selection.insert(feed.url) }
                                    else { bundles.selection.remove(feed.url) }
                                }), selectionStatus: bundles.added.contains(feed.url) ? "Added" : bundles.queued.contains(feed.url) ? "Queued" : nil)
                            .environmentObject(discovery)
                        }
                        if !bundles.busy && bundles.feeds.isEmpty {
                            Text("No feeds to show yet. Try another interest or search all sites.")
                            Button("Try again") { Task { await bundles.load(selectedInterest) } }
                        }
                        if let message = bundles.message { Text(message).font(.subheadline) }
                        subscriptionStatus
                    }.padding(24)
                }
                .background(DiscoverColors.background)
                .safeAreaInset(edge: .bottom) {
                    Button("Add \(bundles.selection.count) feeds to folder") { bundles.queueSubscriptions() }
                        .buttonStyle(OnboardingPrimaryButton()).padding().background(DiscoverColors.background)
                        .disabled(bundles.busy || bundles.selection.isEmpty || bundles.folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .navigationTitle(selectedInterest ?? "A little of everything").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBundle = false } } }
            }.foregroundColor(DiscoverColors.textPrimary)
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Loading your feeds…")
        }.accessibilityIdentifier("onboarding.feeds.loading")
    }

    private var subscriptionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step == 0 && feedLoading.isLoading { loadingIndicator }
            if !bundles.queued.isEmpty {
                Label("Adding \(bundles.queued.count) feeds in the background…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline).foregroundStyle(DiscoverColors.textSecondary)
            }
            ForEach(bundles.failedBundles) { failure in
                HStack {
                    Text("\(failure.feeds.count) feeds couldn’t be added to \(failure.folder).")
                    Spacer()
                    Button("Retry") { bundles.retry(failure) }
                }.font(.subheadline)
            }
        }
    }

    private func bundleCard(_ title: String, interest: String?, symbol: String) -> some View {
        Button {
            selectedInterest = interest
            showBundle = true
            Task { await bundles.load(interest) }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 25, weight: .medium)).foregroundColor(.accentColor)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(DiscoverColors.textSecondary)
                }
                Text(title).font(.headline).foregroundColor(DiscoverColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: -5) {
                    ForEach((bundles.icons[interest ?? ""] ?? []).prefix(5)) { feed in
                        DiscoverFeedIconView(feed: feed)
                            .frame(width: 28, height: 28).padding(3)
                            .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 9))
                            .accessibilityHidden(true)
                    }
                }.frame(height: 34, alignment: .leading)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 155, alignment: .topLeading)
                .background(DiscoverColors.cardBackground).clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .task { await bundles.loadIcons(interest) }
    }

    private func bundleSymbol(_ interest: String) -> String {
        let name = interest.lowercased()
        for (word, symbol) in [("tech", "cpu"), ("science", "atom"), ("food", "fork.knife"), ("design", "paintpalette"),
                               ("travel", "globe.americas"), ("music", "music.note"), ("sport", "figure.run"),
                               ("news", "newspaper"), ("art", "paintbrush.pointed"), ("business", "chart.line.uptrend.xyaxis"),
                               ("game", "gamecontroller"), ("book", "books.vertical"), ("nature", "leaf"), ("space", "moon.stars")] {
            if name.contains(word) { return symbol }
        }
        return "square.stack.3d.up"
    }

    private var finishedPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundColor(.accentColor)
            Text("Your reading, your way. Have fun finding your next favorite story.").font(.title3).foregroundStyle(DiscoverColors.textSecondary)
            VStack(alignment: .leading, spacing: 24) {
                Link(destination: URL(string: "https://forum.newsblur.com")!) { Label("Get help and share ideas on the forum", systemImage: "bubble.left.and.bubble.right") }
                Link("Follow Samuel Clay on X", destination: URL(string: "https://x.com/samuelclay")!)
                Link("Follow NewsBlur on X", destination: URL(string: "https://x.com/newsblur")!)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(DiscoverColors.cardBackground).clipShape(RoundedRectangle(cornerRadius: 24))
            subscriptionStatus
            Text("Good luck, and happy reading.")
        }
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
