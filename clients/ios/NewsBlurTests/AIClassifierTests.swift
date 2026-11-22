import XCTest

@testable import NewsBlur

/// AIClassifierTests.swift answers every AI classifier, credit and usage billing request with fixtures, so no test
/// can run a prompt test, change a limit or open Stripe against a real account.
@MainActor private final class RecordingAITransport: AIClassifierTransport {
    struct Request {
        let method: String
        let path: String
        let parameters: [String: Any]
    }

    var requests: [Request] = []
    var responses: [String: [String: Any]] = [:]
    /// Holds every response until releaseHeldResponses(), like a slow network.
    var holdsResponses = false
    private var heldResponses: [() -> Void] = []

    func get(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requests.append(Request(method: "GET", path: path, parameters: parameters))
        respond(path, completion: completion)
    }

    func post(_ path: String, parameters: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requests.append(Request(method: "POST", path: path, parameters: parameters))
        respond(path, completion: completion)
    }

    func requests(to path: String) -> [Request] {
        requests.filter { $0.path == path }
    }

    func releaseHeldResponses() {
        let held = heldResponses
        heldResponses = []
        held.forEach { $0() }
    }

    private func respond(_ path: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let result: Result<[String: Any], Error> = responses[path].map { .success($0) } ?? .failure(URLError(.badServerResponse))
        if holdsResponses {
            heldResponses.append { completion(result) }
        } else {
            completion(result)
        }
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

/// apps/analyzer/ai_credits.py state() for an Archive month, which each test bends into the state it needs.
private func creditsJSON(_ changes: [String: Any] = [:]) -> [String: Any] {
    var json: [String: Any] = [
        "included": 10_000, "used": 2_340, "remaining": 7_660, "month": "2026-11", "resets_on": "2026-12-01",
        "is_unlimited": false, "is_billing_available": true, "is_usage_billing": false, "monthly_limit": NSNull(),
        "overage_credits": 0, "overage_usd": 0.0, "unbilled_usd": 0.0, "minimum_charge_usd": 1.0,
        "immediate_charge_usd": 10.0, "is_paused": false, "pause_reason": NSNull(), "is_warning": false,
        "credit_usd": 0.00001, "forecast": NSNull(),
    ]
    json.merge(changes) { $1 }
    return json
}

private func credits(_ changes: [String: Any] = [:]) -> AICredits {
    AICredits(json: creditsJSON(changes))!
}

/// A free plan: filters save and test, but don't score stories.
private let freeCredits: [String: Any] = [
    "included": 0, "used": 0.0, "remaining": 0.0, "is_paused": true, "pause_reason": "plan",
]

/// Running low on the 20th, at a pace that runs out on the 27th and would cost 62 cents past the plan's credits.
private let warningCredits: [String: Any] = [
    "used": 8_300, "remaining": 1_700, "is_warning": true,
    "forecast": ["credits": 72_000, "credits_per_day": 3_100, "runs_out_on": "2026-11-27", "overage_usd": 0.62],
]

/// The month's credits used up, at the same pace.
private let pausedCredits: [String: Any] = [
    "used": 10_000, "remaining": 0, "is_paused": true, "pause_reason": "credits", "is_warning": true,
    "forecast": ["credits": 72_000, "credits_per_day": 3_100, "runs_out_on": NSNull(), "overage_usd": 0.62],
]

/// Usage billing past the plan's credits, with $0.37 waiting for the $1 minimum charge.
private let billingCredits: [String: Any] = [
    "used": 47_000, "remaining": 0, "is_usage_billing": true, "overage_credits": 37_000, "overage_usd": 0.37,
    "unbilled_usd": 0.37, "is_warning": true,
]

/// Usage billing stopped at the reader's $5 monthly limit.
private let limitCredits: [String: Any] = [
    "used": 510_000, "remaining": 0, "is_usage_billing": true, "monthly_limit": 5.0, "overage_credits": 500_000,
    "overage_usd": 5.0, "is_paused": true, "pause_reason": "limit", "is_warning": true,
]

private final class PromptSaveAppDelegate: NewsBlurAppDelegate {
    var savedParameters: [[String: Any]] = []

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
        savedParameters.append(parameters as? [String: Any] ?? [:])
    }

    override func recalculateIntelligenceScores(_ feedId: Any!) {
    }
}

/// AIClassifierTests.swift keeps NewsBlurAppDelegate.m's real recalculateIntelligenceScores: and only stubs the network.
private final class RecalculatingPromptSaveAppDelegate: NewsBlurAppDelegate {
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
    }
}

/// AIClassifierTests.swift answers every classifier save right away unless the test holds them, holds each story
/// refresh until the test answers it, and its fixture host can't reach a server.
private final class RefreshingClassifierSaveAppDelegate: NewsBlurAppDelegate {
    struct StoryRequest {
        let url: String
        let parameters: [String: Any]
        let succeed: (Any?) -> Void
        let fail: () -> Void
    }

    struct HeldSave {
        let succeed: () -> Void
        let fail: () -> Void
    }

    var savesSucceed = true
    /// Holds each save's answer in heldSaves until the test sends it, like a slow network.
    var holdsSaves = false
    var heldSaves: [HeldSave] = []
    var storyRequests: [StoryRequest] = []
    var pendingDebounces: [() -> Void] = []
    var pages: StoryPagesViewController?

    override var url: String! { "https://refresh-fixture.invalid" }
    override var storyPagesViewController: StoryPagesViewController! { pages }

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        let save = HeldSave(succeed: { success(nil, ["code": 1]) },
                            fail: { failure(nil, URLError(.badServerResponse)) })
        if holdsSaves {
            heldSaves.append(save)
        } else if savesSucceed {
            save.succeed()
        } else {
            save.fail()
        }
    }

    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        storyRequests.append(StoryRequest(url: urlString, parameters: parameters as? [String: Any] ?? [:],
                                          succeed: { success(nil, $0) },
                                          fail: { failure(nil, URLError(.notConnectedToInternet)) }))
    }

    /// Ends every refresh's debounce, as if the reader stopped saving.
    func endDebounces() {
        let pending = pendingDebounces
        pendingDebounces = []
        pending.forEach { $0() }
    }
}

/// AIClassifierTests.swift pages through rescored stories with the real StoryPagesObjCViewController.m, on plain
/// views in place of the storyboard's, and counts each time it sizes its scroll view.
@MainActor private final class RescoredStoryPages: StoryPagesViewController {
    var scrollViewResizes = 0
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func resizeScrollView() {
        scrollViewResizes += 1
        super.resizeScrollView()
    }
}

/// AIClassifierTests.swift records the stories StoryPagesObjCViewController.m draws into a page instead of loading
/// them into WebKit, and counts the page as showing its story the way a loaded web view would.
@MainActor private final class RescoredStoryPage: StoryDetailViewController {
    var drawnHashes: [String] = []
    var storyDrawn: (() -> Void)?
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func drawStory() {
        drawnHashes.append(activeStory?["story_hash"] as? String ?? "missing")
        hasStory = true
        storyDrawn?()
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

    func test_savingAPromptKeepsTheServersAIAndRegexScoresOnLoadedStories() {
        // The Daring Fireball sponsor post: a disliked author, but the AI focus prompt matched, so it shows green.
        let app = RecalculatingPromptSaveAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Non-apple related news": 1],
                                                          "authors": ["Daring Fireball Department of Commerce": -1]]]
        app.storiesCollection.activeFeedStories = [[
            "story_hash": "42:sponsor",
            "story_feed_id": 42,
            "story_title": "[Sponsor] WorkOS",
            "story_authors": "Daring Fireball Department of Commerce",
            "story_tags": [String](),
            "intelligence": ["feed": 0, "author": -1, "tags": 0, "title": 0, "prompt": 1, "text_regex": 1],
        ]]

        app.savePromptClassifier("Charts", feedId: "42", score: 1, includeImages: true, scope: "feed", folderName: "")

