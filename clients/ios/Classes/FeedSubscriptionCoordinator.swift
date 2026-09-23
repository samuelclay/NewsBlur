import UIKit
import ObjectiveC

@MainActor final class FeedSubscriptionCoordinator: NSObject {
    private weak var app: NewsBlurAppDelegate?
    private let defaults: UserDefaults?
    private var ready = false
    private var generation = 0
    private var pendingURL: URL?
    private var pendingAccount: String?
    private var pendingHost: String?
    private var openingFeedID: String?
    private var sharedFeedID: String?
    private var isSubscribing = false
    private var inFlightURL: URL?
    private var needsReload = false
    private var errorMessage: String?

    init(app: NewsBlurAppDelegate, defaults: UserDefaults? = UserDefaults(suiteName: "group.com.newsblur.NewsBlur-Group")) {
        self.app = app
        self.defaults = defaults
    }

    func accept(_ url: URL) -> Bool {
        guard let feedURL = FeedSubscriptionURL.parse(url) else { return false }
        if feedURL == inFlightURL { return true }
        pendingURL = feedURL
        pendingAccount = ready ? app?.activeUsername : nil
        pendingHost = app?.url
        resume()
        return true
    }

    func resetForAccountChange() {
        for key in ["share:token", "share:host", "share:username", "subscription:pending-feed"] {
            defaults?.removeObject(forKey: key)
        }
        generation += 1
        ready = false
        isSubscribing = false
        inFlightURL = nil
        openingFeedID = nil
        sharedFeedID = nil
        errorMessage = nil
        needsReload = false
        // FeedSubscriptionCoordinator.swift preserves links received before the user signs in.
        if pendingAccount != nil { pendingURL = nil }
        pendingAccount = nil
    }

    func feedsDidLoad() {
        ready = true
        needsReload = false
        resume()
    }

    func resume() {
        guard ready, let app, let account = app.activeUsername, !account.isEmpty,
              app.feedsViewController != nil, app.dictFeeds != nil else { return }
        if let pending = defaults?.dictionary(forKey: "subscription:pending-feed") {
            if pending["username"] as? String == account,
               pending["host"] as? String == app.url,
               let feedID = pending["feed_id"] as? String, let number = Int(feedID), number > 0 {
                if sharedFeedID != feedID {
                    sharedFeedID = feedID
                    openingFeedID = feedID
                    pendingAccount = account
                    pendingHost = app.url
                    needsReload = true
                    app.reloadFeedsView(false)
                    return
                }
            } else {
                defaults?.removeObject(forKey: "subscription:pending-feed")
            }
        }
        guard !needsReload else { return }
        if let owner = pendingAccount, owner != account || pendingHost != app.url {
            pendingURL = nil
            openingFeedID = nil
            pendingAccount = nil
            return
        }
        if let feedID = openingFeedID {
            openingFeedID = nil
            if app.dictFeeds[feedID] != nil {
                app.pendingFolder = nil
                let navigationGeneration = generation
                let host = app.url
                app.popToRoot(completion: { [weak self, weak app] in
                    guard let self, let app, self.generation == navigationGeneration,
                          app.activeUsername == account, app.url == host else { return }
                    self.openSubscribedFeed(feedID, app: app)
                    // FeedSubscriptionCoordinator.swift retains the handoff across failed refreshes and app termination.
                    if let pending = self.defaults?.dictionary(forKey: "subscription:pending-feed"),
                       pending["feed_id"] as? String == feedID,
                       pending["username"] as? String == account,
                       pending["host"] as? String == host {
                        self.defaults?.removeObject(forKey: "subscription:pending-feed")
                    }
                    self.sharedFeedID = nil
                })
            } else {
                showError("The site was subscribed, but its feed could not be loaded. Refresh your sites and try again.")
            }
            return
        }
        if let message = errorMessage {
            showError(message)
            return
        }
        guard !isSubscribing, let url = pendingURL else { return }
        pendingURL = nil
        pendingAccount = account
        pendingHost = app.url
        isSubscribing = true
        inFlightURL = url
        let requestGeneration = generation
        let host = app.url ?? ""
        app.post("\(host)/reader/add_url", parameters: ["url": url.absoluteString, "folder": ""], success: { [weak self] _, response in
            guard let self, self.generation == requestGeneration,
                  self.app?.activeUsername == account, self.app?.url == host else { return }
            self.isSubscribing = false
            self.inFlightURL = nil
            guard let response = response as? [String: Any], let feedID = FeedSubscriptionURL.feedID(in: response) else {
                self.showError((response as? [String: Any])?["message"] as? String ?? "NewsBlur could not subscribe to this feed.")
                return
            }
            if self.pendingURL != nil {
                self.resume()
                return
            }
            self.openingFeedID = feedID
            self.needsReload = true
            self.app?.reloadFeedsView(false)
        }, failure: { [weak self] _, error in
            guard let self, self.generation == requestGeneration,
                  self.app?.activeUsername == account, self.app?.url == host else { return }
            self.isSubscribing = false
            self.inFlightURL = nil
            self.showError(error?.localizedDescription ?? "NewsBlur could not subscribe to this feed.")
        })
    }

