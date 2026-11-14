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

    func test_promptTestResultIsDroppedWhenTheDraftChangesDuringTheRequest() {
        let transport = RecordingAITransport()
        transport.responses["/classifier/test_prompt"] = ["code": 0, "classification": 1]
        transport.holdsResponses = true
        let model = makeModel(transport: transport, canUseAI: true)
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
        XCTAssertEqual(transport.requests.map(\.path), ["/classifier/ai_classifier_usage"])
        XCTAssertEqual(transport.requests.first?.parameters["feed_id"] as? String, "42")
        XCTAssertEqual(billingModel.estimate?.averageCostPerImage, 0.002)
        XCTAssertTrue(billingModel.isLimitReached)
    }

    func test_reopeningTheTrainerLoadsCostsAgainAndKeepsTheDraft() {
        let transport = RecordingAITransport()
        transport.responses["/classifier/ai_classifier_usage"] = [
            "code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0004, "avg_cost_per_image": 0.002, "is_limit_reached": true,
        ]
        transport.holdsResponses = true
        let model = makeModel(transport: transport, canUseAI: true)

        // TrainerViewController.swift and TrainerView.swift both prepare the model as the trainer opens.
        model.prepare(feedId: "42", storyHash: "42:abc")
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(transport.requests(to: "/classifier/ai_classifier_usage").count, 1, "One open shares one fetch")
        transport.releaseHeldResponses()
        XCTAssertTrue(model.isLimitReached)
        model.setDraft("Apple earnings coverage", for: .content)

        // The reader raises their limit on the web, then opens the trainer on the same story again.
        transport.responses["/classifier/ai_classifier_usage"] = [
            "code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0005, "avg_cost_per_image": 0.003, "is_limit_reached": false,
        ]
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(transport.requests(to: "/classifier/ai_classifier_usage").count, 2, "Reopening asks again")
        transport.releaseHeldResponses()
        XCTAssertFalse(model.isLimitReached, "The limit banner doesn't stay as the last visit left it")
        XCTAssertEqual(model.estimate, AIClassifierCostEstimate(averageCostPerText: 0.0005, averageCostPerImage: 0.003))
        XCTAssertEqual(model.draft(.content), "Apple earnings coverage", "The same story keeps its draft")
    }

    func test_anotherAccountsTrainerForTheSameSiteStartsEmpty() {
        var account = (username: "samuel", host: "https://www.newsblur.com")
        let transport = RecordingAITransport()
        transport.responses["/classifier/test_prompt"] = [
            "code": 0, "classification": 1,
            "cost_estimate": ["avg_cost_per_text": 0.0004, "avg_cost_per_image": 0.002],
        ]
        transport.responses["/classifier/ai_classifier_usage"] = [
            "code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0009, "avg_cost_per_image": 0.009, "is_limit_reached": true,
        ]
        let model = makeModel(transport: transport, canUseAI: true, signedInAccount: { account })
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
        XCTAssertNil(model.estimate, "Nor does its usage")
        XCTAssertFalse(model.isLimitReached)
        XCTAssertEqual(model.scope(for: saved), .feed, "Its scope choice is gone")

        transport.responses["/classifier/ai_classifier_usage"] = [
            "code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0007, "avg_cost_per_image": 0.007, "is_limit_reached": false,
        ]
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(model.estimate, AIClassifierCostEstimate(averageCostPerText: 0.0007, averageCostPerImage: 0.007),
                       "This account's own usage loads")
        XCTAssertEqual(model.draft(.content), "")

        // Even without the reset, the same site on another server is another trainer.
        model.setDraft("Charts", for: .image)
        account = (username: "family", host: "https://newsblur.example.com")
        model.prepare(feedId: "42", storyHash: "42:abc")
        XCTAssertEqual(model.draft(.image), "")
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

    func test_topLevelSiteNeverScopesAPromptToAMissingFolder() {
        var moves: [String] = []
        var saves: [String] = []
        let model = makeModel(transport: RecordingAITransport(), canUseAI: true)
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

    func test_nestedFolderPromptFromTheAPICostsItsFolderAndSavesItsFullPath() {
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

        let volumes = AIClassifierStoryVolumes.live(appDelegate: app)
        XCTAssertEqual(volumes.stories(scope: .folder, folderName: "Tech - Swift", feedId: "3"), 300,
                       "Only the subfolder's sites count, not the top-level folder that is also called Swift")
        XCTAssertEqual(volumes.stories(scope: .folder, folderName: "Tech", feedId: "2"), 320, "A folder covers its subfolders")
        XCTAssertEqual(volumes.stories(scope: .folder, folderName: "Swift", feedId: "4"), 4_000)

        let transport = RecordingAITransport()
        transport.responses["/classifier/ai_classifier_usage"] = ["code": 0, "can_use_ai": true, "avg_cost_per_text": 0.001, "avg_cost_per_image": 0.01]
        let model = makeModel(transport: transport, canUseAI: true)
        model.storyVolumes = { volumes }
        model.prepare(feedId: "3", storyHash: nil)
        withEnglishInterface {
            XCTAssertEqual(model.sectionCost(.content, saved: saved, feedId: "3", currentFolderName: currentFolder),
                           AIClassifierSectionCost(monthly: "$0.30", daily: "$0.010",
                                                   breakdown: "1 on folder (300 stories/mo) × $0.0010/story"))
        }

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
        app.dictFeeds = NSMutableDictionary(dictionary: [
            "1": ["stories_last_month": 1], "2": ["stories_last_month": 20],
            "3": ["stories_last_month": 300], "4": ["stories_last_month": 4_000],
        ])
        return app
    }

    private func makeModel(transport: RecordingAITransport, canUseAI: Bool,
                           signedInAccount: @escaping () -> (username: String, host: String) = { ("samuel", "https://www.newsblur.com") })
        -> TrainerAIPromptModel {
        TrainerAIPromptModel(api: AIClassifierAPI(transport: transport),
                             billingStatus: { UsageBillingStatus(isUsageBilling: canUseAI, isSelfHostedAI: false,
                                                                 canUseAIClassifiers: canUseAI, usageBillingLimit: nil) },
                             storyVolumes: { AIClassifierStoryVolumes(storiesForFeed: { _ in 300 }, storiesForFolder: { _ in 0 },
                                                                      storiesForAllSites: { 0 }) },
                             openBilling: {},
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

// MARK: - Usage billing

/// AIClassifierTests.swift tests the billing screen with UsageBillingFeature.swift turned on, as it will be once the
/// release hold lifts. Test_UsageBillingHold covers the release with it off.
@MainActor final class Test_UsageBilling: XCTestCase {
    override func setUp() {
        super.setUp()
        UsageBillingFeature.isEnabled = true
    }

    override func tearDown() {
        UsageBillingFeature.isEnabled = false
        super.tearDown()
    }

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

    func test_limitKeepsTheRegionsDecimalSeparatorAndSavesAPlainDecimal() {
        let transport = RecordingAITransport()
        transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": 10.5]
        let german = makeModel(transport: transport, status: activeStatus, locale: Locale(identifier: "de_DE"))

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
        XCTAssertEqual(UsageBillingModel.serverLimit(german.limitText, locale: german.locale), "0.5")
        german.editLimit(",")
        XCTAssertEqual(UsageBillingModel.serverLimit(german.limitText, locale: german.locale), "0",
                       "A lone separator is rejected by the server instead of clearing the limit")

        transport.responses["/profile/save_usage_billing_limit"] = ["code": 1, "limit": NSNull()]
        german.editLimit("")
        german.saveLimit()
        XCTAssertEqual(transport.requests(to: "/profile/save_usage_billing_limit").last?.parameters as NSDictionary?, ["limit": ""])
        XCTAssertEqual(german.limitText, "")

        let american = makeModel(transport: transport, status: activeStatus, locale: Locale(identifier: "en_US"))
        american.editLimit("10.50")
        XCTAssertEqual(american.limitText, "10.50")
        XCTAssertEqual(UsageBillingModel.serverLimit(american.limitText, locale: american.locale), "10.50")
        american.editLimit("1,050")
        XCTAssertEqual(american.limitText, "1050", "A comma is only a grouping separator in English")

        let arabic = makeModel(transport: transport, status: activeStatus, locale: Locale(identifier: "ar_SA"))
        arabic.editLimit("١٠\(arabic.locale.decimalSeparator ?? ".")٥٠")
        XCTAssertEqual(UsageBillingModel.serverLimit(arabic.limitText, locale: arabic.locale), "10.50",
                       "Arabic-Indic digits and the region's separator save as a plain decimal")
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

    func test_setupKeepsBillingActiveUntilTheWebhookReachesTheProfile() {
        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        let browser = RecordingBillingBrowser()
        var profile = freeStatus
        var profileRefreshes = 0
        var scheduled: [() -> Void] = []
        let model = UsageBillingModel(api: AIClassifierAPI(transport: transport), browser: browser,
                                      readStatus: { profile }, refreshProfile: { profileRefreshes += 1 })
        model.scheduleActivationCheck = { _, check in scheduled.append(check) }

        model.openStripe()
        browser.completion?(URL(string: "newsblur-auth://usage-billing?status=setup_complete"), nil)
        XCTAssertEqual(profileRefreshes, 1)

        model.profileDidRefresh()
        XCTAssertTrue(model.status.isUsageBilling, "A profile from before the webhook doesn't undo the checkout")
        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(profileRefreshes, 2)

        profile = activeStatus
        model.profileDidRefresh()
        XCTAssertTrue(model.status.isUsageBilling)
        XCTAssertTrue(scheduled.isEmpty, "Checks stop once the profile agrees")

        profile = freeStatus
        model.profileDidRefresh()
        XCTAssertFalse(model.status.isUsageBilling, "Later profile changes apply normally")
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

    /// Pins the region to English unless a test asks for another, since the limit field follows its decimal separator.
    private func makeModel(transport: RecordingAITransport, status: UsageBillingStatus,
                           browser: UsageBillingBrowser? = nil, locale: Locale = Locale(identifier: "en_US"),
                           refreshProfile: (() -> Void)? = nil) -> UsageBillingModel {
        UsageBillingModel(api: AIClassifierAPI(transport: transport), browser: browser,
                          readStatus: { status }, refreshProfile: refreshProfile ?? {}, locale: locale)
    }
}

// MARK: - Usage billing held out of the release

/// AIClassifierTests.swift checks that with UsageBillingFeature.swift off, as it ships in this release, no way into
/// usage billing shows and nothing opens Stripe, while readers still see their costs and why filters aren't running.
/// Each test turns the switch on once too, to show it finds the entry point it then checks is gone.
@MainActor final class Test_UsageBillingHold: XCTestCase {
    override func tearDown() {
        UsageBillingFeature.isEnabled = false
        super.tearDown()
    }

    func test_theReleaseShipsWithBillingHeld() {
        XCTAssertFalse(UsageBillingFeature.isEnabled)
    }

    func test_theSettingsMenuOffersUsageBillingOnlyWhileTheSwitchIsOn() throws {
        try withEnglishInterface {
            UsageBillingFeature.isEnabled = false
            XCTAssertFalse(try settingsMenuTitles().contains("Usage Billing"))
            XCTAssertTrue(try settingsMenuTitles().contains("Support Forum"), "The rest of the menu is still there")

            UsageBillingFeature.isEnabled = true
            XCTAssertTrue(try settingsMenuTitles().contains("Usage Billing"))
        }
    }

    func test_nothingOpensTheBillingScreenOrStripeWhileTheSwitchIsOff() {
        let app = NewsBlurAppDelegate()
        let split = BillingPresentationSplitController()
        app.splitViewController = split
        defer { app.splitViewController = nil }
        app.showUsageBillingDialog()
        XCTAssertNil(split.requestedPresentation, "The Premium screen and the trainer's banners open billing this way")

        let transport = RecordingAITransport()
        transport.responses["/profile/setup_usage_billing/"] = ["code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test_app"]
        transport.responses["/profile/manage_usage_billing/"] = ["code": 0, "url": "https://billing.stripe.com/p/session/test_app"]
        let browser = RecordingBillingBrowser()
        for status in [freeStatus, activeStatus] {
            let model = UsageBillingModel(api: AIClassifierAPI(transport: transport), browser: browser,
                                          readStatus: { status }, refreshProfile: {})
            XCTAssertNil(model.stripeAction, "The billing screen shows no Stripe button")
            model.openStripe()
        }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(browser.openedURL)

        UsageBillingFeature.isEnabled = true
        app.showUsageBillingDialog()
        XCTAssertNotNil(split.requestedPresentation)
    }

    func test_theTrainerShowsCostsAndWhyFiltersDontRunButNoWayToPay() {
        withEnglishInterface {
            let transport = RecordingAITransport()
            transport.responses["/classifier/ai_classifier_usage"] = ["code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0004,
                                                                      "avg_cost_per_image": 0.002]
            let billing = makeModel(transport: transport, status: activeStatus)
            billing.prepare(feedId: "42", storyHash: nil)
            let saved = [PromptClassifier(prompt: "Non-apple related news", kind: .content, score: 1, scope: .feed, folderName: "")]
            XCTAssertEqual(billing.sectionCost(.content, saved: saved, feedId: "42", currentFolderName: "")?.monthly, "$0.12",
                           "A reader with billing still sees what their filters cost")
            XCTAssertNil(billing.billingButtonTitle)
            let free = makeModel(transport: RecordingAITransport(), status: freeStatus)
            XCTAssertNil(free.billingButtonTitle)
            XCTAssertTrue(free.showsBillingBanner(.content, saved: saved), "A reader without billing still learns why")

            let banner = section(free)
            XCTAssertEqual(String(banner.billingBannerText.characters), "Natural language filters aren't active on this account.")
            XCTAssertEqual(banner.billingBannerText.runs.count, 1, "No phrase in it is styled as a link")
            XCTAssertEqual(String(section(billing).limitReachedText.characters),
                           "Monthly spending limit reached. Natural language classifiers are paused until next billing cycle. ")

            UsageBillingFeature.isEnabled = true
            XCTAssertEqual(billing.billingButtonTitle, "Manage billing and limits")
            XCTAssertEqual(free.billingButtonTitle, "Set up billing")
            XCTAssertEqual(String(section(free).billingBannerText.characters),
                           "AI filters are saved but won't run until you set up usage-based billing.")
            XCTAssertTrue(String(section(billing).limitReachedText.characters).hasSuffix("Increase or remove your limit"))
        }
    }

    private var activeStatus: UsageBillingStatus {
        UsageBillingStatus(isUsageBilling: true, isSelfHostedAI: false, canUseAIClassifiers: true, usageBillingLimit: nil)
    }

    private var freeStatus: UsageBillingStatus {
        UsageBillingStatus(isUsageBilling: false, isSelfHostedAI: false, canUseAIClassifiers: false, usageBillingLimit: nil)
    }

    private func makeModel(transport: RecordingAITransport, status: UsageBillingStatus) -> TrainerAIPromptModel {
        TrainerAIPromptModel(api: AIClassifierAPI(transport: transport), billingStatus: { status },
                             storyVolumes: { AIClassifierStoryVolumes(storiesForFeed: { _ in 300 }, storiesForFolder: { _ in 0 },
                                                                      storiesForAllSites: { 0 }) })
    }

    private func section(_ model: TrainerAIPromptModel) -> TrainerAIPromptSection {
        TrainerAIPromptSection(kind: .content, model: model, feed: nil, story: nil, isPremiumArchive: true,
                               currentFolderName: "", fontBuilder: { _, size in .system(size: size) })
    }

    /// The titles FeedsObjCViewController.m puts in the feed list's settings menu.
    private func settingsMenuTitles() throws -> [String] {
        let app = NewsBlurAppDelegate()
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

/// AIClassifierTests.swift records what NewsBlurAppDelegate.m presents instead of showing it.
@MainActor private final class BillingPresentationSplitController: SplitViewController {
    var requestedPresentation: UIViewController?
    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) { completion?() }
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        requestedPresentation = viewControllerToPresent
        completion?()
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