        let story = app.storiesCollection.activeFeedStories.first as? [String: Any]
        let intelligence = story?["intelligence"] as? [String: Any]
        XCTAssertEqual(intelligence?["prompt"] as? Int, 1, "The server's AI score survives the local recalculation")
        XCTAssertEqual(intelligence?["text_regex"] as? Int, 1, "Scores the app can't recompute stay as the server sent them")
        XCTAssertEqual(intelligence?["author"] as? Int, -1, "The author score is recomputed from the classifiers")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence), 1, "The AI match still outranks the disliked author")
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
            transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1, "description": "apple"]
            // Testing a prompt isn't gated: a free account, whose saved filters don't run, still tests one.
            let model = makeModel(transport: transport, profile: Self.freeProfile)
            model.prepare(feedId: "42", storyHash: "42:abc")
            model.setDraft("  Non-apple related news ", for: .content)
            model.toggleDraftDirection(.content)

            model.runTest(.content, storyHash: "42:abc", feedId: "42")

            let request = try XCTUnwrap(transport.requests(to: "/classifier/test_prompt").first)
            XCTAssertEqual(request.parameters as NSDictionary, [
                "prompt": "Non-apple related news", "story_hash": "42:abc", "include_images": "false",
                "classifier_type": "hidden", "feed_id": "42",
            ])
            XCTAssertEqual(model.test(.content), .finished(.classified(matches: true, imageMatches: [])))
            XCTAssertEqual(model.testStatus(.content, imageCount: 0)?.text, "✓ Story matches this filter")

            model.setDraft("Non-apple related news!", for: .content)
            XCTAssertEqual(model.test(.content), .idle, "Editing the prompt clears the old result")
        }
    }

    func test_imagePromptTestShowsEachImageResult() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1, "image_results": [1, 0, 1]]
            let model = makeModel(transport: transport, profile: Self.archiveProfile)
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
        transport.responses["/classifier/test_prompt"] = ["code": -1, "message": "Story not found"]
        let model = makeModel(transport: transport, profile: Self.freeProfile)
        model.setDraft("Non-apple related news", for: .content)

        model.runTest(.content, storyHash: "42:abc", feedId: "social:9")

        XCTAssertEqual(transport.requests.first?.parameters["feed_id"] as? String, "0", "The server parses feed_id as an integer")
        let status = model.testStatus(.content, imageCount: 0)
        XCTAssertEqual(status?.text, "Story not found")
        XCTAssertEqual(status?.isError, true)
    }

    func test_promptTestResultIsDroppedWhenTheDraftChangesDuringTheRequest() {
        let transport = RecordingAITransport()
        transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1]
        transport.holdsResponses = true
        let model = makeModel(transport: transport, profile: Self.archiveProfile)
        model.setDraft("Non-apple related news", for: .content)

        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        XCTAssertEqual(transport.requests.last?.parameters["classifier_type"] as? String, "focus")
        model.toggleDraftDirection(.content)
        XCTAssertEqual(model.test(.content), .testing, "Flipping the direction waits for the running test")
        transport.releaseHeldResponses()
        XCTAssertEqual(model.test(.content), .idle, "A focus result never shows for a hide filter")
        XCTAssertNil(model.testStatus(.content, imageCount: 0))

        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        XCTAssertEqual(transport.requests.last?.parameters["classifier_type"] as? String, "hidden")
        model.setDraft("Apple news", for: .content)
        transport.releaseHeldResponses()
        XCTAssertEqual(model.test(.content), .idle, "A result for the old prompt never shows for the new one")

        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        transport.releaseHeldResponses()
        XCTAssertEqual(model.test(.content), .finished(.classified(matches: true, imageMatches: [])),
                       "An unchanged draft shows its result")
    }

    func test_promptTestNeedsAPromptAndAStory() {
        let transport = RecordingAITransport()
        let model = makeModel(transport: transport, profile: Self.archiveProfile)
        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        model.setDraft("Non-apple related news", for: .content)
        model.runTest(.content, storyHash: nil, feedId: "42")
        XCTAssertTrue(transport.requests(to: "/classifier/test_prompt").isEmpty)
    }

    /// Rule: every time the trainer opens it asks for this moment's credits and this site's estimates, so the meter
    /// never shows what the profile held when the feed list last loaded, and it hands them to the profile for the
    /// AI credits screen and the settings menu.
    func test_reopeningTheTrainerLoadsCreditsAgainAndKeepsTheDraft() throws {
        let transport = RecordingAITransport()
        transport.responses["/analyzer/ai_classifier_usage"] = [
            "code": 0, "ai_credits": creditsJSON(["used": 4_000]), "text_credits_per_month": 420, "image_credits_per_month": 3_000,
        ]
        transport.holdsResponses = true
        var stored: [[String: Any]] = []
        let model = makeModel(transport: transport, profile: Self.archiveProfile, storeCredits: { stored.append($0) })

        // TrainerViewController.swift and TrainerView.swift both prepare the model as the trainer opens.
        model.prepare(feedId: "42", storyHash: "42:abc")
        model.prepare(feedId: "42", storyHash: "42:abc")
        let fetches = transport.requests(to: "/analyzer/ai_classifier_usage")
        XCTAssertEqual(fetches.count, 1, "One open shares one fetch")
        XCTAssertEqual(fetches.first?.method, "GET")
        XCTAssertEqual(fetches.first?.parameters["feed_id"] as? String, "42")
        XCTAssertEqual(model.credits?.used, 2_340, "The profile's credits show until the server answers")
        transport.releaseHeldResponses()
        XCTAssertEqual(model.credits?.used, 4_000)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(AICredits(json: try XCTUnwrap(stored.first))?.used, 4_000)
        model.setDraft("Apple earnings coverage", for: .content)

        // The reader's filters spend more, then the trainer opens on the same story again.
        transport.responses["/analyzer/ai_classifier_usage"] = [
            "code": 0, "ai_credits": creditsJSON(pausedCredits), "text_credits_per_month": 420, "image_credits_per_month": 3_000,
        ]
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(transport.requests(to: "/analyzer/ai_classifier_usage").count, 2, "Reopening asks again")
        transport.releaseHeldResponses()
        XCTAssertEqual(model.credits?.status, .pausedForCredits, "The meter doesn't stay as the last visit left it")
        XCTAssertEqual(model.draft(.content), "Apple earnings coverage", "The same story keeps its draft")
        model.prepare(feedId: "42", storyHash: "42:def")
        XCTAssertEqual(model.draft(.content), "", "Another story starts its own")
    }

    func test_anotherAccountsTrainerForTheSameSiteStartsEmpty() {
        var account = (username: "samuel", host: "https://www.newsblur.com")
        let transport = RecordingAITransport()
        transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1]
        let model = makeModel(transport: transport, profile: Self.archiveProfile, signedInAccount: { account })
        let trainer = TrainerViewController()
        trainer.aiPrompts = model
        let saved = PromptClassifier(prompt: "Sponsored posts", kind: .content, score: -1, scope: .feed, folderName: "")

        model.prepare(feedId: "42", storyHash: "42:abc")
        model.setDraft("Non-apple related news", for: .content)
        model.runTest(.content, storyHash: "42:abc", feedId: "42")
        XCTAssertEqual(model.test(.content), .finished(.classified(matches: true, imageMatches: [])))
        model.scopeBinding(for: saved, currentFolderName: "Apple").wrappedValue = .global
        // A second test and a usage fetch are still out when the reader signs in to another account.
        transport.holdsResponses = true
        transport.responses["/analyzer/ai_classifier_usage"] = ["code": 0, "ai_credits": creditsJSON(pausedCredits)]
        model.setDraft("Apple earnings coverage", for: .image)
        model.runTest(.image, storyHash: "42:abc", feedId: "42")
        model.prepare(feedId: "42", storyHash: "42:abc")

        account = (username: "family", host: "https://www.newsblur.com")
        trainer.resetForAccountChange()
        transport.holdsResponses = false
        transport.releaseHeldResponses()
        XCTAssertEqual(model.draft(.content), "", "TrainerViewController.swift clears the last account's drafts")
        XCTAssertEqual(model.draft(.image), "")
        XCTAssertEqual(model.test(.content), .idle, "The last account's test result is gone")
        XCTAssertEqual(model.test(.image), .idle, "Its test answered after the switch never lands")
        XCTAssertNil(model.usage, "Nor do its credits")
        XCTAssertEqual(model.scope(for: saved), .feed, "Its scope choice is gone")

        // Even without the reset, the same site on another server is another trainer.
        model.prepare(feedId: "42", storyHash: "42:abc")
        model.setDraft("Charts", for: .image)
        account = (username: "family", host: "https://newsblur.example.com")
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(model.draft(.image), "")
    }

    /// Rule: a plan without credits is told so, with a way to upgrade, once it has an AI filter of either kind saved
    /// or is writing one, whichever mode the card shows. A paid plan never sees that notice, and a plan without
    /// credits has no credits row.
    func test_aPlanWithoutCreditsIsToldOnceItHasAnAIFilter() throws {
        let saved = [PromptClassifier(prompt: "Charts", kind: .image, score: 1, scope: .feed, folderName: "")]
        let removed = [PromptClassifier(prompt: "Charts", kind: .image, score: 0, scope: .feed, folderName: "")]
        var upgrades = 0

        let free = makeModel(transport: RecordingAITransport(), profile: Self.freeProfile, openUpgrade: { upgrades += 1 })
        let notice = try XCTUnwrap(free.freeNotice(saved: saved), "A saved image filter counts while the card shows Text")
        XCTAssertEqual(notice.tone, .upgrade)
        XCTAssertNil(free.creditsNotice)
        XCTAssertNil(free.freeNotice(saved: []), "Without filters there's nothing to warn about")
        XCTAssertNil(free.freeNotice(saved: removed), "A removed filter the trainer still lists doesn't count")
        free.setDraft("Charts", for: .image)
        XCTAssertNotNil(free.freeNotice(saved: []), "Writing a filter shows it before it's saved")
        free.perform(try XCTUnwrap(notice.button).action)
        XCTAssertEqual(upgrades, 1, "Upgrade opens the Premium screen")

        let archive = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile)
        XCTAssertNil(archive.freeNotice(saved: saved))
    }

    /// Rule: the card's credits row shows the month for every plan with credits, before any filter exists, and opens
    /// the AI credits screen; the estimate line names the kind of filter being written, but only while filters run.
    func test_theCreditsRowShowsTheMonthAndEachModeEstimatesItsKind() throws {
        try withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/analyzer/ai_classifier_usage"] = [
                "code": 0, "ai_credits": creditsJSON(), "text_credits_per_month": 1_428, "image_credits_per_month": 0,
            ]
            var opened: [Bool] = []
            let model = makeModel(transport: transport, profile: Self.archiveProfile, openCredits: { opened.append($0) })
            model.prepare(feedId: "42", storyHash: nil)

            let notice = try XCTUnwrap(model.creditsNotice)
            XCTAssertEqual(notice.tone, .normal)
            XCTAssertEqual(notice.meter?.usedText, "2,340 of 10,000 AI credits used")
            XCTAssertEqual(try XCTUnwrap(notice.meter?.fraction), 0.234, accuracy: 0.0001)
            XCTAssertEqual(model.estimateText(.content), "A text filter on this site uses about 1,428 credits a month")
            XCTAssertEqual(model.estimateText(.image), "An image filter on this site uses less than one credit a month",
                           "A site that published nothing last month still says what a filter would cost")
            model.perform(.openCredits)
            XCTAssertEqual(opened, [false], "The credits row opens the AI credits screen")

            transport.responses["/analyzer/ai_classifier_usage"] = [
                "code": 0, "ai_credits": creditsJSON(pausedCredits), "text_credits_per_month": 420, "image_credits_per_month": 3_000,
            ]
            model.prepare(feedId: "42", storyHash: nil)
            XCTAssertEqual(model.creditsNotice?.tone, .paused)
            XCTAssertNil(model.estimateText(.content), "Paused filters spend nothing, so there's no estimate to give")
        }
    }

    /// Rule: the Text / Images switch keeps a draft for each mode, so a filter saves as the kind it was typed in,
    /// whichever mode is showing when it's added; another site or story starts in Text.
    func test_eachModeKeepsItsDraftAndSavesAsTheKindItWasTypedIn() {
        var saves: [(String, PromptClassifierKind)] = []
        let model = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile)
        model.savePrompt = { prompt, kind, _, _, _, _ in saves.append((prompt, kind)) }
        model.prepare(feedId: "42", storyHash: "42:abc")

        model.setDraft("Apple earnings", for: model.mode)
        model.mode = .image
        model.setDraft("Charts", for: model.mode)
        model.mode = .content
        XCTAssertEqual(model.draft(.content), "Apple earnings", "Switching modes doesn't move or clear a draft")
        model.addDraft(.image, feedId: "42")
        model.addDraft(.content, feedId: "42")
        XCTAssertEqual(saves.map(\.0), ["Charts", "Apple earnings"])
        XCTAssertEqual(saves.map(\.1), [.image, .content])

        model.mode = .image
        model.prepare(feedId: "42", storyHash: "42:def")
        XCTAssertEqual(model.mode, .content)
    }

    /// Rule: every credit number shows as a whole credit rounded to the nearest, even from a server that still sends
    /// decimals, and the amount past the plan compares the rounded numbers.
    func test_creditNumbersRoundToTheNearestWholeCredit() {
        withEnglishInterface {
            XCTAssertEqual(credits(["used": 2_340.6]).usedText, "2,341 of 10,000 AI credits used")
            XCTAssertEqual(credits(["used": 10_012.6]).usedText, "10,013 AI credits used, 13 past your plan's 10,000")
            XCTAssertEqual(credits(["used": 10_000.4]).usedText, "10,000 of 10,000 AI credits used")
            XCTAssertEqual(credits(["forecast": ["credits": 16_268.7, "runs_out_on": NSNull(), "overage_usd": 0.0]]).forecastText,
                           "At this pace, this month will use about 16,269 AI credits.")
            XCTAssertEqual(AIClassifierUsage.estimateText(1_427.5, kind: .content),
                           "A text filter on this site uses about 1,428 credits a month")
            XCTAssertEqual(AIClassifierUsage.estimateText(0.6, kind: .image),
                           "An image filter on this site uses about 1 credit a month")
            XCTAssertEqual(AIClassifierUsage.estimateText(0.4, kind: .content),
                           "A text filter on this site uses less than one credit a month")
        }
    }

    /// Rule: running low warns with the day credits run out at this pace. While the app may open Stripe it offers to
    /// keep filters running and says what that would cost this month, leaving the cost out when the pace costs
    /// nothing; with UsageBillingFeature.swift off it offers nothing to pay.
    func test_runningLowWarnsWhenCreditsRunOutAndOffersBillingWithTheMonthsCost() throws {
        try withEnglishInterface {
            UsageBillingFeature.isEnabled = true
            defer { UsageBillingFeature.isEnabled = false }
            let warning = try XCTUnwrap(AICreditsNotice.make(credits(warningCredits), offersBilling: true))
            XCTAssertEqual(warning.tone, .warning)
            XCTAssertEqual(warning.messages, ["At this pace your credits run out around Nov 27."])
            XCTAssertEqual(warning.button, AICreditsNotice.ActionButton(
                title: "Keep filters running",
                detail: "Past your credits, filters keep running at 1¢ per 1,000 credits. About $0.62 this month at your pace.",
                action: .setUpBilling))

            var noCost = warningCredits
            noCost["forecast"] = ["credits": 49.0, "credits_per_day": 1.0, "runs_out_on": NSNull(), "overage_usd": 0.0]
            let calm = try XCTUnwrap(AICreditsNotice.make(credits(noCost), offersBilling: true))
            XCTAssertEqual(calm.messages, [], "No run-out day when the pace lasts the month")
            XCTAssertEqual(calm.button?.detail, "Past your credits, filters keep running at 1¢ per 1,000 credits.")

            var unavailable = warningCredits
            unavailable["is_billing_available"] = false
            XCTAssertNil(AICreditsNotice.make(credits(unavailable), offersBilling: true)?.button,
                         "A server without usage billing has nothing to set up")

            var opened: [Bool] = []
            let model = makeModel(transport: RecordingAITransport(), profile: ["ai_credits": creditsJSON(warningCredits)],
                                  openCredits: { opened.append($0) })
            model.perform(try XCTUnwrap(model.creditsNotice?.button).action)
            XCTAssertEqual(opened, [true], "Keep filters running goes straight on to setting up usage billing")
        }
    }

    /// Rule: paused filters say when they run again and that the month's credits are used. While the app may open
    /// Stripe they also offer usage billing, with this month's cost, or waiting for the 1st. Test_UsageBillingHold
    /// covers the release, where they offer nothing.
    func test_pausedFiltersSayWhenTheyRunAgainAndOfferBillingOnlyWhileTheAppMay() throws {
        try withEnglishInterface {
            let paused = try XCTUnwrap(AICreditsNotice.make(credits(pausedCredits), offersBilling: true))
            XCTAssertEqual(paused.tone, .paused)
            XCTAssertEqual(paused.meter?.fraction, 1)
            XCTAssertEqual(paused.meter?.usedText, "10,000 of 10,000 AI credits used")
            var overshot = pausedCredits
            overshot["used"] = 10_012
            let pastPlan = try XCTUnwrap(AICreditsNotice.make(credits(overshot), offersBilling: true)?.meter)
            XCTAssertEqual(pastPlan.usedText, "10,012 AI credits used, 12 past your plan's 10,000",
                           "The last request can run a little past the plan's credits")
            overshot["used"] = 10_000.4
            XCTAssertEqual(AICreditsNotice.make(credits(overshot), offersBilling: true)?.meter?.usedText,
                           "10,000 of 10,000 AI credits used", "Never \"0 past your plan's 10,000\"")
            XCTAssertEqual(paused.messages, ["Your AI filters are paused until Dec 1.", "This month's 10,000 AI credits are used."])
            XCTAssertEqual(paused.button, AICreditsNotice.ActionButton(
                title: "Turn on usage billing", detail: "1¢ per 1,000 credits past your plan's, about $0.62 this month",
                action: .setUpBilling))
            XCTAssertEqual(paused.footnote, "or wait until Dec 1")
        }
    }

    /// Rule: with usage billing on, the meter says how many credits went past the plan's and stays calm (only nearing
    /// the monthly limit warns), the trainer shows what that has cost this month and what's waiting to be charged,
    /// and a reached limit names the limit and the day filters run again. Managing either opens the AI credits screen.
    func test_usageBillingShowsTheMonthsCostAndAReachedLimit() throws {
        try withEnglishInterface {
            let billing = try XCTUnwrap(AICreditsNotice.make(credits(billingCredits), offersBilling: true))
            XCTAssertEqual(billing.meter?.usedText, "47,000 AI credits used, 37,000 past your plan's 10,000")
            XCTAssertEqual(billing.tone, .normal, "Going past the plan is what usage billing is for, so nothing warns")
            var nearLimit = billingCredits
            nearLimit["monthly_limit"] = 0.4
            XCTAssertEqual(AICreditsNotice.make(credits(nearLimit), offersBilling: true)?.tone, .warning,
                           "$0.37 of a $0.40 limit is running low")
            XCTAssertEqual(billing.messages, [
                "Usage billing is on. Credits past your 10,000 cost 1¢ per 1,000: $0.37 so far this month.",
                "$0.37 is waiting to be charged: at the start of next month if it's at least $1, or right away at $10.",
            ])
            XCTAssertEqual(billing.button?.action, .manageBilling)

            var charged = billingCredits
            charged["unbilled_usd"] = 0.0
            XCTAssertEqual(AICreditsNotice.make(credits(charged), offersBilling: true)?.messages.count, 1,
                           "Nothing waiting, nothing to explain")

            let limit = try XCTUnwrap(AICreditsNotice.make(credits(limitCredits), offersBilling: true))
            XCTAssertEqual(limit.tone, .paused)
            XCTAssertEqual(limit.messages, ["Your AI filters reached your $5.00 monthly limit and are paused until Dec 1."])
            XCTAssertEqual(limit.button?.title, "Change limit")

            var opened: [Bool] = []
            let model = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile, openCredits: { opened.append($0) })
            model.perform(.manageBilling)
            XCTAssertEqual(opened, [false])
        }
    }

    /// Rule: a server that counts no credits, like a self-hosted NewsBlur, shows nothing about them and isn't asked.
    func test_aServerThatCountsNoCreditsShowsNothingAboutThem() {
        let transport = RecordingAITransport()
        let model = makeModel(transport: transport, profile: ["ai_credits": creditsJSON(["is_unlimited": true])])
        model.prepare(feedId: "42", storyHash: nil)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(model.creditsNotice)
        XCTAssertNil(model.freeNotice(saved: []))
        XCTAssertNil(model.estimateText(.content))
    }

    func test_addingDraftSavesItInTheChosenDirection() {
        var saves: [(String, PromptClassifierKind, String, Int)] = []
        let model = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile)
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

    func test_topLevelSiteNeverScopesAPromptToAMissingFolder() {
        var moves: [String] = []
        var saves: [String] = []
        let model = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile)
        model.changeScope = { _, _, _, _, oldScope, oldFolderName, scope, folderName in
            moves.append("\(oldScope.rawValue):\(oldFolderName) -> \(scope.rawValue):\(folderName)")
        }
        model.savePrompt = { _, _, _, score, scope, folderName in saves.append("\(score) \(scope.rawValue):\(folderName)") }
        let prompt = PromptClassifier(prompt: "Sponsored posts", kind: .content, score: -1, scope: .feed, folderName: "")

        model.changeScope(prompt, to: .folder, feedId: "42", currentFolderName: "")
        XCTAssertEqual(moves, [], "The original prompt is never removed for a move with nowhere to go")
        XCTAssertEqual(model.scope(for: prompt), .feed)
        model.scopeBinding(for: prompt, currentFolderName: "").wrappedValue = .folder
        XCTAssertEqual(model.scope(for: prompt), .feed, "The scope toggle can't pick a folder the site isn't in")
        model.tap(prompt, feedId: "42", currentFolderName: "")
        XCTAssertEqual(saves, ["0 feed:"])

        model.scopeOverrides[ClassifierScopeResolver.overrideKey(type: prompt.kind.saveType, name: prompt.prompt)] = .folder
        model.tapDislike(prompt, feedId: "42", currentFolderName: "")
        XCTAssertEqual(saves, ["0 feed:"], "A folder save without a folder name, which the server makes global, is never sent")

        model.scopeOverrides = [:]
        model.changeScope(prompt, to: .global, feedId: "42", currentFolderName: "")
        XCTAssertEqual(moves, ["feed: -> global:"], "A top-level site can still go global on purpose")

        let foldered = PromptClassifier(prompt: "Apple rumors", kind: .image, score: 1, scope: .feed, folderName: "")
        model.changeScope(foldered, to: .folder, feedId: "42", currentFolderName: "Apple")
        XCTAssertEqual(moves.last, "feed: -> folder:Apple", "A site in a folder scopes to it")
    }

    func test_nestedFolderPromptFromTheAPISavesItsFullPath() {
        let app = makeNestedFolderApp()
        // apps/analyzer/models.py names a folder scope by its flatten_folders path.
        let classifiers: AnyDictionary = [
            "prompts": ["Swift evolution proposals": 1],
            "prompts_scope": ["Swift evolution proposals": ["scope": "folder", "folder_name": "Tech - Swift"]],
        ]
        let saved = PromptClassifier.saved(in: classifiers, kind: .content)
        XCTAssertEqual(saved.first?.folderName, "Tech - Swift")

        let currentFolder = ClassifierFolderPath.serverPath(forFeed: "3", appDelegate: app)
        XCTAssertEqual(currentFolder, "Tech - Swift", "A subfolder's site scopes to the subfolder's full path, not its parent or leaf name")
        XCTAssertEqual(ClassifierFolderPath.serverPath(forFeed: "2", appDelegate: app), "Tech")
        XCTAssertEqual(ClassifierFolderPath.serverPath(forFeed: "1", appDelegate: app), "", "A site outside any folder has no folder")

        let model = makeModel(transport: RecordingAITransport(), profile: Self.archiveProfile)
        model.prepare(feedId: "3", storyHash: nil)
        model.savePrompt = { prompt, kind, feedId, score, scope, folderName in
            app.savePromptClassifier(prompt, feedId: feedId, score: score, includeImages: kind.includesImages,
                                     scope: scope.rawValue, folderName: folderName)
        }
        model.tapDislike(saved[0], feedId: "3", currentFolderName: currentFolder)
        XCTAssertEqual(app.savedParameters.last as NSDictionary?,
                       ["dislike_prompt": "Swift evolution proposals", "feed_id": "3", "scope": "folder", "folder_name": "Tech - Swift"])

        var moves: [String] = []
        model.changeScope = { _, _, _, _, oldScope, oldFolderName, scope, folderName in
            moves.append("\(oldScope.rawValue):\(oldFolderName) -> \(scope.rawValue):\(folderName)")
        }
        let sitePrompt = PromptClassifier(prompt: "Server-side Swift", kind: .image, score: 1, scope: .feed, folderName: "")
        model.changeScope(sitePrompt, to: .folder, feedId: "3", currentFolderName: currentFolder)
        XCTAssertEqual(moves, ["feed: -> folder:Tech - Swift"], "Moving a site prompt to its folder names the full path too")
        model.tap(sitePrompt, feedId: "3", currentFolderName: currentFolder)
        XCTAssertEqual(app.savedParameters.last as NSDictionary?,
                       ["dislike_image_prompt": "Server-side Swift", "feed_id": "3", "scope": "folder", "folder_name": "Tech - Swift"])
    }

    /// FeedsObjCViewController.m keys folders by native path, and FeedsViewController.swift addSubfolderFeeds lists a
    /// subfolder's sites under its parent too. A top-level folder shares the subfolder's leaf name.
    private func makeNestedFolderApp() -> PromptSaveAppDelegate {
        let app = PromptSaveAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.dictFolders = ["everything": [1], "Swift": [4], "Tech": [2, 3], "Tech ▸ Swift": [3], "saved_stories": [] as [Any]]
        app.dictFoldersArray = NSMutableArray(array: ["everything", "Swift", "Tech", "Tech ▸ Swift", "saved_stories"])
        return app
    }

    /// The user_profile /reader/feeds sends: every paid plan runs AI filters on its monthly AI credits.
    private static let freeProfile: [AnyHashable: Any] = [
        "is_premium": false, "is_archive": false, "is_pro": false, "can_use_ai_classifiers": false,
        "ai_credits": creditsJSON(freeCredits),
    ]

    private static let archiveProfile: [AnyHashable: Any] = [
        "is_premium": true, "is_archive": true, "is_pro": false, "can_use_ai_classifiers": true,
        "ai_credits": creditsJSON(),
    ]

    private func makeModel(transport: RecordingAITransport, profile: [AnyHashable: Any],
                           storeCredits: @escaping ([String: Any]) -> Void = { _ in },
                           openUpgrade: @escaping () -> Void = {},
                           openCredits: @escaping (Bool) -> Void = { _ in },
                           signedInAccount: @escaping () -> (username: String, host: String) = { ("samuel", "https://www.newsblur.com") })
        -> TrainerAIPromptModel {
        TrainerAIPromptModel(api: AIClassifierAPI(transport: transport),
                             userProfile: { profile },
                             storeCredits: storeCredits,
                             openUpgrade: openUpgrade,
                             openCredits: openCredits,
                             signedInAccount: signedInAccount)
    }

    private func promptScore(_ app: NewsBlurAppDelegate, key: String, prompt: String) -> Int? {
        let feedClassifiers = app.storiesCollection.activeClassifiers["42"] as? [String: Any]
        return (feedClassifiers?[key] as? [String: Any])?[prompt] as? Int
    }
}

