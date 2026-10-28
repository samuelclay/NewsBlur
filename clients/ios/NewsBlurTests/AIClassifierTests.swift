import XCTest

@testable import NewsBlur

/// AIClassifierTests.swift answers every AI classifier and usage billing request with fixtures, so no test can
/// run a paid prompt test, change a limit or open Stripe against a real account.
@MainActor private final class RecordingAITransport: AIClassifierTransport {
    struct Request {
        let method: String
        let path: String
        let parameters: [String: Any]
    }

    var requests: [Request] = []
    var responses: [String: [String: Any]] = [:]

    func get(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requests.append(Request(method: "GET", path: path, parameters: parameters))
        completion(responses[path].map { .success($0) } ?? .failure(URLError(.badServerResponse)))
    }

    func post(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requests.append(Request(method: "POST", path: path, parameters: parameters))
        completion(responses[path].map { .success($0) } ?? .failure(URLError(.badServerResponse)))
    }

    func requests(to path: String) -> [Request] {
        requests.filter { $0.path == path }
    }
}

@MainActor private final class RecordingBillingBrowser: UsageBillingBrowser {
    var openedURL: URL?
    var callbackScheme: String?
    var completion: ((URL?, Error?) -> Void)?

    func open(_ url: URL, callbackScheme: String, completion: @escaping (URL?, Error?) -> Void) -> Bool {
        openedURL = url
        self.callbackScheme = callbackScheme
        self.completion = completion
        return true
    }
}

private final class PromptSaveAppDelegate: NewsBlurAppDelegate {
    var savedParameters: [[String: Any]] = []

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
        savedParameters.append(parameters as? [String: Any] ?? [:])
    }

    override func recalculateIntelligenceScores(_ feedId: Any!) {
    }
}

/// AIClassifierTests.swift checks English copy, so it pins the interface language while each test runs.
@MainActor private func withEnglishInterface(_ body: () throws -> Void) rethrows {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: NBLocalization.preferenceKey)
    defaults.set("en", forKey: NBLocalization.preferenceKey)
    defer { defaults.set(previous, forKey: NBLocalization.preferenceKey) }
    try body()
}

// MARK: - Story header pills

@MainActor final class Test_StoryAIClassifierPills: XCTestCase {
    func test_headerShowsContentAndImagePillsWithScoreClasses() throws {
        try withEnglishInterface {
            let html = StoryAIClassifierPills.headerHTML(for: [
                ["prompt": "Non-apple related news", "score": 1, "include_images": false],
                ["prompt": "Charts and graphs", "score": -1, "include_images": true],
            ])

            XCTAssertTrue(html.hasPrefix("<div class=\"NB-story-ai-classifiers\">"))
            let focus = try XCTUnwrap(html.range(of: "class=\"NB-story-ai-classifier NB-score-1\" data-prompt-type=\"content\""))
            let hidden = try XCTUnwrap(html.range(of: "class=\"NB-story-ai-classifier NB-score--1\" data-prompt-type=\"image\""))
            XCTAssertLessThan(focus.lowerBound, hidden.lowerBound, "Pills keep the server's order")
            XCTAssertTrue(html.contains("<span class=\"NB-story-ai-classifier-label\">Content Filter</span>: "
                                        + "<span class=\"NB-story-ai-classifier-prompt\" dir=\"auto\">Non-apple related news</span>"))
            XCTAssertTrue(html.contains("<span class=\"NB-story-ai-classifier-label\">Image Filter</span>: "
                                        + "<span class=\"NB-story-ai-classifier-prompt\" dir=\"auto\">Charts and graphs</span>"))
            // storyDetailView.js turns this link into the trainer, anchored at the pill.
            XCTAssertEqual(html.components(separatedBy: "href=\"http://ios.newsblur.com/train\"").count - 1, 2)
        }
    }

    func test_headerEscapesPromptText() {
        let html = StoryAIClassifierPills.headerHTML(for: [
            ["prompt": "<img src=x onerror=\"alert('x')\"> & C:\\path\nnext", "score": 1, "include_images": false],
        ])

        XCTAssertFalse(html.contains("<img"))
        XCTAssertTrue(html.contains("&lt;img src=x onerror=&quot;alert(&#39;x&#39;)&quot;&gt; &amp; C:&#92;path next"))
        // StoryDetailObjCViewController.m refreshHeader wraps the header in a single-quoted JavaScript string.
        XCTAssertFalse(html.contains("'"))
        XCTAssertFalse(html.contains("\\"))
        XCTAssertFalse(html.contains("\n"))
    }