    private func openSubscribedFeed(_ feedID: String, app: NewsBlurAppDelegate) {
        // FeedSubscriptionCoordinator.swift follows ordinary feed selection, without starting a notification story lookup.
        app.feedsViewController.loadWorkItem?.cancel()
        app.detailViewController.dismissDiscoverSites()
        app.feedDetailViewController.beginExplicitFeedSelection()
        app.feedDetailViewController.cancelMarkStoryReadTimer()
        app.cleanUpTryFeed()
        app.pendingFolder = nil
        app.pendingDailyBriefingStoryHash = nil
        app.inFindingStoryMode = false
        app.findingStoryStartDate = nil
        app.findingStoryDictionary = nil
        app.tryFeedFeedId = nil
        app.tryFeedStoryId = nil
        app.tryFeedStoryTitle = nil
        app.skipTryFeedCleanup = false
        app.feedsViewController.clearDashboard()
        app.storiesCollection.reset()
        app.storiesCollection.inSearch = false
        app.storiesCollection.searchQuery = nil
        app.storiesCollection.savedSearchQuery = nil
        // FeedSubscriptionCoordinator.swift shows a newly subscribed site's stories even when they are all already read.
        app.storiesCollection.readFilterOverride = "all"
        app.loadFolder(nil, feedID: feedID)
    }

    private func showError(_ message: String) {
        errorMessage = message
        guard let root = app?.window?.rootViewController, root.viewIfLoaded?.window != nil else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        guard !(presenter is UIAlertController), !presenter.isBeingDismissed else { return }
        errorMessage = nil
        let alert = UIAlertController(title: "Unable to Subscribe", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.resume() })
        presenter.present(alert, animated: true)
    }
}

@MainActor private var feedSubscriptionCoordinatorKey: UInt8 = 0

extension NewsBlurAppDelegate {
    @MainActor var feedSubscriptionCoordinator: FeedSubscriptionCoordinator {
        if let coordinator = objc_getAssociatedObject(self, &feedSubscriptionCoordinatorKey) as? FeedSubscriptionCoordinator {
            return coordinator
        }
        let coordinator = FeedSubscriptionCoordinator(app: self)
        objc_setAssociatedObject(self, &feedSubscriptionCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return coordinator
    }

    @MainActor @objc func handleFeedSubscriptionURL(_ url: URL) -> Bool {
        feedSubscriptionCoordinator.accept(url)
    }

    @MainActor @objc func feedSubscriptionsDidLoad() { feedSubscriptionCoordinator.feedsDidLoad() }
    @MainActor @objc func resumeFeedSubscription() { feedSubscriptionCoordinator.resume() }
    @MainActor @objc func resetFeedSubscriptionForAccountChange() { feedSubscriptionCoordinator.resetForAccountChange() }
}