// MARK: - Recalculating loaded stories

/// AIClassifierTests.swift saves classifiers through NewsBlurAppDelegate.m and checks that its real
/// recalculateIntelligenceScores: scores loaded stories the way apps/analyzer/models.py does.
@MainActor final class Test_StoryClassifierRecalculation: XCTestCase {
    private let sponsorPermalink = "https://daringfireball.net/linked/2026/10/27/sponsor-workos"
    private let sponsorContent = "<p>Let agents sign up for <em>your</em> app without a browser.</p>"

    func test_removingAMatchingURLRegexMakesTheStoryNeutral() {
        // The server matched the sponsor URL regex, so the story arrives green.
        let app = makeApp(classifiers: ["url_regex": ["sponsor": 1]],
                          intelligence: ["feed": 0, "author": 0, "tags": 0, "title": 0, "url_regex": 1, "prompt": 0])
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)

        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, 0, "The removed regex no longer counts")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 0)

        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, 1, "Liking it again matches the permalink")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)
    }

    func test_addingAndRemovingATextClassifierScoresTheTextReadersSee() {
        let app = makeApp(classifiers: [:], intelligence: ["feed": 0, "text": 0, "prompt": 0], content: sponsorContent)

        app.toggleTextClassifier("Sign up for your app", feedId: "42")
        XCTAssertEqual(intelligence(app)?["text"] as? Int, 1, "Text matches case insensitively across the <em> tag")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)

        app.toggleTextClassifier("Sign up for your app", feedId: "42")
        XCTAssertEqual(intelligence(app)?["text"] as? Int, 0, "The removed text classifier no longer counts")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 0)
    }

    func test_urlScoresNeedPremiumAndRegexScoresNeedProLikeTheServer() {
        let classifiers: NSDictionary = [
            "urls": ["daringfireball.net/linked": 1],
            "url_regex": ["sponsor-\\w+": 1],
            "title_regex": ["^\\[sponsor\\]": -1],
            "author_regex": ["department of \\w+": -1],
            "texts": ["without a browser": 1],
            "text_regex": ["\\bagents?\\b": 1],
        ]
        let story: NSDictionary = [
            "story_feed_id": 42,
            "story_title": "[Sponsor] WorkOS",
            "story_authors": "Daring Fireball Department of Commerce",
            "story_permalink": sponsorPermalink,
            "story_content": sponsorContent,
        ]
        func scores(premium: Bool, archive: Bool, pro: Bool) -> [String: Int] {
            StoryClassifierScorer(classifiers: classifiers, isPremium: premium, isPremiumArchive: archive,
                                  isPremiumPro: pro).scores(forStory: story)
        }
        let unscored = ["title": 0, "author": 0, "tags": 0, "url": 0, "url_regex": 0, "title_regex": 0, "author_regex": 0,
                        "text": 0, "text_regex": 0]

        XCTAssertEqual(scores(premium: false, archive: false, pro: false), unscored)
        XCTAssertEqual(scores(premium: true, archive: false, pro: false), unscored.merging(["url": 1]) { $1 })
        XCTAssertEqual(scores(premium: true, archive: true, pro: false), unscored.merging(["url": 1, "text": 1]) { $1 })
        XCTAssertEqual(scores(premium: true, archive: false, pro: true),
                       unscored.merging(["url": 1, "url_regex": 1, "title_regex": -1, "author_regex": -1, "text": 1,
                                         "text_regex": 1]) { $1 })

        // NewsBlurAppDelegate.m passes the account's own tiers: Premium without Archive or Pro.
        let app = makeApp(classifiers: classifiers as! [String: Any],
                          intelligence: ["url": 1, "url_regex": 1, "text": 1, "text_regex": 1], content: sponsorContent,
                          isPremium: true, isPremiumArchive: false, isPremiumPro: false)
        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["url"] as? Int, 1)
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, 0)
        XCTAssertEqual(intelligence(app)?["text"] as? Int, 0)
        XCTAssertEqual(intelligence(app)?["text_regex"] as? Int, 0)
    }

    func test_aStoryLoadedWithoutContentKeepsTheServersTextScores() {
        let app = makeApp(classifiers: ["texts": ["without a browser": 0], "url_regex": ["sponsor": 0]],
                          intelligence: ["text": 1, "text_regex": -1, "url_regex": 1, "prompt": 1])

        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["text"] as? Int, 1, "Without the content there is nothing to match again")
        XCTAssertEqual(intelligence(app)?["text_regex"] as? Int, -1)
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, 0, "The permalink is loaded, so its score is recomputed")
        XCTAssertEqual(intelligence(app)?["prompt"] as? Int, 1, "The app can't run the AI, so its score stays")
    }

    func test_aRegexThatRunsOutOfTimeKeepsTheServersScoreAndIsNotSearchedAgainThisPass() {
        // (a+)+$ tries every way to split a run of a's before giving up, so this content would take years unbounded.
        let classifiers: NSDictionary = ["text_regex": ["(a+)+$": 1]]
        let longContent = "<p>" + String(repeating: "a", count: 20_000) + "!</p>"
        let longStory: NSDictionary = ["story_feed_id": 42, "story_content": longContent]
        let shortStory: NSDictionary = ["story_feed_id": 42, "story_content": "<p>aaaa</p>"]
        let scorer = StoryClassifierScorer(classifiers: classifiers, isPremium: true, isPremiumArchive: true, isPremiumPro: true)

        let started = ProcessInfo.processInfo.systemUptime
        XCTAssertNil(scorer.scores(forStory: longStory)["text_regex"],
                     "The server gives the search 100ms to the app's 50ms, so a timeout can't say it doesn't match")
        // The search checks its deadline every fraction of a millisecond. The margin only absorbs CI runner stalls.
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started,
                          TrainerRegexMatcher.drawingBudget + SimulatorTestTiming.realWorkTimeout)
        XCTAssertNil(scorer.scores(forStory: shortStory)["text_regex"],
                     "A slow pattern costs the main thread one budget per recalculation, not one per loaded story")

        let nextPass = StoryClassifierScorer(classifiers: classifiers, isPremium: true, isPremiumArchive: true, isPremiumPro: true)
        XCTAssertEqual(nextPass.scores(forStory: shortStory)["text_regex"], 1, "The next recalculation tries the pattern again")

        // The server matched the pattern within its budget, so the story arrives green and stays green.
        let app = makeApp(classifiers: classifiers as! [String: Any], intelligence: ["text_regex": 1, "prompt": 0],
                          content: longContent)
        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["text_regex"] as? Int, 1, "A search the app gave up on keeps the server's score")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)
    }

    func test_aPatternAlsoTrainedForAFolderOrAllSitesKeepsTheServersScore() {
        // get_classifiers_for_user sends one score per pattern. This site's URL classifier is a -2 and the global one
        // for the same pattern is a +1; the payload shows only the +1 and its scope, and the server scored -2.
        let global = ["scope": "global", "folder_name": ""]
        let appleFolder = ["scope": "folder", "folder_name": "Apple"]
        let app = makeApp(classifiers: ["urls": ["daringfireball.net/linked": 1],
                                        "url_regex": ["sponsor": 0],
                                        "urls_scope": ["daringfireball.net/linked": global, "sponsor": global],
                                        "author_regex": ["department of \\w+": 1],
                                        "authors_scope": ["department of \\w+": appleFolder],
                                        "titles": ["WorkOS": 1],
                                        "titles_scope": ["WorkOS": global]],
                          intelligence: ["url": -2, "url_regex": -1, "author_regex": -1, "title": -2, "prompt": 0])

        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["title"] as? Int, -2, "Title classifiers too")
        XCTAssertEqual(intelligence(app)?["url"] as? Int, -2, "The +1 shown may hide this site's -2 for the same URL")
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, -1,
                       "Removing the global copy of a pattern can leave this site's copy, which the server still scores")
        XCTAssertEqual(intelligence(app)?["author_regex"] as? Int, -1, "Author regex scopes arrive in authors_scope")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), -2)
    }

    func test_aMatchingSuperDislikeOrAScopedPatternThatDoesntMatchStillLetsTheAppScore() {
        let global = ["scope": "global", "folder_name": ""]
        let app = makeApp(classifiers: ["urls": ["daringfireball.net/linked": 1, "sponsor-workos": -2],
                                        "urls_scope": ["daringfireball.net/linked": global, "sponsor-workos": global],
                                        "title_regex": ["^\\[sponsor\\]": -1, "giveaway": 1],
                                        "titles_scope": ["giveaway": global]],
                          intelligence: ["url": 1, "title_regex": 0, "prompt": 0])

        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["url"] as? Int, -2,
                       "The server returns on the first matching super dislike, whatever the hidden classifier scores")
        XCTAssertEqual(intelligence(app)?["title_regex"] as? Int, -1,
                       "A scoped pattern that doesn't match the story can't change its score")
    }

    func test_aPythonRegexThatICUCantCompileKeepsTheServersScore() {
        // apps/analyzer/views.py saved this because Python's re compiles it, but ICU has no (?P<name>...) groups.
        let pattern = "(?P<label>sponsor)"
        XCTAssertThrowsError(try NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
        let app = makeApp(classifiers: ["title_regex": [pattern: 1], "url_regex": [pattern: -1]],
                          intelligence: ["title_regex": 1, "url_regex": -1, "prompt": 0])

        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["title_regex"] as? Int, 1, "The server matched [Sponsor] WorkOS")
        XCTAssertEqual(intelligence(app)?["url_regex"] as? Int, -1, "The server matched the sponsor permalink")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)
    }

    func test_aMatchingSuperDislikeSettlesAScoreTheAppCouldntOtherwiseTell() {
        // The server returns on the first matching super dislike, so whatever the slow pattern does can't matter.
        let classifiers: [String: Any] = ["text_regex": ["(a+)+$": 1, "a!": -2]]
        let app = makeApp(classifiers: classifiers, intelligence: ["text_regex": 1, "prompt": 0],
                          content: "<p>" + String(repeating: "a", count: 20_000) + "!</p>")

        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["text_regex"] as? Int, -2)
    }

    func test_titleClassifiersMatchLikeTheServer() {
        // apps/analyzer/models.py classifier_title_matches, each checked against Python 3's str.lower and isalnum.
        let cases: [(title: String, classifier: String, matches: Bool)] = [
            ("Apple launches a new iPad", "apple", true),
            ("APPLE LAUNCH", "Apple", true),
            ("Pineapple prices fall", "apple", false),
            ("Pineapple and Apple", "apple", true),
            ("iPhone 17 review", "Phone", false),
            // A classifier that doesn't start with a word character can match inside one.
            ("ASP.NET Core", ".net", true),
            ("my_tag cloud", "tag", false),
            ("4K TVs", "k tv", false),
            ("\u{0663}D printing", "d printing", false),
            ("\u{65B0}iPhone", "iphone", false),
            // A combining accent is a word character, so "clair" doesn't start a word in éclair written that way.
            ("e\u{0301}clair recipes", "clair", false),
            ("Caf\u{00E9} cr\u{00E8}me", "cr\u{00E8}me", true),
            // Python lowercases İ to i and a combining dot, and a word's last capital sigma to ς.
            ("\u{0130}stanbul guide", "istanbul", false),
            ("\u{0130}stanbul guide", "\u{0130}stanbul", true),
            ("\u{039F}\u{0394}\u{039F}\u{03A3} \u{03A0}\u{0391}\u{039D}", "\u{03BF}\u{03B4}\u{03BF}\u{03C3}", false),
            ("\u{039F}\u{0394}\u{039F}\u{03A3} \u{03A0}\u{0391}\u{039D}", "\u{039F}\u{0394}\u{039F}\u{03A3}", true),
            ("", "apple", false),
            ("Apple", "", false),
        ]
        for (title, classifier, matches) in cases {
            XCTAssertEqual(ClassifierTextMatching.titleMatches(title, classifier: classifier), matches,
                           "\(classifier) in \(title)")
        }
    }

    func test_authorAndTagClassifiersNeedTheExactTextLikeTheServer() {
        let author = "Daring Fireball Department of Commerce"
        XCTAssertTrue(ClassifierTextMatching.isSameText(author, "Daring Fireball Department of Commerce"))
        XCTAssertFalse(ClassifierTextMatching.isSameText(author, "daring fireball department of commerce"))
        XCTAssertFalse(ClassifierTextMatching.isSameText(author, "Department of Commerce"))
        XCTAssertFalse(ClassifierTextMatching.isSameText("Jos\u{00E9} Valim", "Jose\u{0301} Valim"),
                       "Python compares code points, so an accent written another way is another author")

        let app = makeApp(classifiers: ["titles": ["sponsor": 1, "os": -1],
                                        "authors": ["Department of Commerce": -1],
                                        "tags": ["sponsored": -1, "Apple": 1]],
                          intelligence: ["title": 0, "author": -1, "tags": 0, "prompt": 0], tags: ["Sponsored", "Apple"])
        app.recalculateIntelligenceScores("42")
        XCTAssertEqual(intelligence(app)?["title"] as? Int, 1,
                       "\"sponsor\" matches [Sponsor] in any case, and \"os\" inside WorkOS doesn't start a word")
        XCTAssertEqual(intelligence(app)?["author"] as? Int, 0, "Part of the author's name isn't the author")
        XCTAssertEqual(intelligence(app)?["tags"] as? Int, 1, "A tag matches only in its own case")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 1)
    }

    func test_removingADislikedAuthorShowsTheHiddenStoryRightAway() {
        let app = makeApp(classifiers: ["authors": ["Daring Fireball Department of Commerce": -1]],
                          intelligence: ["author": -1, "prompt": 0])
        XCTAssertEqual(app.storiesCollection.activeFeedStoryLocationIds as? [String], [], "Hidden at neutral")

        app.toggleAuthorClassifier("Daring Fireball Department of Commerce", feedId: "42")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(app)), 0)
        XCTAssertEqual(app.storiesCollection.activeFeedStoryLocationIds as? [String], ["42:sponsor"],
                       "The list and paging show a story as soon as its score reaches the selected level")
        XCTAssertEqual(app.storiesCollection.storyLocationsCount, 1)
    }

    func test_aPassStopsMatchingOnceItsBudgetIsSpentAndTheRestKeepTheServersScores() {
        // Every look at the clock costs 10ms of the 100ms budget, like a regex slow enough to take that long.
        var now: TimeInterval = 0
        let scorer = StoryClassifierScorer(classifiers: ["text_regex": ["agents?": 1], "title_regex": ["sponsor": -1]],
                                           isPremium: true, isPremiumArchive: true, isPremiumPro: true,
                                           budget: StoryClassifierScorer.passBudget,
                                           clock: { now += 0.01; return now }, textCache: StoryVisibleTextCache())
        let stories: [NSDictionary] = (0..<50).map { index in
            ["story_hash": "42:\(index)", "story_feed_id": 42, "story_title": "[Sponsor] WorkOS \(index)",
             "story_permalink": sponsorPermalink, "story_content": sponsorContent,
             "intelligence": ["text_regex": -1, "title_regex": 0]]
        }

        let scores = stories.map { scorer.scores(forStory: $0) }
        XCTAssertEqual(scores.first?["text_regex"], 1)
        XCTAssertEqual(scores.first?["title_regex"], -1)
        XCTAssertNil(scores.last?["text_regex"], "Past the budget, the server's score stays")
        XCTAssertNil(scores.last?["title_regex"])
        XCTAssertEqual(scores.last?["url"], 0, "Matching a URL without a regex is cheap and keeps going")
        let scored = scores.prefix { $0["text_regex"] != nil }.count
        XCTAssertGreaterThan(scored, 0)
        XCTAssertLessThan(scored, 10, "The pass stopped matching long before the end of the list")
        XCTAssertTrue(scores.dropFirst(scored).allSatisfy { $0["text_regex"] == nil }, "Once spent, it stays spent")
        XCTAssertEqual(scorer.uncertainStoryHashes, Set(stories.dropFirst(scored).compactMap { $0["story_hash"] as? String }),
                       "Every story it stopped on is left for StoryScoreRefresher.swift to ask the server about")
    }

    func test_aStorysTextIsStrippedOnceAndOnlyReusedForTheSameContent() {
        let cache = StoryVisibleTextCache()
        let content = sponsorContent as NSString
        func score(_ content: NSString) -> Int? {
            let scorer = StoryClassifierScorer(classifiers: ["texts": ["sign up for your app": 1]], isPremium: true,
                                               isPremiumArchive: true, isPremiumPro: false,
                                               budget: StoryClassifierScorer.passBudget,
                                               clock: StoryClassifierScorer.threadTime, textCache: cache)
            return scorer.scores(forStory: ["story_hash": "42:sponsor", "story_feed_id": 42, "story_content": content])["text"]
        }

        XCTAssertEqual(score(content), 1)
        let stripped = StoryVisibleTextCache.Text(text: "Let agents sign up for your app without a browser.",
                                                  lowercased: "let agents sign up for your app without a browser.")
        XCTAssertEqual(cache.text(forStoryHash: "42:sponsor", content: content), stripped)
        XCTAssertEqual(cache.text(forStoryHash: "42:sponsor", content: NSString(string: sponsorContent)), stripped,
                       "A copy of the same content finds it too")

        // The next pass matches the cached text instead of stripping the HTML again.
        cache.store(StoryVisibleTextCache.Text(text: "Cached", lowercased: "cached"), forStoryHash: "42:sponsor", content: content)
        XCTAssertEqual(score(content), 0)
        XCTAssertEqual(score("<p>Now you can sign up for your app.</p>"), 1, "Changed content is stripped again")
    }

    func test_aStoryWithoutContentIsUncertainOnlyWhenItsTextScoresMayHaveChanged() {
        func isUncertain(_ classifiers: NSDictionary, _ intelligence: [String: Int]) -> Bool {
            let scorer = StoryClassifierScorer(classifiers: classifiers, isPremium: true, isPremiumArchive: true, isPremiumPro: true)
            _ = scorer.scores(forStory: ["story_hash": "42:sponsor", "story_feed_id": 42, "story_permalink": sponsorPermalink,
                                         "intelligence": intelligence])
            return scorer.uncertainStoryHashes.contains("42:sponsor")
        }

        XCTAssertFalse(isUncertain([:], ["text": 0, "text_regex": 0]), "No classifier could score it")
        XCTAssertTrue(isUncertain(["texts": ["without a browser": 1]], ["text": 0]), "A text classifier the app can't match")
        XCTAssertTrue(isUncertain(["texts": ["without a browser": 0]], ["text": 1]),
                      "The server's match came from a classifier since removed")
        XCTAssertTrue(isUncertain(["text_regex": ["agents?": 1]], [:]))
    }

    private func makeApp(classifiers: [String: Any], intelligence: [String: Int], content: String? = nil,
                         tags: [String] = [], isPremium: Bool = true, isPremiumArchive: Bool = true,
                         isPremiumPro: Bool = true) -> NewsBlurAppDelegate {
        let app = RecalculatingPromptSaveAppDelegate()
        app.isPremium = isPremium
        app.isPremiumArchive = isPremiumArchive
        app.isPremiumPro = isPremiumPro
        app.selectedIntelligence = 0
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.storiesCollection.activeClassifiers = ["42": classifiers]
        var story: [String: Any] = [
            "story_hash": "42:sponsor",
            "story_feed_id": 42,
            "story_title": "[Sponsor] WorkOS",
            "story_authors": "Daring Fireball Department of Commerce",
            "story_permalink": sponsorPermalink,
            "story_tags": tags,
            "intelligence": intelligence,
        ]
        if let content {
            story["story_content"] = content
        }
        app.storiesCollection.setStories([story])
        return app
    }

    private func intelligence(_ app: NewsBlurAppDelegate) -> [String: Any]? {
        (app.storiesCollection.activeFeedStories.first as? [String: Any])?["intelligence"] as? [String: Any]
    }
}