    func test_headerIsEmptyWithoutMatchedPrompts() {
        XCTAssertEqual(StoryAIClassifierPills.headerHTML(for: nil), "")
        XCTAssertEqual(StoryAIClassifierPills.headerHTML(for: NSNull()), "")
        XCTAssertEqual(StoryAIClassifierPills.headerHTML(for: []), "")
        XCTAssertEqual(StoryAIClassifierPills.headerHTML(for: [["prompt": "Unmatched", "score": 0]]), "")
        XCTAssertEqual(StoryAIClassifierPills.headerHTML(for: [["prompt": "  ", "score": 1]]), "")
    }

    func test_storyHeaderPlacesPillsAfterURLMatchAndKeepsThemOffline() throws {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.activeClassifiers = ["5719953": ["url_regex": ["sponsor": -1]]]
        let story: [String: Any] = [
            "story_hash": "5719953:1b4552",
            "story_feed_id": 5719953,
            "story_title": "[Sponsor] WorkOS: Let Agents Sign Up for Your App Without a Browser",
            "story_permalink": "https://daringfireball.net/linked/2026/10/27/sponsor-workos",
            "story_authors": "Daring Fireball Department of Commerce",
            "story_timestamp": 1_800_000_000,
            "read_status": 1,
            "intelligence": ["feed": 1, "author": -1, "prompt": 1],
            "prompt_classifiers": [["prompt": "Non-apple related news", "score": 1, "include_images": false]],
        ]
        // OfflineFetchStories.m stores each story as JSON and reads it back the same way.
        let stored = try JSONSerialization.data(withJSONObject: story)
        let restored = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [String: Any])

        let page = StoryDetailViewController()
        page.appDelegate = app
        page.activeStory = NSMutableDictionary(dictionary: restored)
        let header = try XCTUnwrap(page.getHeader())

        let urlMatch = try XCTUnwrap(header.range(of: "NB-story-url-match"))
        let pills = try XCTUnwrap(header.range(of: "NB-story-ai-classifiers"))
        XCTAssertLessThan(urlMatch.lowerBound, pills.lowerBound)
        XCTAssertTrue(header.contains("NB-story-ai-classifier NB-score-1"))
        XCTAssertTrue(header.contains(">Non-apple related news<"))
    }
}

// MARK: - Trainer prompts