// MARK: - Refreshing scores from the server

/// AIClassifierTests.swift checks that a classifier save asks apps/reader/views.py for loaded stories' scores only
/// when it changed one the app couldn't settle, asks for the uncertain stories and those near the screen, and that
/// the scores only land on the story list they were asked for.
@MainActor final class Test_StoryScoreRefresh: XCTestCase {
    func test_aPromptSaveRefreshesTheSitesStoriesNearTheScreenOnceSavesPause() {
        let app = makeApp()

        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        XCTAssertTrue(app.storyRequests.isEmpty, "The refresh waits for the reader to stop saving")
        app.endDebounces()

        XCTAssertEqual(app.storyRequests.count, 1)
        XCTAssertEqual(app.storyRequests.first?.url, "https://refresh-fixture.invalid/reader/river_stories")
        XCTAssertEqual(app.storyRequests.first?.parameters["h"] as? [String], ["42:sponsor", "42:keynote"],
                       "Only the saved site's loaded stories")
        XCTAssertEqual(app.storyRequests.first?.parameters["include_hidden"] as? String, "true",
                       "Hidden stories need their new scores too")
        XCTAssertEqual(app.storyRequests.first?.parameters["include_story_content"] as? String, "false",
                       "Only the scores are needed, not each story's text again")
    }

    func test_savesTheAppCanScoreItselfSendNoRefresh() {
        let app = makeApp()

        app.toggleTitleClassifier("Sponsor", feedId: "42", score: 1)
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["title"] as? Int, 1, "The recalculation shows it")
        app.toggleAuthorClassifier("Daring Fireball Department of Commerce", feedId: "42")
        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        app.toggleTextRegexClassifier("agents?", feedId: "42")
        app.toggleFeedClassifier("42")
        app.endDebounces()

        XCTAssertTrue(app.storyRequests.isEmpty, "Nothing was left uncertain, so the server has nothing to add")
    }

    func test_aPromptSaveAndAScopeMoveEachAskForARefresh() {
        let app = makeApp()

        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "The app can't run the AI")
        app.storyRequests[0].succeed(response(prompt: -1, for: ["42:sponsor", "42:keynote"]))

        app.toggleTitleClassifier("Sponsor", feedId: "42", score: 1)
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "A landed refresh isn't asked for again")

        app.changeClassifierScope("url", value: "daringfireball.net", feedId: "42", score: 1,
                                  oldScope: "feed", oldFolderName: "", scope: "global", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 2, "Moving a classifier to all sites changes what the server matches")
    }

    func test_rapidSavesShareOneRefresh() {
        let app = makeApp()

        app.toggleAuthorClassifier("Daring Fireball Department of Commerce", feedId: "42")
        app.toggleTitleClassifier("Sponsor", feedId: "42", score: 1)
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.changeClassifierScope("url", value: "daringfireball.net", feedId: "42", score: 1,
                                  oldScope: "feed", oldFolderName: "", scope: "global", folderName: "")
        XCTAssertEqual(app.pendingDebounces.count, 4, "Each save that lands checks for a refresh once saves pause")

        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "Saves made before the wait ends share one refresh")
    }

    func test_anUncertainRegexRefreshesOnlyTheAffectedStoriesAndThoseNearTheScreen() throws {
        // The sponsor URL regex is also trained for all sites, so the app can't tell which score the server keeps for
        // the two sponsor posts. The reader has the 150th story open.
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["url_regex": ["sponsor": 1],
                                                          "urls_scope": ["sponsor": ["scope": "global", "folder_name": ""]]]]
        let hashes = (0..<300).map { $0 == 10 || $0 == 290 ? "42:sponsor-\($0)" : "42:\($0)" }
        app.storiesCollection.setStories(hashes.map { story($0) })
        app.activeStory = loadedStory("42:150", in: app)

        app.toggleTitleClassifier("Keynote", feedId: "42", score: 1)
        app.endDebounces()

        let requested = try XCTUnwrap(app.storyRequests.first?.parameters["h"] as? [String])
        XCTAssertEqual(app.storyRequests.count, 1)
        XCTAssertEqual(requested, ["42:sponsor-10"] + (125...175).map { "42:\($0)" } + ["42:sponsor-290"],
                       "The uncertain stories, and those within a page of the open one, in list order")
    }

    func test_aRefreshAsksForAtMostOneBatchNearestTheScreen() throws {
        // ICU can't compile this Python pattern, so every story's title regex score is uncertain.
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["title_regex": ["(?P<label>story)": 1]]]
        app.storiesCollection.setStories((0..<300).map { story("42:\($0)") })
        app.activeStory = loadedStory("42:150", in: app)

        app.toggleTitleClassifier("Keynote", feedId: "42", score: 1)
        app.endDebounces()

        // apps/reader/views.py load_river_stories__redis reads the first 100 hashes of a request.
        XCTAssertEqual(app.storyRequests.count, 1, "One request at a time, however many stories are uncertain")
        XCTAssertEqual(app.storyRequests.first?.parameters["h"] as? [String], (100...199).map { "42:\($0)" })

        app.storiesCollection.activeFeedStories = [story("7:other", feedId: 7)]
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "A site with no loaded stories asks for nothing")
    }

    func test_storiesPastTheFirstBatchGetTheirScoresFromTheBatchesThatFollow() throws {
        // ICU can't compile this Python pattern, so all 300 stories' title regex scores are uncertain. The reader has
        // the 150th story open.
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["title_regex": ["(?P<label>story)": 1]]]
        app.storiesCollection.setStories((0..<300).map { story("42:\($0)") })
        app.activeStory = loadedStory("42:150", in: app)
        app.toggleTitleClassifier("Keynote", feedId: "42", score: 1)
        app.endDebounces()

        XCTAssertEqual(try requestedHashes(0, in: app), hashes(100...199))
        app.storyRequests[0].succeed(titleRegexScores(for: try requestedHashes(0, in: app)))
        XCTAssertEqual(app.storyRequests.count, 2, "The next batch goes out once the first lands")
        XCTAssertEqual(try requestedHashes(1, in: app), hashes(50...99) + hashes(200...249), "Nearest the screen first")

        // The list loses its last 50 stories while the second batch is out.
        app.storiesCollection.setStories(Array(app.storiesCollection.activeFeedStories.prefix(250)))
        app.storyRequests[1].succeed(titleRegexScores(for: try requestedHashes(1, in: app)))
        XCTAssertEqual(try requestedHashes(2, in: app), hashes(0...49), "Stories no longer loaded are dropped")
        app.storyRequests[2].succeed(titleRegexScores(for: try requestedHashes(2, in: app)))

        XCTAssertEqual(app.storyRequests.count, 3, "Nothing is left to ask for")
        XCTAssertEqual((0..<250).filter { intelligence(of: "42:\($0)", in: app)?["title_regex"] as? Int != 1 }, [],
                       "Every loaded story has the server's score")
    }

    func test_aSaveWhileABatchIsOutDropsItAndAsksAgainOnceTheSaveAnswers() throws {
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["title_regex": ["(?P<label>story)": 1]]]
        app.storiesCollection.setStories((0..<300).map { story("42:\($0)") })
        app.activeStory = loadedStory("42:150", in: app)
        app.toggleTitleClassifier("Keynote", feedId: "42", score: 1)
        app.endDebounces()
        app.storyRequests[0].succeed(titleRegexScores(for: try requestedHashes(0, in: app)))
        XCTAssertEqual(app.storyRequests.count, 2)

        app.holdsSaves = true
        app.toggleTitleClassifier("Keynote", feedId: "42", score: 0)
        app.storyRequests[1].succeed(titleRegexScores(for: try requestedHashes(1, in: app)))
        XCTAssertNil(intelligence(of: "42:99", in: app)?["title_regex"], "Scores from before the save never land")
        XCTAssertEqual(app.storyRequests.count, 2, "No batch goes out while the save is out")

        app.heldSaves[0].succeed()
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 3)
        XCTAssertEqual(try requestedHashes(2, in: app), hashes(100...199),
                       "The save left every story uncertain again, so its refresh starts nearest the screen")
    }

    func test_theServersScoresReplaceTheLocalGuessIncludingAIPrompts() {
        // The sponsor post shows green only because the AI focus prompt matched it, and the reader removes the prompt.
        let app = makeApp()
        var stories = app.storiesCollection.activeFeedStories ?? []
        stories.append(story("42:rerun", title: "Apple's October event, again", intelligence: ["prompt": 0]))
        app.storiesCollection.activeFeedStories = stories
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false,
                                 scope: "feed", folderName: "")
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["prompt"] as? Int, 1,
                       "The app can't run the AI, so its recalculation keeps the old match")
        app.endDebounces()

        let sponsor = ["feed": 0, "author": -1, "tags": 0, "title": 0, "title_regex": 0, "author_regex": 0, "text": 0,
                       "text_regex": 0, "url": 0, "url_regex": 0, "prompt": 0]
        let keynote = sponsor.merging(["author": 0, "prompt": 1]) { $1 }
        let keynotePill: [String: Any] = ["prompt": "Apple event coverage", "score": 1, "include_images": false]
        let refreshedStories: [[String: Any]] = [
            ["story_hash": "42:sponsor", "story_feed_id": 42, "story_title": "Renamed on the server",
             "intelligence": sponsor, "score": -1, "prompt_classifiers": [Any]()],
            ["story_hash": "42:keynote", "story_feed_id": 42, "intelligence": keynote, "score": 1,
             "prompt_classifiers": [keynotePill],
             // apps/clustering/models.py folded the rerun under the keynote it repeats.
             "cluster_stories": [["story_hash": "42:rerun", "story_feed_id": 42, "intelligence": keynote, "score": 1]]],
            ["story_hash": "7:other", "story_feed_id": 7, "intelligence": keynote, "score": 1],
        ]
        app.storyRequests[0].succeed(["stories": refreshedStories])

        let refreshedSponsor = loadedStory("42:sponsor", in: app)
        XCTAssertEqual(refreshedSponsor?["intelligence"] as? NSDictionary, sponsor as NSDictionary,
                       "The AI match is gone once the server scores the story")
        XCTAssertEqual(refreshedSponsor?["score"] as? Int, -1)
        XCTAssertEqual((refreshedSponsor?["prompt_classifiers"] as? [Any])?.count, 0, "Its AI pill goes with it")
        XCTAssertEqual(refreshedSponsor?["story_title"] as? String, "[Sponsor] WorkOS", "Only the scores change")
        XCTAssertEqual(refreshedSponsor?["story_content"] as? String, "<p>Let agents sign up for your app.</p>")

        let refreshedKeynote = loadedStory("42:keynote", in: app)
        XCTAssertEqual(refreshedKeynote?["intelligence"] as? NSDictionary, keynote as NSDictionary,
                       "A prompt match the app couldn't see arrives with the refresh")
        XCTAssertEqual((refreshedKeynote?["prompt_classifiers"] as? [[String: Any]])?.first?["prompt"] as? String,
                       "Apple event coverage")
        XCTAssertEqual(intelligence(of: "42:rerun", in: app)?["prompt"] as? Int, 1,
                       "A story the server folded into a cluster still gets its score")
        XCTAssertEqual(intelligence(of: "7:other", in: app)?["prompt"] as? Int, 0, "Another site's story wasn't asked for")
    }

    func test_aFoldedStoryTakesItsAIPillsFromItsClusterMember() {
        // The reruns matched the AI focus prompt the reader removes, and the server folds both under the keynote.
        let app = makeApp()
        let prompt = "Non-apple related news"
        let oldPill: [String: Any] = ["prompt": prompt, "score": 1, "include_images": false]
        var rerun = story("42:rerun", title: "Apple's October event, again", intelligence: ["prompt": 1])
        rerun["prompt_classifiers"] = [oldPill]
        var recap = story("42:recap", title: "Apple's October event, recapped", intelligence: ["prompt": 1])
        recap["prompt_classifiers"] = [oldPill]
        app.storiesCollection.activeFeedStories = (app.storiesCollection.activeFeedStories ?? []) + [rerun, recap]
        XCTAssertTrue(pillsHTML(of: "42:rerun", in: app).contains(prompt))
        app.savePromptClassifier(prompt, feedId: "42", score: 0, includeImages: false, scope: "feed", folderName: "")
        app.endDebounces()

        let unmatched = ["prompt": 0]
        app.storyRequests[0].succeed(["stories": [
            ["story_hash": "42:keynote", "story_feed_id": 42, "intelligence": unmatched, "score": 0,
             "prompt_classifiers": [Any](),
             "cluster_stories": [
                ["story_hash": "42:rerun", "story_feed_id": 42, "intelligence": unmatched, "score": 0,
                 "prompt_classifiers": [Any]()],
                // A server from before apps/clustering/models.py sent members' prompt_classifiers.
                ["story_hash": "42:recap", "story_feed_id": 42, "intelligence": unmatched, "score": 0],
             ]],
        ]])

        XCTAssertEqual(intelligence(of: "42:rerun", in: app)?["prompt"] as? Int, 0)
        XCTAssertEqual(pillsHTML(of: "42:rerun", in: app), "", "The folded story's AI pill goes with the prompt")
        XCTAssertEqual(intelligence(of: "42:recap", in: app)?["prompt"] as? Int, 0)
        XCTAssertTrue(pillsHTML(of: "42:recap", in: app).contains(prompt),
                      "A member without prompt_classifiers leaves the story's pills as they were")
    }

    func test_aStoryShowingInFocusStaysWhenTheRefreshLowersItsScore() {
        // Focus. The reader adds an AI hide prompt, then likes a URL regex that shows the keynote locally, so they may
        // be looking at it when the prompt's lower score arrives. The sponsor post wasn't showing and isn't kept.
        let app = makeApp(selectedIntelligence: 1)
        app.storiesCollection.setStories([story("42:keynote", intelligence: ["prompt": 0]),
                                          story("42:sponsor", intelligence: ["author": -1])])
        XCTAssertEqual(visibleHashes(in: app), [])
        app.savePromptClassifier("Apple events", feedId: "42", score: -1, includeImages: false, scope: "feed",
                                 folderName: "")
        app.toggleUrlRegexClassifier("keynote", feedId: "42")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(intelligence(of: "42:keynote", in: app)), 1)
        XCTAssertNil(loadedStory("42:keynote", in: app)?["sticky"], "It wasn't showing before the save")
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote"], "The local recalculation shows it in Focus")
        app.endDebounces()

        app.storyRequests[0].succeed(response(prompt: -1, for: ["42:keynote", "42:sponsor"]))
        XCTAssertEqual(intelligence(of: "42:keynote", in: app)?["prompt"] as? Int, -1)
        XCTAssertEqual(loadedStory("42:keynote", in: app)?["sticky"] as? Bool, true,
                       "Like recalculateIntelligenceScores:, a story the reader can see stays until they leave")
        XCTAssertNil(loadedStory("42:sponsor", in: app)?["sticky"])
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote"])
    }

    func test_aStoryTheRefreshRaisesToTheSelectedLevelJoinsTheList() {
        // The reader hid sponsor posts with an AI prompt and now removes it. The app can't run the AI, so the sponsor
        // post stays hidden until the server's score arrives.
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Sponsor posts": -1]]]
        app.storiesCollection.setStories([story("42:sponsor", title: "[Sponsor] WorkOS", intelligence: ["prompt": -1]),
                                          story("42:keynote", title: "Apple's October event", intelligence: ["prompt": 0])])
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote"])

        app.savePromptClassifier("Sponsor posts", feedId: "42", score: 0, includeImages: false, scope: "feed",
                                 folderName: "")
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote"], "The local recalculation keeps the AI's score")
        app.endDebounces()

        app.storyRequests[0].succeed(response(prompt: 0, for: ["42:sponsor", "42:keynote"]))
        XCTAssertEqual(visibleHashes(in: app), ["42:sponsor", "42:keynote"],
                       "Scored neutral by the server, the sponsor post shows in the list and paging")
        XCTAssertEqual(app.storiesCollection.storyLocationsCount, 2)
    }

    func test_theOpenStoryKeepsItsPageWhenAStoryJoinsAboveIt() {
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Sponsor posts": -1]]]
        app.storiesCollection.setStories([story("42:sponsor", intelligence: ["prompt": -1]),
                                          story("42:keynote", intelligence: ["prompt": 0]),
                                          story("42:review", intelligence: ["prompt": 0])])
        let pages = openPager(at: "42:keynote", in: app)
        let (previous, open, next) = (page(pages.previousPage), page(pages.currentPage), page(pages.nextPage))

        app.savePromptClassifier("Sponsor posts", feedId: "42", score: 0, includeImages: false, scope: "feed",
                                 folderName: "")
        app.endDebounces()
        app.storyRequests[0].succeed(response(prompt: 0, for: ["42:sponsor"]))
        XCTAssertEqual(visibleHashes(in: app), ["42:sponsor", "42:keynote", "42:review"])

        waitForDraw(of: "42:sponsor", into: previous)
        XCTAssertEqual(open.pageIndex, 1, "The keynote's page moves down one as the sponsor post joins above it")
        XCTAssertEqual(open.activeStoryId, "42:keynote")
        XCTAssertEqual(open.drawnHashes, [], "The open article isn't drawn again")
        XCTAssertEqual(shownPage(of: pages), 1, "The reader still sees the keynote")
        XCTAssertEqual(previous.pageIndex, 0)
        XCTAssertEqual(previous.activeStoryId, "42:sponsor", "Paging back shows the sponsor post")
        XCTAssertEqual(next.pageIndex, 2)
        XCTAssertEqual(next.activeStoryId, "42:review")
        XCTAssertEqual(next.drawnHashes, ["42:review"], "The next page already showed the review")
        XCTAssertEqual(pageCount(of: pages), 3)
    }

    func test_theNextPageShowsAStoryThatJoinsRightAfterTheOpenOne() {
        // The keynote is open and the review is the next page, with the hidden sponsor post between them.
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Sponsor posts": -1]]]
        app.storiesCollection.setStories([story("42:keynote", intelligence: ["prompt": 0]),
                                          story("42:sponsor", intelligence: ["prompt": -1]),
                                          story("42:review", intelligence: ["prompt": 0])])
        let pages = openPager(at: "42:keynote", in: app)
        let (open, next) = (page(pages.currentPage), page(pages.nextPage))
        XCTAssertEqual(next.activeStoryId, "42:review")
        XCTAssertEqual(pageCount(of: pages), 2)

        app.savePromptClassifier("Sponsor posts", feedId: "42", score: 0, includeImages: false, scope: "feed",
                                 folderName: "")
        app.endDebounces()
        app.storyRequests[0].succeed(response(prompt: 0, for: ["42:sponsor"]))
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote", "42:sponsor", "42:review"])

        XCTAssertEqual(next.activeStoryId, "42:sponsor", "Paging forward shows the sponsor post the list shows next")
        XCTAssertEqual(next.pageIndex, 1)
        XCTAssertEqual(pageCount(of: pages), 3, "The pager reaches the review on the third page")
        waitForDraw(of: "42:sponsor", into: next)
        XCTAssertEqual(open.pageIndex, 0)
        XCTAssertEqual(open.activeStoryId, "42:keynote")
        XCTAssertEqual(open.drawnHashes, [], "The open article isn't drawn again")
        XCTAssertEqual(shownPage(of: pages), 0, "The reader still sees the keynote")
    }

    func test_aRescoreThatShowsTheSameStoriesLeavesThePagerAlone() {
        let app = makeApp()
        app.storiesCollection.activeClassifiers = ["42": ["prompts": ["Sponsor posts": -1]]]
        app.storiesCollection.setStories([story("42:keynote", intelligence: ["prompt": 0]),
                                          story("42:sponsor", intelligence: ["prompt": -1]),
                                          story("42:review", intelligence: ["prompt": 0])])
        let pages = openPager(at: "42:keynote", in: app)
        let pagesShown = [pages.previousPage, pages.currentPage, pages.nextPage].map { page($0) }
        let drawn = pagesShown.map(\.drawnHashes)
        pages.scrollViewResizes = 0

        // The local recalculation keeps the AI's score, and the server likes the review but still hides the sponsor
        // post: the scores change, the stories shown don't.
        app.savePromptClassifier("Sponsor posts", feedId: "42", score: 0, includeImages: false, scope: "feed",
                                 folderName: "")
        app.endDebounces()
        app.storyRequests[0].succeed(["stories": [["story_hash": "42:review", "story_feed_id": 42,
                                                   "intelligence": ["prompt": 1], "score": 1],
                                                  ["story_hash": "42:sponsor", "story_feed_id": 42,
                                                   "intelligence": ["prompt": -1], "score": -1]]])
        XCTAssertEqual(intelligence(of: "42:review", in: app)?["prompt"] as? Int, 1)
        XCTAssertEqual(visibleHashes(in: app), ["42:keynote", "42:review"])

        XCTAssertEqual(pages.scrollViewResizes, 0, "The pager isn't laid out again")
        XCTAssertEqual([pages.previousPage, pages.currentPage, pages.nextPage].map { page($0) }, pagesShown)
        XCTAssertEqual(pagesShown.map(\.pageIndex), [-1, 0, 1])
        XCTAssertEqual(pagesShown.map(\.drawnHashes), drawn, "No page is drawn again")
    }

    func test_aLateRefreshIsDroppedOnceTheReaderSavesAgain() {
        let app = makeApp()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 2)
        let recalculated = intelligence(of: "42:sponsor", in: app) as NSDictionary?

        app.storyRequests[0].succeed(response(prompt: 1, for: ["42:sponsor"]))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app) as NSDictionary?, recalculated,
                       "The first save's refresh doesn't know about the second save")

        app.storyRequests[1].succeed(response(prompt: -1, for: ["42:sponsor"]))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["prompt"] as? Int, -1, "The latest save's refresh lands")
    }

    func test_aRefreshAskedForBeforeASaveIsDroppedAndAskedForAgainOnceTheSaveAnswers() {
        // The reader removes the AI focus prompt, and its refresh is still out when they like the sponsor URL regex.
        let app = makeApp()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1)

        app.holdsSaves = true
        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["url_regex"] as? Int, 1, "Shown right away")

        // The server scored the prompt removal before it heard of the URL regex.
        app.storyRequests[0].succeed(scores(["author": -1, "url_regex": 0, "prompt": 0], for: "42:sponsor"))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["url_regex"] as? Int, 1,
                       "Scores from before the save don't undo it while it's out")

        app.heldSaves[0].succeed()
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 2, "The prompt removal's scores never landed, so they're asked for again")
        let serverScores = ["author": -1, "url_regex": 1, "prompt": 0]
        app.storyRequests[1].succeed(scores(serverScores, for: "42:sponsor"))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?.filter { serverScores.keys.contains($0.key) } as NSDictionary?,
                       serverScores as NSDictionary)
    }

    func test_aSaveThatFailsDropsOlderScoresAndAsksForTheServersOwn() {
        let app = makeApp()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()

        app.holdsSaves = true
        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        app.heldSaves[0].fail()
        let serverScores = ["author": -1, "url_regex": 0, "prompt": 0]
        app.storyRequests[0].succeed(scores(serverScores, for: "42:sponsor"))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["url_regex"] as? Int, 1,
                       "A refresh asked for before the failed save never lands")

        // The failed save's start dropped the prompt removal's refresh, and the server's scores are right whether or
        // not the URL regex reached it, so the failed save asks again.
        XCTAssertEqual(app.pendingDebounces.count, 1)
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 2)
        app.storyRequests[1].succeed(scores(serverScores, for: "42:sponsor"))
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?.filter { serverScores.keys.contains($0.key) } as NSDictionary?,
                       serverScores as NSDictionary,
                       "The server never saved the URL regex, so its scores replace the local guess")
    }

    func test_aScoreTheServerLeavesOutKeepsTheAppsOwn() {
        // A server from before /reader/river_stories scored author regexes sends no author_regex at all. The reader
        // hides the Department of Commerce with an author regex, then removes the AI focus prompt.
        let app = makeApp()
        app.toggleAuthorRegexClassifier("department of \\w+", feedId: "42", score: -2, scope: "feed", folderName: "")
        XCTAssertEqual(intelligence(of: "42:sponsor", in: app)?["author_regex"] as? Int, -2)
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 0, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1)

        app.storyRequests[0].succeed(scores(["feed": 0, "author": -1, "tags": 0, "title": 0, "title_regex": 0, "text": 0,
                                             "text_regex": 0, "url": 0, "url_regex": 0, "prompt": 0], for: "42:sponsor"))

        let refreshed = intelligence(of: "42:sponsor", in: app)
        XCTAssertEqual(refreshed?["author_regex"] as? Int, -2, "The app's own author regex score stays")
        XCTAssertEqual(refreshed?["prompt"] as? Int, 0, "Every score the server sends wins, 0s included")
        XCTAssertEqual(NewsBlurAppDelegate.computeStoryScore(refreshed), -2, "The story stays hidden")
    }

    func test_noRefreshIsSentWhileAnotherSaveForTheSiteIsOut() {
        let app = makeApp()
        app.holdsSaves = true
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.toggleAuthorClassifier("Daring Fireball Department of Commerce", feedId: "42")

        app.heldSaves[0].succeed()
        app.endDebounces()
        XCTAssertTrue(app.storyRequests.isEmpty, "The server may not have the author change yet")

        app.heldSaves[1].succeed()
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "Once both saves answer, one refresh goes out")
    }

    func test_aRefreshIsDroppedOnceTheReaderLeavesTheSite() {
        let app = makeApp()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        app.endDebounces()

        // The reader opens the Apple folder, whose river loaded the same stories with their own scores.
        openAppleFolder(app)
        let folderStories = app.storiesCollection.activeFeedStories as NSArray
        app.storyRequests[0].succeed(response(prompt: 1, for: ["42:sponsor", "42:keynote"]))
        XCTAssertEqual(app.storiesCollection.activeFeedStories as NSArray, folderStories)

        // Back on the site, the reader saves and leaves again before the refresh is sent.
        app.storiesCollection.isRiverView = false
        app.storiesCollection.activeFolder = nil
        app.storiesCollection.activeFeed = ["id": 42]
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: 1, includeImages: false,
                                 scope: "feed", folderName: "")
        openAppleFolder(app)
        app.endDebounces()
        XCTAssertEqual(app.storyRequests.count, 1, "A refresh for a list the reader left is never sent")
    }

    func test_aFailedRefreshChangesNothing() {
        let app = makeApp()
        app.savePromptClassifier("Non-apple related news", feedId: "42", score: -1, includeImages: false,
                                 scope: "feed", folderName: "")
        let recalculated = app.storiesCollection.activeFeedStories as NSArray
        app.endDebounces()

        app.storyRequests[0].fail()
        XCTAssertEqual(app.storiesCollection.activeFeedStories as NSArray, recalculated, "The local recalculation stays")

        app.toggleUrlRegexClassifier("sponsor", feedId: "42")
        let recalculatedAgain = app.storiesCollection.activeFeedStories as NSArray
        app.endDebounces()
        app.storyRequests[1].succeed(["code": -1, "message": "Something went wrong"] as [String: Any])
        XCTAssertEqual(app.storiesCollection.activeFeedStories as NSArray, recalculatedAgain)
    }

    private func makeApp(selectedIntelligence: Int = 0) -> RefreshingClassifierSaveAppDelegate {
        let app = RefreshingClassifierSaveAppDelegate()
        app.isPremium = true
        app.isPremiumArchive = true
        app.isPremiumPro = true
        app.selectedIntelligence = selectedIntelligence
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.storiesCollection.activeFeed = ["id": 42]
        app.storiesCollection.activeClassifiers = ["42": ["feeds": [String: Int](),
                                                          "authors": ["Daring Fireball Department of Commerce": -1],
                                                          "prompts": ["Non-apple related news": 1]]]
        app.storiesCollection.activeFeedStories = [
            story("42:sponsor", title: "[Sponsor] WorkOS", intelligence: ["author": -1, "prompt": 1]),
            story("42:keynote", title: "Apple's October event", intelligence: ["prompt": 0]),
            story("7:other", feedId: 7, title: "Elsewhere", intelligence: ["prompt": 0]),
        ]
        app.storyScoreRefresher.afterDebounce = { [unowned app] _, work in app.pendingDebounces.append(work) }
        return app
    }

    private func openAppleFolder(_ app: NewsBlurAppDelegate) {
        app.storiesCollection.activeFeed = nil
        app.storiesCollection.activeFolder = "Apple"
        app.storiesCollection.isRiverView = true
        app.storiesCollection.activeFeedStories = [story("42:sponsor", title: "[Sponsor] WorkOS", intelligence: ["prompt": 0])]
    }

    private func story(_ hash: String, feedId: Int = 42, title: String = "A story",
                       intelligence: [String: Int] = [:]) -> [String: Any] {
        ["story_hash": hash, "story_feed_id": feedId, "story_title": title,
         "story_authors": "Daring Fireball Department of Commerce",
         "story_permalink": "https://daringfireball.net/linked/2026/10/27/\(hash)", "story_tags": [String](),
         "story_content": "<p>Let agents sign up for your app.</p>", "intelligence": intelligence]
    }

    private func response(prompt: Int, for hashes: [String]) -> [String: Any] {
        let stories = hashes.map { hash -> [String: Any] in
            ["story_hash": hash, "story_feed_id": 42, "intelligence": ["prompt": prompt], "score": prompt]
        }
        return ["stories": stories]
    }

    private func scores(_ intelligence: [String: Int], for hash: String) -> [String: Any] {
        ["stories": [["story_hash": hash, "story_feed_id": 42, "intelligence": intelligence]]]
    }

    private func titleRegexScores(for hashes: [String]) -> [String: Any] {
        ["stories": hashes.map { ["story_hash": $0, "story_feed_id": 42, "intelligence": ["title_regex": 1]] }]
    }

    private func hashes(_ range: ClosedRange<Int>) -> [String] {
        range.map { "42:\($0)" }
    }

    private func requestedHashes(_ request: Int, in app: RefreshingClassifierSaveAppDelegate) throws -> [String] {
        try XCTUnwrap(app.storyRequests[request].parameters["h"] as? [String])
    }

    private func loadedStory(_ hash: String, in app: NewsBlurAppDelegate) -> [String: Any]? {
        app.storiesCollection.activeFeedStories.compactMap { $0 as? [String: Any] }.first { $0["story_hash"] as? String == hash }
    }

    /// The AI pills StoryDetailObjCViewController.m puts in a loaded story's header.
    private func pillsHTML(of hash: String, in app: NewsBlurAppDelegate) -> String {
        StoryAIClassifierPills.headerHTML(for: loadedStory(hash, in: app)?["prompt_classifiers"])
    }

    /// The stories the list shows and paging moves through, in order.
    private func visibleHashes(in app: NewsBlurAppDelegate) -> [String]? {
        app.storiesCollection.activeFeedStoryLocationIds as? [String]
    }

    private func intelligence(of hash: String, in app: NewsBlurAppDelegate) -> [String: Any]? {
        loadedStory(hash, in: app)?["intelligence"] as? [String: Any]
    }

    /// Opens the story in a real pager that has settled on it, with its neighbors drawn the way paging leaves them.
    private func openPager(at hash: String, in app: RefreshingClassifierSaveAppDelegate) -> RescoredStoryPages {
        let pages = RescoredStoryPages()
        pages.appDelegate = app
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        pages.scrollingToPage = -1
        let (previous, open, next) = (RescoredStoryPage(), RescoredStoryPage(), RescoredStoryPage())
        for storyPage in [previous, open, next] {
            storyPage.appDelegate = app
        }
        let location = app.storiesCollection.location(ofStoryId: hash)
        open.activeStory = NSMutableDictionary(dictionary: loadedStory(hash, in: app) ?? [:])
        open.activeStoryId = hash
        open.pageIndex = location
        open.hasStory = true
        (pages.previousPage, pages.currentPage, pages.nextPage) = (previous, open, next)
        app.pages = pages

        pages.applyNewIndex(location, pageController: open, supressRedraw: true)
        pages.applyNewIndex(location - 1, pageController: previous)
        pages.applyNewIndex(location + 1, pageController: next)
        let shown = visibleHashes(in: app) ?? []
        if shown.indices.contains(location - 1) { waitForDraw(of: shown[location - 1], into: previous) }
        if shown.indices.contains(location + 1) { waitForDraw(of: shown[location + 1], into: next) }
        return pages
    }

    private func page(_ storyPage: StoryDetailViewController?) -> RescoredStoryPage {
        storyPage as! RescoredStoryPage
    }

    /// Waits for StoryPagesObjCViewController.m's asynchronous draw of a story into a page.
    private func waitForDraw(of hash: String, into storyPage: RescoredStoryPage) {
        guard storyPage.drawnHashes.last != hash else { return }
        let drawn = expectation(description: "\(hash) is drawn into its page")
        drawn.assertForOverFulfill = false
        storyPage.storyDrawn = { [unowned storyPage] in
            if storyPage.drawnHashes.last == hash { drawn.fulfill() }
        }
        wait(for: [drawn], timeout: SimulatorTestTiming.realWorkTimeout)
        storyPage.storyDrawn = nil
    }

    /// How many stories the pager's scroll view pages through.
    private func pageCount(of pages: StoryPagesViewController) -> CGFloat {
        let size = pages.scrollView.contentSize
        let bounds = pages.scrollView.bounds.size
        return pages.isHorizontal ? size.width / bounds.width : size.height / bounds.height
    }

    /// The page the pager's scroll view shows.
    private func shownPage(of pages: StoryPagesViewController) -> CGFloat {
        let offset = pages.scrollView.contentOffset
        let bounds = pages.scrollView.bounds.size
        return pages.isHorizontal ? offset.x / bounds.width : offset.y / bounds.height
    }
}