@MainActor final class Test_TrainerPromptClassifiers: XCTestCase {
    func test_saveParametersMatchClassifierSave() {
        func parameters(_ score: Int, previous: Int, images: Bool = false, scope: String? = "feed",
                        folder: String? = "") -> NSDictionary? {
            PromptClassifierSave.parameters(prompt: "Non-apple related news", feedId: "42", score: score,
                                            previousScore: previous, includeImages: images, scope: scope,
                                            folderName: folder).map { $0 as NSDictionary }
        }

        XCTAssertEqual(parameters(1, previous: 0), ["like_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(-1, previous: 1), ["dislike_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(0, previous: 1), ["remove_like_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(0, previous: -1), ["remove_dislike_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertNil(parameters(0, previous: 0), "Nothing to remove")
        XCTAssertEqual(parameters(1, previous: 0, images: true), ["like_image_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(-1, previous: 0, images: true), ["dislike_image_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(0, previous: 1, images: true), ["remove_like_image_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(0, previous: -1, images: true), ["remove_dislike_image_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(parameters(1, previous: 0, scope: "folder", folder: "Apple"),
                       ["like_prompt": "Non-apple related news", "feed_id": "42", "scope": "folder", "folder_name": "Apple"])
        XCTAssertEqual(parameters(-1, previous: 0, scope: "global", folder: "Apple"),
                       ["dislike_prompt": "Non-apple related news", "feed_id": "42", "scope": "global"])
    }

    func test_tappingCyclesLikeDislikeRemovedAndThumbsDownTogglesDislike() {
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTapping: 0), 1)
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTapping: 1), -1)
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTapping: -1), 0)
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTappingDislike: 0), -1)
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTappingDislike: 1), -1)
        XCTAssertEqual(PromptClassifierSave.nextScore(afterTappingDislike: -1), 0)
    }

    func test_appDelegateSavesPromptAndKeepsRemovedPromptVisible() {
        let app = PromptSaveAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Non-apple related news": 1], "authors": ["Sponsor": -1]]]

        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false, scope: "feed", folderName: "")
        XCTAssertEqual(app.savedParameters.last as NSDictionary?, ["dislike_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(promptScore(app, key: "prompts", prompt: "Non-apple related news"), -1)

        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false, scope: "feed", folderName: "")
        XCTAssertEqual(app.savedParameters.last as NSDictionary?, ["remove_dislike_prompt": "Non-apple related news", "feed_id": "42"])
        XCTAssertEqual(promptScore(app, key: "prompts", prompt: "Non-apple related news"), 0,
                       "The trainer keeps a removed prompt as neutral so it can be liked again")

        app.savePromptClassifier("Charts", feedId: "42", score: 1, includeImages: true, scope: "folder", folderName: "Apple")
        XCTAssertEqual(app.savedParameters.last as NSDictionary?,
                       ["like_image_prompt": "Charts", "feed_id": "42", "scope": "folder", "folder_name": "Apple"])
        XCTAssertEqual(promptScore(app, key: "image_prompts", prompt: "Charts"), 1)
        let feedClassifiers = app.storiesCollection.activeClassifiers["42"] as? [String: Any]
        XCTAssertEqual(feedClassifiers?["authors"] as? [String: Int], ["Sponsor": -1], "Other classifiers stay put")

        let saves = app.savedParameters.count
        app.savePromptClassifier("Never saved", feedId: "42", score: 0, includeImages: false, scope: "feed", folderName: "")
        XCTAssertEqual(app.savedParameters.count, saves, "Removing a prompt that isn't saved sends nothing")
    }

    func test_savedPromptsReadScopesFromClassifiers() {
        let classifiers: AnyDictionary = [
            "prompts": ["Non-apple related news": 1, "Sponsored posts": -1],
            "prompts_scope": ["Sponsored posts": ["scope": "folder", "folder_name": "Apple"]],
            "image_prompts": ["Charts": 1],
            "image_prompts_scope": ["Charts": ["scope": "global", "folder_name": ""]],
        ]

        let content = PromptClassifier.saved(in: classifiers, kind: .content)
        XCTAssertEqual(content.map(\.prompt), ["Non-apple related news", "Sponsored posts"])
        XCTAssertEqual(content.map(\.score), [1, -1])
        XCTAssertEqual(content.map(\.scope), [.feed, .folder])
        XCTAssertEqual(content[1].folderName, "Apple")
        let images = PromptClassifier.saved(in: classifiers, kind: .image)
        XCTAssertEqual(images.map(\.prompt), ["Charts"])
        XCTAssertEqual(images.first?.scope, .global)
    }

    func test_textPromptTestPostsDraftAndShowsMatch() throws {
        try withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/classifier/test_prompt"] = [
                "code": 0, "classification": 1,
                "cost_estimate": ["avg_cost_per_text": 0.0004, "avg_cost_per_image": 0.002],
            ]
            let model = makeModel(transport: transport, canUseAI: false)
            model.prepare(feedId: "42", storyHash: "42:abc")
            model.setDraft("  Non-apple related news ", for: .content)
            model.toggleDraftDirection(.content)

            model.runTest(.content, storyHash: "42:abc", feedId: "42")

            let request = try XCTUnwrap(transport.requests(to: "/classifier/test_prompt").first)
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.parameters as NSDictionary, [
                "prompt": "Non-apple related news", "story_hash": "42:abc", "include_images": "false",
                "classifier_type": "hidden", "feed_id": "42",
            ])
            XCTAssertEqual(model.test(.content), .finished(.classified(matches: true, imageMatches: [])))
            XCTAssertEqual(model.testStatus(.content, imageCount: 0)?.text, "✓ Story matches this filter")
            XCTAssertEqual(model.estimate, AIClassifierCostEstimate(averageCostPerText: 0.0004, averageCostPerImage: 0.002))

            model.setDraft("Non-apple related news!", for: .content)
            XCTAssertEqual(model.test(.content), .idle, "Editing the prompt clears the old result")
        }
    }

    func test_imagePromptTestShowsEachImageResult() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1, "image_results": [1, 0, 1]]
            let model = makeModel(transport: transport, canUseAI: true)
            model.setDraft("Charts and graphs", for: .image)

            model.runTest(.image, storyHash: "42:abc", feedId: "42")

            XCTAssertEqual(transport.requests(to: "/classifier/test_prompt").first?.parameters["include_images"] as? String, "true")
            XCTAssertEqual(transport.requests(to: "/classifier/test_prompt").first?.parameters["classifier_type"] as? String, "focus")
            XCTAssertEqual(model.imageMatch(at: 0), true)
            XCTAssertEqual(model.imageMatch(at: 1), false)
            XCTAssertEqual(model.imageMatch(at: 2), true)
            XCTAssertNil(model.imageMatch(at: 3))
            XCTAssertEqual(model.testStatus(.image, imageCount: 3)?.text, "✓ 2 of 3 images match this filter")

            transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 0, "image_results": [0]]
            model.setDraft("Food photography", for: .image)
            model.runTest(.image, storyHash: "42:abc", feedId: "42")
            XCTAssertEqual(model.testStatus(.image, imageCount: 1)?.text, "✗ Image does not match this filter")
        }
    }

    func test_promptTestFailureShowsServerMessage() {
        let transport = RecordingAITransport()
        transport.responses["/classifier/test_prompt"] = ["code": -1, "message": "Usage billing required for AI classifiers"]
        let model = makeModel(transport: transport, canUseAI: false)
        model.setDraft("Non-apple related news", for: .content)

        model.runTest(.content, storyHash: "42:abc", feedId: "social:9")

        XCTAssertEqual(transport.requests.first?.parameters["feed_id"] as? String, "0", "The server parses feed_id as an integer")
        let status = model.testStatus(.content, imageCount: 0)
        XCTAssertEqual(status?.text, "Usage billing required for AI classifiers")
        XCTAssertEqual(status?.isError, true)
    }

    func test_promptTestNeedsAPromptAndAStory() {
        let transport = RecordingAITransport()
        let model = makeModel(transport: transport, canUseAI: true)
        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        model.setDraft("Non-apple related news", for: .content)
        model.runTest(.content, storyHash: nil, feedId: "42")
        XCTAssertTrue(transport.requests(to: "/classifier/test_prompt").isEmpty)
    }

    func test_costEstimatesOnlyLoadForBillingUsers() {
        let transport = RecordingAITransport()
        transport.responses["/classifier/ai_classifier_usage"] = [
            "code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0004, "avg_cost_per_image": 0.002, "is_limit_reached": true,
        ]

        let freeModel = makeModel(transport: transport, canUseAI: false)
        freeModel.prepare(feedId: "42", storyHash: nil)
        XCTAssertTrue(transport.requests.isEmpty)

        let billingModel = makeModel(transport: transport, canUseAI: true)
        billingModel.prepare(feedId: "42", storyHash: nil)
        billingModel.prepare(feedId: "42", storyHash: nil)
        XCTAssertEqual(transport.requests.map(\.path), ["/classifier/ai_classifier_usage"], "Reloading the same site doesn't refetch")
        XCTAssertEqual(transport.requests.first?.parameters["feed_id"] as? String, "42")
        XCTAssertEqual(billingModel.estimate?.averageCostPerImage, 0.002)
        XCTAssertTrue(billingModel.isLimitReached)
    }

    func test_sectionCostFollowsWebFormula() {
        withEnglishInterface {
            XCTAssertEqual(AIClassifierCostFormatter.format(0), "$0.00")
            XCTAssertEqual(AIClassifierCostFormatter.format(0.0004), "$0.0004")
            XCTAssertEqual(AIClassifierCostFormatter.format(0.012), "$0.012")
            XCTAssertEqual(AIClassifierCostFormatter.format(1.234), "$1.23")

            let none = AIClassifierCostFormatter.sectionCost(kind: .content, costPerRun: 0.0004, feedStoriesPerMonth: 300, filters: [])
            XCTAssertEqual(none, AIClassifierSectionCost(monthly: "$0.00", daily: "$0.00",
                                                         breakdown: "300 stories/mo × 0 content filters × $0.0004/story"))

            let feedOnly = AIClassifierCostFormatter.sectionCost(
                kind: .image, costPerRun: 0.002, feedStoriesPerMonth: 300,
                filters: [AIClassifierCostFilter(scope: .feed, storiesPerMonth: 300), AIClassifierCostFilter(scope: .feed, storiesPerMonth: 300)])
            XCTAssertEqual(feedOnly, AIClassifierSectionCost(monthly: "$1.20", daily: "$0.040",
                                                             breakdown: "300 stories/mo × 2 image filters × $0.0020/story"))

            let mixed = AIClassifierCostFormatter.sectionCost(
                kind: .content, costPerRun: 0.0004, feedStoriesPerMonth: 300,
                filters: [AIClassifierCostFilter(scope: .feed, storiesPerMonth: 300), AIClassifierCostFilter(scope: .global, storiesPerMonth: 1)])
            XCTAssertEqual(mixed?.breakdown, "1 on this site (300 stories/mo) + 1 on all sites (1 story/mo) × $0.0004/story")
            XCTAssertEqual(mixed?.monthly, "$0.12")

            XCTAssertNil(AIClassifierCostFormatter.sectionCost(kind: .content, costPerRun: 0.0004, feedStoriesPerMonth: 0, filters: []))
        }
    }

    func test_modelCountsSavedAndDraftPromptsAcrossScopes() {
        let model = makeModel(transport: RecordingAITransport(), canUseAI: true)
        model.storyVolumes = {
            AIClassifierStoryVolumes(storiesForFeed: { $0 == "42" ? 100 : 0 },
                                     storiesForFolder: { $0 == "Apple" ? 1_000 : 0 },
                                     storiesForAllSites: { 5_000 })
        }
        let transport = model.api.transport as! RecordingAITransport
        transport.responses["/classifier/ai_classifier_usage"] = ["code": 0, "can_use_ai": true, "avg_cost_per_text": 0.001, "avg_cost_per_image": 0.01]
        model.prepare(feedId: "42", storyHash: nil)
        let saved = [
            PromptClassifier(prompt: "Apple", kind: .content, score: 1, scope: .folder, folderName: "Apple"),
            PromptClassifier(prompt: "Removed", kind: .content, score: 0, scope: .feed, folderName: ""),
        ]

        XCTAssertEqual(model.sectionCost(.content, saved: saved, feedId: "42", currentFolderName: "Apple")?.monthly, "$1.00")
        model.setDraft("Sponsored", for: .content)
        XCTAssertEqual(model.sectionCost(.content, saved: saved, feedId: "42", currentFolderName: "Apple")?.monthly, "$1.10",
                       "The prompt being written counts on this site")
    }

    func test_billingBannerAppearsForPromptsThatWontRun() {
        let saved = [PromptClassifier(prompt: "Apple", kind: .content, score: 1, scope: .feed, folderName: "")]
        let free = makeModel(transport: RecordingAITransport(), canUseAI: false)
        XCTAssertTrue(free.showsBillingBanner(.content, saved: saved))
        XCTAssertFalse(free.showsBillingBanner(.image, saved: []))
        free.setDraft("Charts", for: .image)
        XCTAssertTrue(free.showsBillingBanner(.image, saved: []))

        let billing = makeModel(transport: RecordingAITransport(), canUseAI: true)
        XCTAssertFalse(billing.showsBillingBanner(.content, saved: saved))
    }

    func test_addingDraftSavesItInTheChosenDirection() {
        var saves: [(String, PromptClassifierKind, String, Int)] = []
        let model = makeModel(transport: RecordingAITransport(), canUseAI: true)
        model.savePrompt = { prompt, kind, feedId, score, _, _ in saves.append((prompt, kind, feedId, score)) }
        model.setDraft(" Charts ", for: .image)
        model.toggleDraftDirection(.image)

        model.addDraft(.image, feedId: "42")

        XCTAssertEqual(saves.count, 1)
        XCTAssertEqual(saves.first?.0, "Charts")
        XCTAssertEqual(saves.first?.1, .image)
        XCTAssertEqual(saves.first?.2, "42")
        XCTAssertEqual(saves.first?.3, -1)
        XCTAssertEqual(model.draft(.image), "")
        XCTAssertEqual(model.draftScore(.image), 1, "The next prompt starts as a focus prompt again")
    }

    private func makeModel(transport: RecordingAITransport, canUseAI: Bool) -> TrainerAIPromptModel {
        TrainerAIPromptModel(api: AIClassifierAPI(transport: transport),
                             billingStatus: { UsageBillingStatus(isUsageBilling: canUseAI, isSelfHostedAI: false,
                                                                 canUseAIClassifiers: canUseAI, usageBillingLimit: nil) },
                             storyVolumes: { AIClassifierStoryVolumes(storiesForFeed: { _ in 300 }, storiesForFolder: { _ in 0 },
                                                                      storiesForAllSites: { 0 }) },
                             openBilling: {})
    }

    private func promptScore(_ app: NewsBlurAppDelegate, key: String, prompt: String) -> Int? {
        let feedClassifiers = app.storiesCollection.activeClassifiers["42"] as? [String: Any]
        return (feedClassifiers?[key] as? [String: Any])?[prompt] as? Int
    }
}