// MARK: - AI credits screen

/// AIClassifierTests.swift tests the AI credits screen's Stripe paths with UsageBillingFeature.swift turned on, as it
/// will be once the release hold lifts. Test_UsageBillingHold covers the release with it off.
@MainActor final class Test_AICreditsScreen: XCTestCase {
    override func setUp() {
        super.setUp()
        UsageBillingFeature.isEnabled = true
    }

    override func tearDown() {
        UsageBillingFeature.isEnabled = false
        super.tearDown()
    }

    /// Rule: the screen shows the profile's credits at once, then this moment's from the server, which it hands to the
    /// profile; invoices load only for a reader with usage billing, since nobody else has any.
    func test_loadShowsTheProfilesCreditsThenTheServersAndInvoicesOnlyWithBilling() throws {
        let transport = RecordingAITransport()
        transport.responses["/analyzer/ai_classifier_usage"] = ["code": 0, "ai_credits": creditsJSON(["used": 6_000])]
        transport.holdsResponses = true
        var stored: [[String: Any]] = []
        let model = makeModel(transport: transport, credits: credits(), storeCredits: { stored.append($0) })

        model.load()
        XCTAssertEqual(model.credits?.used, 2_340)
        XCTAssertEqual(transport.requests.map(\.path), ["/analyzer/ai_classifier_usage"], "No invoices without usage billing")
        XCTAssertEqual(transport.requests.first?.parameters["feed_id"] as? String, "0")
        transport.releaseHeldResponses()
        XCTAssertEqual(model.credits?.used, 6_000)
        XCTAssertEqual(AICredits(json: try XCTUnwrap(stored.first))?.used, 6_000)
        XCTAssertEqual(model.historyState, .notSetUp)

        transport.holdsResponses = false
        transport.responses["/analyzer/ai_classifier_usage"] = ["code": 0, "ai_credits": creditsJSON(billingCredits)]
        transport.responses["/profile/usage_billing_history"] = [
            "code": 0, "ai_credits": creditsJSON(billingCredits), "upcoming_invoice": NSNull(),
            "invoices": [["date": "2026-11-01", "amount": 3.0, "amount_paid": 2.75, "status": "paid",
                          "hosted_invoice_url": "https://invoice.stripe.com/i/acct/test",
                          "line_items": [["description": "AI credits", "quantity": 275, "amount": 2.75]]]],
        ]
        let billing = makeModel(transport: transport, credits: credits(billingCredits))
        billing.load()
        guard case .loaded(let history) = billing.historyState else { return XCTFail("Invoices should load") }
        XCTAssertEqual(history.invoices.first?.amount, 2.75, "Paid invoices show what was charged")
        XCTAssertEqual(history.invoices.first?.lineItems,
                       [UsageBillingHistory.LineItem(description: "AI credits", quantity: 275, amount: 2.75)])
        XCTAssertEqual(history.invoices.first?.hostedInvoiceURL?.absoluteString, "https://invoice.stripe.com/i/acct/test")
        XCTAssertNil(history.upcomingInvoice)

        transport.responses["/analyzer/ai_classifier_usage"] = nil
        let offline = makeModel(transport: transport, credits: nil)
        offline.load()
        XCTAssertTrue(offline.loadFailed, "Without credits from anywhere the screen says it couldn't load them")
    }