// MARK: - Usage billing

@MainActor final class Test_UsageBilling: XCTestCase {
    func test_statusReadsProfileFlags() {
        withEnglishInterface {
            let billing = UsageBillingStatus(profile: ["is_usage_billing": true, "is_self_hosted_ai": false,
                                                       "can_use_ai_classifiers": true, "usage_billing_limit": 25.5])
            XCTAssertEqual(billing, UsageBillingStatus(isUsageBilling: true, isSelfHostedAI: false,
                                                       canUseAIClassifiers: true, usageBillingLimit: 25.5))
            XCTAssertEqual(billing.statusText, "Usage-based billing is enabled for natural language classifiers.")

            let selfHosted = UsageBillingStatus(profile: ["is_self_hosted_ai": 1, "usage_billing_limit": NSNull()])
            XCTAssertTrue(selfHosted.canUseAIClassifiers, "Older servers without can_use_ai_classifiers still work")
            XCTAssertNil(selfHosted.usageBillingLimit)
            XCTAssertEqual(selfHosted.statusText, "Natural language classifiers are using your instance's API keys.")

            let free = UsageBillingStatus(profile: nil)
            XCTAssertFalse(free.canUseAIClassifiers)
            XCTAssertEqual(free.statusText, "Set up usage-based billing to use natural language content and image filters.")
        }
    }