    func test_savingLimitSendsItAndBlankClearsIt() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/profile/save_usage_billing_limit"] = [
                "code": 1, "limit": 25.5, "ai_credits": creditsJSON(billingCredits.merging(["monthly_limit": 25.5]) { $1 }),
            ]
            var stored: [[String: Any]] = []
            let model = makeModel(transport: transport, credits: credits(billingCredits), storeCredits: { stored.append($0) })

            model.editLimit("$25.50/month")
            XCTAssertEqual(model.limitText, "25.50")
            model.saveLimit()
            XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?, ["limit": "25.50"])
            XCTAssertEqual(model.limitText, "25.5")
            XCTAssertEqual(model.credits?.monthlyLimit, 25.5)
            XCTAssertEqual(stored.count, 1, "The trainer sees the new limit too")
            XCTAssertEqual(model.limitMessage, AICreditsModel.Message(text: "Saved", isError: false))

            transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": NSNull(), "ai_credits": creditsJSON(billingCredits)]
            model.editLimit("")
            model.saveLimit()
            XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?, ["limit": ""])
            XCTAssertEqual(model.limitText, "")
            XCTAssertNil(model.credits?.monthlyLimit)

            transport.responses["/profile/save_usage_billing_limit"] = ["code": -1, "message": "Limit cannot exceed $10,000"]
            model.editLimit("20000")
            model.saveLimit()
            XCTAssertEqual(model.limitMessage, AICreditsModel.Message(text: "Limit cannot exceed $10,000", isError: true))
            XCTAssertEqual(model.limitText, "20000", "A rejected limit stays for editing")
        }
    }

    func test_limitKeepsTheRegionsDecimalSeparatorAndSavesAPlainDecimal() {
        let transport = RecordingAITransport()
        transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": 10.5]
        let german = makeModel(transport: transport, credits: credits(billingCredits), locale: Locale(identifier: "de_DE"))

        german.editLimit("10,50")
        XCTAssertEqual(german.limitText, "10,50")
        german.saveLimit()
        XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?,
                       ["limit": "10.50"], "A German 10,50 is $10.50, not $1,050")
        XCTAssertEqual(german.limitText, "10,5", "The saved limit shows with the comma again")

        german.editLimit("12.5")
        XCTAssertEqual(german.limitText, "12,5", "A period from a hardware keyboard also starts the cents")
        german.editLimit("12,505")
        XCTAssertEqual(german.limitText, "12,50", "Cents stop at two digits")
        german.editLimit("12,50,")
        XCTAssertEqual(german.limitText, "12,50", "A second separator is dropped")
        german.editLimit(",5")
        XCTAssertEqual(AICreditsModel.serverLimit(german.limitText, locale: german.locale), "0.5")
        german.editLimit(",")
        XCTAssertEqual(AICreditsModel.serverLimit(german.limitText, locale: german.locale), "0",
                       "A lone separator is rejected by the server instead of clearing the limit")

        let american = makeModel(transport: transport, credits: credits(billingCredits), locale: Locale(identifier: "en_US"))
        american.editLimit("1,050")
        XCTAssertEqual(american.limitText, "1050", "A comma is only a grouping separator in English")

        let arabic = makeModel(transport: transport, credits: credits(billingCredits), locale: Locale(identifier: "ar_SA"))
        arabic.editLimit("١٠\(arabic.locale.decimalSeparator ?? ".")٥٠")
        XCTAssertEqual(AICreditsModel.serverLimit(arabic.limitText, locale: arabic.locale), "10.50",
                       "Arabic-Indic digits and the region's separator save as a plain decimal")
    }

    /// Rule: Set up opens Stripe checkout from the app, and once Stripe returns the screen shows usage billing on and
    /// reloads the profile and credits.
    func test_setupOpensStripeAndRefreshesWhenItReturns() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        let browser = RecordingBillingBrowser()
        var profileRefreshes = 0
        let model = makeModel(transport: transport, credits: credits(pausedCredits), browser: browser) { profileRefreshes += 1 }
        XCTAssertEqual(model.stripeAction, .setup)

        model.openStripe()

        XCTAssertEqual(transport.requests(to: "/profile/setup_usage_billing/").first?.parameters as NSDictionary?, ["platform": "ios"])
        XCTAssertEqual(browser.openedURL?.absoluteString, "https://checkout.stripe.com/c/pay/cs_test_app")
        XCTAssertEqual(browser.callbackScheme, "newsblur-auth")
        XCTAssertTrue(model.isOpeningStripe)

        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=setup_complete"), nil)

        XCTAssertFalse(model.isOpeningStripe)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertEqual(model.credits?.status, .usageBilling, "Paused filters show as running on usage billing")
        XCTAssertEqual(model.stripeAction, .manage)
        XCTAssertEqual(transport.requests(to: "/analyzer/ai_classifier_usage").count, 1)
    }

    /// Rule: Stripe's webhook can land after checkout returns, so the screen keeps billing on until the profile agrees.
    func test_setupKeepsBillingOnUntilTheWebhookReachesTheProfile() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        transport.responses["/analyzer/ai_classifier_usage"] = ["code": 0, "ai_credits": creditsJSON(pausedCredits)]
        let browser = RecordingBillingBrowser()
        var profile = credits(pausedCredits)
        var profileRefreshes = 0
        var scheduled: [() -> Void] = []
        let model = AICreditsModel(api: AIClassifierAPI(transport: transport), browser: browser,
                                   readCredits: { profile }, storeCredits: { _ in }, refreshProfile: { profileRefreshes += 1 })
        model.scheduleActivationCheck = { _, check in scheduled.append(check) }

        model.openStripe()
        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=setup_complete"), nil)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertTrue(model.credits?.isUsageBilling == true, "Credits from before the webhook don't undo the checkout")

        model.profileDidRefresh()
        XCTAssertTrue(model.credits?.isUsageBilling == true, "Nor does a profile from before it")
        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(profileRefreshes, 2)

        profile = credits(billingCredits)
        model.profileDidRefresh()
        XCTAssertTrue(model.credits?.isUsageBilling == true)
        XCTAssertTrue(scheduled.isEmpty, "Checks stop once the profile agrees")

        profile = credits(pausedCredits)
        model.profileDidRefresh()
        XCTAssertEqual(model.credits?.status, .pausedForCredits, "Later profile changes apply normally")
    }

    func test_billingReadersUpdateTheirCardOnStripeAndRefreshAfterThePortal() {
        let transport = RecordingAITransport()
        transport.responses["/profile/manage_usage_billing/"] = ["code": 0, "url": "https://billing.stripe.com/p/session/test_app"]
        let browser = RecordingBillingBrowser()
        var profileRefreshes = 0
        let model = makeModel(transport: transport, credits: credits(billingCredits), browser: browser) { profileRefreshes += 1 }

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
        let model = makeModel(transport: transport, credits: credits(), browser: browser) { profileRefreshes += 1 }

        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "already_active": true]
        model.openStripe()
        XCTAssertNil(browser.openedURL)
        XCTAssertEqual(profileRefreshes, 1)
        XCTAssertNil(model.stripeMessage)

        transport.responses["/profile/setup_usage_billing/"] = ["code": -1, "message": "Stripe is unavailable"]
        model.openStripe()
        XCTAssertNil(browser.openedURL)
        XCTAssertEqual(model.stripeMessage, AICreditsModel.Message(text: "Stripe is unavailable", isError: true))
        XCTAssertFalse(model.isOpeningStripe)
    }

    func test_cancelledCheckoutKeepsBillingOff() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        let browser = RecordingBillingBrowser()
        let model = makeModel(transport: transport, credits: credits(pausedCredits), browser: browser) {}

        model.openStripe()
        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=cancelled"), nil)

        XCTAssertEqual(model.credits?.status, .pausedForCredits)
        XCTAssertEqual(model.stripeAction, .setup)
        XCTAssertNil(model.stripeMessage)
    }

    /// Rule: turning usage billing off shows the credits the server answers with, and a failure says so and changes
    /// nothing.
    func test_turningBillingOffShowsTheCreditsItLeaves() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            let model = makeModel(transport: transport, credits: credits(billingCredits))

            model.turnOffUsageBilling()
            XCTAssertEqual(model.stripeMessage, AICreditsModel.Message(text: "Couldn't turn off usage billing. Please try again.", isError: true))
            XCTAssertEqual(model.credits?.status, .usageBilling)

            transport.responses["/profile/cancel_usage_billing"] = ["code": 0, "ai_credits": creditsJSON(pausedCredits)]
            model.turnOffUsageBilling()
            XCTAssertEqual(transport.requests(to: "/profile/cancel_usage_billing").last?.method, "POST")
            XCTAssertEqual(model.credits?.status, .pausedForCredits)
            XCTAssertFalse(model.canTurnOffBilling)
            XCTAssertEqual(model.historyState, .notSetUp)
        }
    }

    /// Rule: a plan without credits is pointed at upgrading, not usage billing, and a server that counts no credits
    /// has nothing to bill.
    func test_aPlanWithoutCreditsOrAServerThatCountsNoneOpensNoStripe() {
        XCTAssertNil(makeModel(transport: RecordingAITransport(), credits: credits(freeCredits)).stripeAction)
        XCTAssertNil(makeModel(transport: RecordingAITransport(), credits: credits(["is_unlimited": true])).stripeAction)
        XCTAssertNil(makeModel(transport: RecordingAITransport(), credits: credits(["is_billing_available": false])).stripeAction)
    }

    /// Rule: the trainer's Keep filters running and Turn on usage billing open the screen straight into checkout, once.
    func test_openingTheScreenToSetUpGoesStraightToCheckoutOnce() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        let browser = RecordingBillingBrowser()
        let controller = AICreditsViewController(model: makeModel(transport: transport, credits: credits(warningCredits), browser: browser),
                                                 startingSetup: true)
        controller.viewDidAppear(false)
        controller.viewDidAppear(false)
        XCTAssertEqual(transport.requests(to: "/profile/setup_usage_billing/").count, 1)
        XCTAssertNotNil(browser.openedURL)

        let plain = RecordingAITransport()
        AICreditsViewController(model: makeModel(transport: plain, credits: credits(warningCredits)), startingSetup: false)
            .viewDidAppear(false)
        XCTAssertTrue(plain.requests(to: "/profile/setup_usage_billing/").isEmpty, "Opening from the meter just shows the screen")
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

    /// Pins the region to English unless a test asks for another, since the limit field follows its decimal separator.
    private func makeModel(transport: RecordingAITransport, credits: AICredits?,
                           browser: UsageBillingBrowser? = nil, locale: Locale = Locale(identifier: "en_US"),
                           storeCredits: @escaping ([String: Any]) -> Void = { _ in },
                           refreshProfile: (() -> Void)? = nil) -> AICreditsModel {
        AICreditsModel(api: AIClassifierAPI(transport: transport), browser: browser, readCredits: { credits },
                       storeCredits: storeCredits, refreshProfile: refreshProfile ?? {}, openUpgrade: {}, locale: locale)
    }
}

// MARK: - Usage billing held out of the release

/// AIClassifierTests.swift checks that with UsageBillingFeature.swift off, as it ships in this release, readers still
/// see their credits, the forecast and why filters are paused, but nothing opens Stripe or points them anywhere to pay.
/// Each test turns the switch on once too, to show it finds the way to pay it then checks is gone.
@MainActor final class Test_UsageBillingHold: XCTestCase {
    override func tearDown() {
        UsageBillingFeature.isEnabled = false
        super.tearDown()
    }

    func test_theReleaseShipsWithBillingHeld() {
        XCTAssertFalse(UsageBillingFeature.isEnabled)
    }

    /// Rule: the settings menu lists AI Credits for plans that include them and readers with usage billing, whatever
    /// the switch says, since the screen reads fully without Stripe.
    func test_theSettingsMenuListsAICreditsForPlansThatIncludeThem() throws {
        try withEnglishInterface {
            XCTAssertTrue(try settingsMenuTitles(credits: creditsJSON()).contains("AI Credits"))
            XCTAssertTrue(try settingsMenuTitles(credits: creditsJSON(freeCredits.merging(["is_usage_billing": true,
                                                                                         "pause_reason": NSNull()]) { $1 }))
                .contains("AI Credits"), "A free account billed for its filters sees what they cost")
            XCTAssertFalse(try settingsMenuTitles(credits: creditsJSON(freeCredits)).contains("AI Credits"))
            XCTAssertFalse(try settingsMenuTitles(credits: creditsJSON(["is_unlimited": true])).contains("AI Credits"),
                           "A server that counts no credits has nothing to list")
            XCTAssertTrue(try settingsMenuTitles(credits: creditsJSON(freeCredits)).contains("Support Forum"),
                          "The rest of the menu is still there")
        }
    }

    /// Rule: with the switch off the trainer tells every credit state, but its only button is Upgrade, the App Store
    /// purchase; nothing offers usage billing, its card or its limit, or waiting as the alternative to paying.
    func test_theTrainerTellsEveryCreditStateWithoutAWayToPay() throws {
        try withEnglishInterface {
            let states = [warningCredits, pausedCredits, billingCredits, limitCredits]
            for state in states {
                let notice = try XCTUnwrap(trainerNotice(state))
                XCTAssertNil(notice.button, "\(notice.messages)")
                XCTAssertNil(notice.footnote)
            }
            XCTAssertEqual(try trainerNotice(pausedCredits)?.messages,
                           ["Your AI filters are paused until Dec 1.", "This month's 10,000 AI credits are used."])
            XCTAssertEqual(try trainerNotice(warningCredits)?.messages, ["At this pace your credits run out around Nov 27."])
            var billingWithLimit = billingCredits
            billingWithLimit["monthly_limit"] = 5.0
            XCTAssertEqual(try trainerNotice(billingWithLimit)?.messages.last, "Monthly limit: $5.00",
                           "Usage billing turned on elsewhere shows its limit as text")
            XCTAssertEqual(try trainerNotice(freeCredits, kind: .content, draft: "Charts")?.button?.action, .upgrade)

            UsageBillingFeature.isEnabled = true
            for state in states {
                XCTAssertNotNil(try trainerNotice(state)?.button)
            }
            XCTAssertNotEqual(try trainerNotice(billingWithLimit)?.messages.last, "Monthly limit: $5.00",
                              "The limit is edited on the AI credits screen instead")
        }
    }

    /// Rule: with the switch off the AI credits screen opens nothing on Stripe, doesn't edit the limit, and keeps
    /// usage billing on.
    func test_theCreditsScreenOpensNoStripeWhileTheSwitchIsOff() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        transport.responses["/profile/manage_usage_billing/"] = ["code": 0, "url": "https://billing.stripe.com/p/session/test_app"]
        transport.responses["/profile/cancel_usage_billing"] = ["code": 0, "ai_credits": creditsJSON(pausedCredits)]
        let browser = RecordingBillingBrowser()
        var models: [AICreditsModel] = []
        for state in [pausedCredits, billingCredits] {
            let current = credits(state)
            let model = AICreditsModel(api: AIClassifierAPI(transport: transport), browser: browser, readCredits: { current },
                                       storeCredits: { _ in }, refreshProfile: {}, openUpgrade: {})
            XCTAssertNil(model.stripeAction, "The screen shows no Stripe button")
            XCTAssertFalse(model.canEditLimit)
            XCTAssertFalse(model.canTurnOffBilling)
            model.openStripe()
            model.editLimit("5")
            model.saveLimit()
            model.turnOffUsageBilling()
            models.append(model)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(browser.openedURL)

        UsageBillingFeature.isEnabled = true
        XCTAssertEqual(models.map(\.stripeAction), [.setup, .manage])
    }

    private func trainerNotice(_ state: [String: Any], kind: PromptClassifierKind = .content,
                               draft: String = "") throws -> AICreditsNotice? {
        let profile: [AnyHashable: Any] = ["ai_credits": creditsJSON(state)]
        let model = TrainerAIPromptModel(api: AIClassifierAPI(transport: RecordingAITransport()), userProfile: { profile })
        model.setDraft(draft, for: kind)
        return model.freeNotice(saved: []) ?? model.creditsNotice
    }

    /// The titles FeedsObjCViewController.m puts in the feed list's settings menu for an account with these credits.
    private func settingsMenuTitles(credits: [String: Any]) throws -> [String] {
        let app = NewsBlurAppDelegate()
        app.dictUserProfile = ["is_premium": 1, "ai_credits": credits]
        let feeds = BillingMenuFeedsController()
        feeds.appDelegate = app
        let navigation = BillingMenuNavigationController(rootViewController: feeds)
        feeds.loadViewIfNeeded()
        feeds.showSettingsPopover(nil)
        let presented = try XCTUnwrap(navigation.requestedPresentation as? UINavigationController)
        let menu = try XCTUnwrap(presented.viewControllers.first as? MenuViewController)
        let items = try XCTUnwrap(menu.value(forKey: "items") as? [[String: Any]])
        return items.compactMap { $0["title"] as? String }
    }
}

/// AIClassifierTests.swift builds the real settings menu from a feed list on a plain view.
@MainActor private final class BillingMenuFeedsController: FeedsViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 780)) }
    override func viewDidLoad() {}
}

@MainActor private final class BillingMenuNavigationController: UINavigationController {
    var requestedPresentation: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        requestedPresentation = viewControllerToPresent
        completion?()
    }
}