    func test_historyParsesSpendLimitAndInvoices() throws {
        let history = UsageBillingHistory(json: [
            "current_cycle_spend": 8.5, "usage_billing_limit": 10.0, "is_limit_reached": false,
            "cycle_start": "2026-10-01", "cycle_end": "2026-10-31",
            "upcoming_invoice": ["date": "2026-11-01", "amount": 8.5, "status": "upcoming",
                                 "line_items": [["description": "Natural language text classifier", "quantity": 4200, "amount": 1.68]]],
            "invoices": [["date": "2026-10-01", "amount": 3.0, "amount_paid": 2.75, "status": "paid",
                          "hosted_invoice_url": "https://invoice.stripe.com/i/acct/test", "line_items": []]],
        ])

        XCTAssertEqual(history.currentCycleSpend, 8.5)
        XCTAssertEqual(try XCTUnwrap(history.limitProgress), 0.85, accuracy: 0.0001)
        XCTAssertTrue(history.isNearLimit)
        XCTAssertFalse(history.isLimitReached)
        XCTAssertEqual(history.cycleStart, UsageBillingHistory.day("2026-10-01"))
        XCTAssertEqual(history.upcomingInvoice?.amount, 8.5)
        XCTAssertEqual(history.upcomingInvoice?.lineItems,
                       [UsageBillingHistory.LineItem(description: "Natural language text classifier", quantity: 4200, amount: 1.68)])
        XCTAssertEqual(history.invoices.first?.amount, 2.75, "Paid invoices show what was charged")
        XCTAssertEqual(history.invoices.first?.hostedInvoiceURL?.absoluteString, "https://invoice.stripe.com/i/acct/test")
        XCTAssertTrue(history.hasInvoices)

        let empty = UsageBillingHistory(json: ["invoices": [], "upcoming_invoice": NSNull()])
        XCTAssertFalse(empty.hasInvoices)
        XCTAssertNil(empty.limitProgress)
    }

    func test_loadFetchesHistoryOnlyWhenBillingIsActive() {
        let transport = RecordingAITransport()
        transport.responses["/profile/usage_billing_history"] = ["invoices": [], "current_cycle_spend": 1.25, "usage_billing_limit": 20.0]

        let free = makeModel(transport: transport, status: .init(isUsageBilling: false, isSelfHostedAI: false,
                                                                 canUseAIClassifiers: false, usageBillingLimit: nil))
        free.load()
        XCTAssertEqual(free.historyState, .notSetUp)
        XCTAssertTrue(transport.requests.isEmpty)

        let billing = makeModel(transport: transport, status: activeStatus)
        billing.load()
        XCTAssertEqual(transport.requests.map(\.path), ["/profile/usage_billing_history"])
        guard case .loaded(let history) = billing.historyState else { return XCTFail("History should load") }
        XCTAssertEqual(history.currentCycleSpend, 1.25)
        XCTAssertEqual(billing.limitText, "20")
    }

    func test_savingLimitSendsItAndBlankClearsIt() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": 25.5]
            let model = makeModel(transport: transport, status: activeStatus)

            model.editLimit("$25.50/month")
            XCTAssertEqual(model.limitText, "25.50")
            model.saveLimit()
            XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?, ["limit": "25.50"])
            XCTAssertEqual(model.limitText, "25.5")
            XCTAssertEqual(model.limitMessage, UsageBillingModel.Message(text: "Saved", isError: false))

            transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": NSNull()]
            model.editLimit("")
            model.saveLimit()
            XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?, ["limit": ""])
            XCTAssertEqual(model.limitText, "")
            XCTAssertNil(model.status.usageBillingLimit)

            transport.responses["/profile/save_usage_billing_limit"] = ["code": -1, "message": "Limit cannot exceed $10,000"]
            model.editLimit("20000")
            model.saveLimit()
            XCTAssertEqual(model.limitMessage, UsageBillingModel.Message(text: "Limit cannot exceed $10,000", isError: true))
            XCTAssertEqual(model.limitText, "20000", "A rejected limit stays for editing")
        }
    }

    func test_setupOpensStripeAndRefreshesWhenItReturns() throws {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        transport.responses["/profile/usage_billing_history"] = ["invoices": [], "current_cycle_spend": 0]
        let browser = RecordingBillingBrowser()
        var profileRefreshes = 0
        let model = makeModel(transport: transport, status: freeStatus, browser: browser) { profileRefreshes += 1 }

        model.openStripe()

        XCTAssertEqual(transport.requests(to: "/profile/setup_usage_billing/").first?.parameters as NSDictionary?, ["platform": "ios"])
        XCTAssertEqual(browser.openedURL?.absoluteString, "https://checkout.stripe.com/c/pay/cs_test_app")
        XCTAssertEqual(browser.callbackScheme, "newsblur-auth")
        XCTAssertTrue(model.isOpeningStripe)

        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=setup_complete"), nil)

        XCTAssertFalse(model.isOpeningStripe)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertTrue(model.status.isUsageBilling)
        XCTAssertEqual(model.stripeAction, .manage)
        XCTAssertEqual(transport.requests(to: "/profile/usage_billing_history").count, 1)
    }

    func test_billingUsersManageOnStripeAndRefreshAfterThePortal() {
        let transport = RecordingAITransport()
        transport.responses["/profile/manage_usage_billing/"] = ["code": 0, "url": "https://billing.stripe.com/p/session/test_app"]
        let browser = RecordingBillingBrowser()
        var profileRefreshes = 0
        let model = makeModel(transport: transport, status: activeStatus, browser: browser) { profileRefreshes += 1 }

        model.openStripe()
        XCTAssertEqual(transport.requests(to: "/profile/manage_usage_billing/").count, 1)
        XCTAssertEqual(browser.openedURL?.host, "billing.stripe.com")

        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=portal_return"), nil)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertNil(model.stripeMessage)
    }

    func test_alreadyActiveAndErrorsNeverOpenTheBrowser() {
        let transport = RecordingAITransport()
        let browser = RecordingBillingBrowser()
        var profileRefreshes = 0
        let model = makeModel(transport: transport, status: freeStatus, browser: browser) { profileRefreshes += 1 }

        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "already_active": true]
        model.openStripe()
        XCTAssertNil(browser.openedURL)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertEqual(model.stripeMessage?.isError, false)

        transport.responses["/profile/setup_usage_billing/"] = ["code": -1, "message": "Stripe is unavailable"]
        model.openStripe()
        XCTAssertNil(browser.openedURL)
        XCTAssertEqual(model.stripeMessage, UsageBillingModel.Message(text: "Stripe is unavailable", isError: true))
        XCTAssertFalse(model.isOpeningStripe)
    }

    func test_cancelledCheckoutKeepsBillingOff() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        let browser = RecordingBillingBrowser()
        let model = makeModel(transport: transport, status: freeStatus, browser: browser) {}

        model.openStripe()
        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=cancelled"), nil)

        XCTAssertFalse(model.status.isUsageBilling)
        XCTAssertEqual(model.stripeAction, .setup)
        XCTAssertNil(model.stripeMessage)
    }

    func test_selfHostedAIHasNoStripeButton() {
        let model = makeModel(transport: RecordingAITransport(),
                              status: .init(isUsageBilling: false, isSelfHostedAI: true, canUseAIClassifiers: true, usageBillingLimit: nil))
        XCTAssertNil(model.stripeAction)
    }

    func test_callbackAndStripeResponseParsing() {
        XCTAssertEqual(UsageBillingCallback(url: URL(string: "newsblur-auth://usage-billing?status=setup_complete")!), .setupComplete)
        XCTAssertEqual(UsageBillingCallback(url: URL(string: "newsblur-auth://usage-billing?status=cancelled")!), .cancelled)
        XCTAssertEqual(UsageBillingCallback(url: URL(string: "newsblur-auth://usage-billing?status=portal_return")!), .portalReturn)
        XCTAssertNil(UsageBillingCallback(url: URL(string: "newsblur-auth://complete?ticket=abc")!))
        XCTAssertNil(UsageBillingCallback(url: URL(string: "https://usage-billing/?status=setup_complete")!))
        XCTAssertNil(UsageBillingCallback(url: URL(string: "newsblur-auth://usage-billing?status=other")!))

        XCTAssertEqual(UsageBillingStripeResponse(json: ["code": 0, "url": "https://checkout.stripe.com/x"]),
                       .open(URL(string: "https://checkout.stripe.com/x")!))
        XCTAssertEqual(UsageBillingStripeResponse(json: ["code": 0, "url": "javascript:alert(1)"]), .failed(message: nil))
        XCTAssertEqual(UsageBillingStripeResponse(json: ["code": -1, "message": "Nope"]), .failed(message: "Nope"))
        XCTAssertEqual(UsageBillingStripeResponse(json: ["code": 0, "already_active": true]), .alreadyActive)
    }

    private var activeStatus: UsageBillingStatus {
        UsageBillingStatus(isUsageBilling: true, isSelfHostedAI: false, canUseAIClassifiers: true, usageBillingLimit: nil)
    }

    private var freeStatus: UsageBillingStatus {
        UsageBillingStatus(isUsageBilling: false, isSelfHostedAI: false, canUseAIClassifiers: false, usageBillingLimit: nil)
    }

    private func makeModel(transport: RecordingAITransport, status: UsageBillingStatus,
                           browser: UsageBillingBrowser? = nil, refreshProfile: (() -> Void)? = nil) -> UsageBillingModel {
        UsageBillingModel(api: AIClassifierAPI(transport: transport), browser: browser,
                          readStatus: { status }, refreshProfile: refreshProfile ?? {})
    }
}
