import XCTest
import WebKit

@testable import NewsBlur

final class Test_NewsBlurSocketClient: XCTestCase {
    func test_backgroundConnectionReadsServerConfigurationOnMainWithoutOpeningASocket() async {
        let configured = expectation(description: "Server configuration read")
        let started = expectation(description: "Connection received its endpoint")
        let client = SocketEndpointProbe(serverURLProvider: {
            XCTAssertTrue(Thread.isMainThread, "NewsBlurAppDelegate.shared accesses UIApplication and must run on main")
            configured.fulfill()
            return "https://reader.example.test/custom"
        }, connectionStarted: { endpoint in
            XCTAssertFalse(Thread.isMainThread, "Socket state must remain on its serial worker queue")
            XCTAssertEqual(endpoint, "wss://reader.example.test/custom/v3/socket.io/")
            started.fulfill()
        })

        DispatchQueue.global(qos: .utility).async {
            client.connect(username: "fixture", feeds: [])
        }

        await fulfillment(of: [configured, started], timeout: 2)
    }

    func test_disconnectDuringConfigurationPreventsADelayedConnection() async {
        let configured = expectation(description: "Configuration captured before cancellation")
        let started = expectation(description: "Cancelled connection must not start")
        started.isInverted = true
        weak var cancellationTarget: NewsBlurSocketClient?
        let client = SocketEndpointProbe(serverURLProvider: {
            XCTAssertTrue(Thread.isMainThread)
            cancellationTarget?.disconnect()
            configured.fulfill()
            return "http://localhost:8000"
        }, connectionStarted: { _ in started.fulfill() })
        cancellationTarget = client

        client.connect(username: "fixture", feeds: [])

        await fulfillment(of: [configured], timeout: 2)
        await fulfillment(of: [started], timeout: 0.1)
        XCTAssertFalse(client.connected)
    }
}

private final class SocketEndpointProbe: NewsBlurSocketClient {
    private let connectionStarted: @Sendable (String) -> Void

    init(serverURLProvider: @escaping () -> String?, connectionStarted: @escaping @Sendable (String) -> Void) {
        self.connectionStarted = connectionStarted
        super.init(serverURLProvider: serverURLProvider)
    }

    // LoginViewControllerTests.swift observes connection configuration without creating a URLSession or sending messages.
    override func connectWebSocket() { connectionStarted(baseURL) }
}

@MainActor
final class Test_InteractionCellLayout: XCTestCase {
    func test_interactionTextStaysWithinContentBeforeTheAccessory() throws {
        try assertTextFitsContent(cellNames: ["InteractionCell", "SmallInteractionCell"], labelKey: "interactionLabel")
    }

    func test_activityTextStaysWithinContentBeforeTheAccessory() throws {
        try assertTextFitsContent(cellNames: ["ActivityCell", "SmallActivityCell"], labelKey: "activityLabel")
    }

    private func assertTextFitsContent(cellNames: [String], labelKey: String) throws {
        for className in cellNames {
            let cellType = try XCTUnwrap(NSClassFromString(className) as? UITableViewCell.Type)
            let cell = cellType.init(style: .default, reuseIdentifier: nil)
            let label = try XCTUnwrap(cell.value(forKey: labelKey) as? UILabel)
            let rightMargin = CGFloat(try XCTUnwrap(cell.value(forKey: "rightMargin") as? NSNumber).doubleValue)
            label.numberOfLines = 0
            label.text = String(repeating: "A long interaction and reply must wrap before the disclosure control. ", count: 4)

            for width in [CGFloat(320), 466, 768] {
                for accessoryWidth in [CGFloat(84), 28, 0] {
                    cell.frame = CGRect(x: 0, y: 0, width: width, height: 260)
                    // LoginViewControllerTests.swift lets UIKit reserve the accessory region, including a Duo-sized exclusion.
                    cell.accessoryView = accessoryWidth > 0 ? UIImageView(frame: CGRect(x: 0, y: 0, width: accessoryWidth, height: 24)) : nil
                    cell.setNeedsLayout()
                    cell.layoutIfNeeded()
                    if accessoryWidth > 0 {
                        XCTAssertLessThan(cell.contentView.bounds.width, cell.bounds.width,
                                          "The fixture must exercise a narrower system content area")
                    }
                    XCTAssertGreaterThan(label.bounds.width, 0)
                    XCTAssertLessThanOrEqual(label.frame.maxX + rightMargin, cell.contentView.bounds.maxX + 0.5,
                                             "\(className) must not render interaction text over its accessory")
                }
            }
        }
    }

    func test_interactionRowHeightFitsTextAtTheVisibleContentWidth() throws {
        try assertModuleRowFits(moduleName: "InteractionsModule", tableKey: "interactionsTable", labelKey: "interactionLabel")
    }

    func test_activityModuleRowHeightFitsTextAtTheVisibleContentWidth() throws {
        try assertModuleRowFits(moduleName: "ActivityModule", tableKey: "activitiesTable", labelKey: "activityLabel")
    }

    private func assertModuleRowFits(moduleName: String, tableKey: String, labelKey: String) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let moduleType = try XCTUnwrap(NSClassFromString(moduleName) as? UIView.Type)
        for phone in [true, false] {
            let app = DuoInteractionSizingApp()
            app.usesPhoneCells = phone
            let records: [[String: Any]] = [[
                "category": "comment_reply", "title": "A long article discussion", "time_since": "1 hour",
                "content": String(repeating: "A long reply must remain readable within the content area reserved before the disclosure indicator. ", count: 12),
                "with_user": ["username": "Reader", "photo_url": ""]
            ]]
            app.dictSocialProfile = ["username": "You"]
            if moduleName == "ActivityModule" {
                app.userActivitiesArray = records
            } else {
                app.userInteractionsArray = records
            }
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIViewController()
            window.isHidden = false
            defer { window.isHidden = true }
            let module = moduleType.init(frame: window.bounds)
            module.setValue(app, forKey: "appDelegate")
            module.setValue(true, forKey: "pageFinished")
            window.rootViewController?.view.addSubview(module)
            module.setNeedsLayout()
            module.layoutIfNeeded()
            let table = try XCTUnwrap(module.value(forKey: tableKey) as? UITableView)
            table.reloadData()
            window.layoutIfNeeded()
            table.layoutIfNeeded()
            let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
            let label = try XCTUnwrap(cell.value(forKey: labelKey) as? UILabel)
            func metric(_ key: String) throws -> CGFloat {
                CGFloat(try XCTUnwrap(cell.value(forKey: key) as? NSNumber).doubleValue)
            }
            let textWidth = try cell.contentView.bounds.width - 2 * metric("leftMargin") - metric("avatarSize") - metric("rightMargin")
            let textHeight = label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
            let requiredHeight = try textHeight + metric("topMargin") + metric("bottomMargin")
            let geometry = XCTAttachment(string: "phone=\(phone), table=\(table.bounds), safe=\(table.safeAreaInsets), adjusted=\(table.adjustedContentInset), cell=\(cell.frame), content=\(cell.contentView.frame), label=\(label.frame), requiredHeight=\(requiredHeight)")
            geometry.name = "\(moduleName)-row-sizing-\(phone ? "phone" : "regular")"
            geometry.lifetime = .keepAlways
            add(geometry)
            XCTAssertLessThan(cell.contentView.bounds.width, cell.bounds.width)
            XCTAssertGreaterThanOrEqual(cell.bounds.height + 1, requiredHeight,
                                        "\(moduleName) row measurement must use the same available width as its visible label")
            let expectedHeight = try max(requiredHeight, metric("avatarSize") + metric("topMargin") + metric("bottomMargin"))
            XCTAssertLessThanOrEqual(cell.bounds.height, expectedHeight + 4,
                                     "\(moduleName) must not estimate extra blank space from a narrower prototype cell")
        }
    }

    func test_profileActivityRowHeightFitsTextAtTheVisibleContentWidth() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let profileType = try XCTUnwrap(NSClassFromString("UserProfileViewController") as? UIViewController.Type)
        let profile = profileType.init(nibName: nil, bundle: nil)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { window.isHidden = true }
        profile.view = UIView(frame: window.bounds)
        profile.setValue(["username": "Reader"], forKey: "userProfile")
        profile.setValue([[
            "category": "sharedstory", "title": "An article with a long discussion", "time_since": "1 hour",
            "content": String(repeating: "A long shared-story comment must stay readable before the disclosure indicator and retain all its lines. ", count: 12)
        ]], forKey: "activitiesArray")
        let source = try XCTUnwrap(profile as? UITableViewDataSource)
        let delegate = try XCTUnwrap(profile as? UITableViewDelegate)
        let activityOnly = DuoProfileActivityTable(source: source, delegate: delegate)
        let table = UITableView(frame: window.bounds, style: .grouped)
        profile.setValue(table, forKey: "profileTable")
        table.dataSource = activityOnly
        table.delegate = activityOnly
        profile.view.addSubview(table)
        window.rootViewController?.view.addSubview(profile.view)
        table.reloadData()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let label = try XCTUnwrap(cell.value(forKey: "activityLabel") as? UILabel)
        func metric(_ key: String) throws -> CGFloat {
            CGFloat(try XCTUnwrap(cell.value(forKey: key) as? NSNumber).doubleValue)
        }
        let textWidth = try cell.contentView.bounds.width - 2 * metric("leftMargin") - metric("avatarSize") - metric("rightMargin")
        let requiredHeight = try label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height + metric("topMargin") + metric("bottomMargin")
        let geometry = XCTAttachment(string: "table=\(table.bounds), safe=\(table.safeAreaInsets), cell=\(cell.frame), content=\(cell.contentView.frame), label=\(label.frame), requiredHeight=\(requiredHeight)")
        geometry.name = "profile-activity-row-sizing"
        geometry.lifetime = .keepAlways
        add(geometry)
        XCTAssertGreaterThanOrEqual(cell.bounds.height + 1, requiredHeight,
                                    "The profile's real activity delegate must reserve enough height for the visible text width")
        let expectedHeight = try max(requiredHeight, metric("avatarSize") + metric("topMargin") + metric("bottomMargin"))
        XCTAssertLessThanOrEqual(cell.bounds.height, expectedHeight + 4,
                                 "Grouped profile activity rows must use their own actual content width")
        withExtendedLifetime(activityOnly) {}
    }

    func test_profileActivityRendersHTMLCommentsAsReadableParagraphs() throws {
        let html = "<blockquote><p>I&#x27;ve found <em>useful</em> software.</p><p>Second &amp; final paragraph.</p></blockquote>"
        let htmlText = try profileActivityText(content: html)
        XCTAssertTrue(htmlText.contains("I've found useful software."))
        XCTAssertTrue(htmlText.contains("Second & final paragraph."))
        XCTAssertNotNil(htmlText.range(of: "software\\.\\n+Second", options: .regularExpression),
                        "HTML paragraphs must remain separate readable paragraphs")
        XCTAssertFalse(htmlText.contains("<blockquote>"))
        XCTAssertFalse(htmlText.contains("<p>"))
        XCTAssertFalse(htmlText.contains("&#x27;"))

        let plainText = try profileActivityText(content: "2 < 3\n\nAlready readable &amp; preserved.")
        XCTAssertTrue(plainText.contains("2 < 3\n\nAlready readable & preserved."),
                      "Plain comments must retain their line breaks and literal comparisons")
    }

    func test_modulesPreserveCollapsedRowsForMissingAuthors() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for moduleName in ["InteractionsModule", "ActivityModule"] {
            let isInteraction = moduleName == "InteractionsModule"
            let categories = isInteraction ? ["follow", "comment_reply", "reply_reply", "story_reshare", "comment_like"] :
                ["follow", "comment_reply", "comment_like", "signup", "sharedstory", "feedsub", "star"]
            let collapsedCount = isInteraction ? categories.count : 4
            for phone in [true, false] {
                let app = DuoInteractionSizingApp()
                app.usesPhoneCells = phone
                app.dictSocialProfile = ["username": "You"]
                var records = categories.map { missingAuthorRecord(category: $0) }
                records.append(["category": "follow", "title": "An article", "content": "A comment", "time_since": "1 hour",
                                "with_user": ["username": "Reader", "photo_url": ""]])
                if isInteraction { app.userInteractionsArray = records } else { app.userActivitiesArray = records }
                let window = UIWindow(windowScene: scene)
                window.rootViewController = UIViewController()
                window.isHidden = false
                defer { window.isHidden = true }
                let moduleType = try XCTUnwrap(NSClassFromString(moduleName) as? UIView.Type)
                let module = moduleType.init(frame: window.bounds)
                module.setValue(app, forKey: "appDelegate")
                module.setValue(true, forKey: "pageFinished")
                window.rootViewController?.view.addSubview(module)
                module.setNeedsLayout()
                module.layoutIfNeeded()
                let table = try XCTUnwrap(module.value(forKey: isInteraction ? "interactionsTable" : "activitiesTable") as? UITableView)
                table.reloadData()
                window.layoutIfNeeded()
                table.layoutIfNeeded()
                assertMissingAuthorRowHeights(table: table, recordCount: records.count, collapsedCount: collapsedCount)
            }
        }
    }

    func test_profilePreservesCollapsedActivityRowsForMissingAuthors() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let categories = ["follow", "comment_reply", "comment_like", "signup", "sharedstory", "feedsub", "star"]
        let profileType = try XCTUnwrap(NSClassFromString("UserProfileViewController") as? UIViewController.Type)
        let profile = profileType.init(nibName: nil, bundle: nil)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { window.isHidden = true }
        profile.view = UIView(frame: window.bounds)
        profile.setValue(["username": "Reader"], forKey: "userProfile")
        profile.setValue(categories.map { missingAuthorRecord(category: $0) }, forKey: "activitiesArray")
        let activityOnly = DuoProfileActivityTable(source: try XCTUnwrap(profile as? UITableViewDataSource),
                                                   delegate: try XCTUnwrap(profile as? UITableViewDelegate))
        let table = UITableView(frame: window.bounds, style: .grouped)
        profile.setValue(table, forKey: "profileTable")
        table.dataSource = activityOnly
        table.delegate = activityOnly
        profile.view.addSubview(table)
        window.rootViewController?.view.addSubview(profile.view)
        table.reloadData()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        assertMissingAuthorRowHeights(table: table, recordCount: categories.count, collapsedCount: 4)
        withExtendedLifetime(activityOnly) {}
    }

    private func missingAuthorRecord(category: String) -> [String: Any] {
        ["category": category, "title": "An article", "content": "A comment", "time_since": "1 hour", "with_user": NSNull()]
    }

    private func assertMissingAuthorRowHeights(table: UITableView, recordCount: Int, collapsedCount: Int,
                                               file: StaticString = #filePath, line: UInt = #line) {
        for row in 0..<recordCount {
            let height = table.rectForRow(at: IndexPath(row: row, section: 0)).height
            if row < collapsedCount {
                XCTAssertEqual(height, 1, accuracy: 0.01, "Missing-author rows must retain their previous collapsed height", file: file, line: line)
            } else {
                XCTAssertGreaterThan(height, 1, "Valid activity and categories without authors must retain normal automatic sizing", file: file, line: line)
            }
        }
    }

    private func profileActivityText(content: String) throws -> String {
        let profileType = try XCTUnwrap(NSClassFromString("UserProfileViewController") as? UIViewController.Type)
        let profile = profileType.init(nibName: nil, bundle: nil)
        profile.view = UIView(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        profile.setValue(["username": "Reader"], forKey: "userProfile")
        // LoginViewControllerTests.swift omits a feed identifier to render real activity text without fetching a favicon.
        profile.setValue([[
            "category": "sharedstory", "title": "An article", "time_since": "1 hour", "content": content
        ]], forKey: "activitiesArray")
        let table = UITableView(frame: profile.view.bounds, style: .grouped)
        profile.setValue(table, forKey: "profileTable")
        let source = try XCTUnwrap(profile as? UITableViewDataSource)
        let cell = source.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1))
        let label = try XCTUnwrap(cell.value(forKey: "activityLabel") as? UILabel)
        return try XCTUnwrap(label.attributedText?.string)
    }
}

@MainActor private final class DuoInteractionSizingApp: NewsBlurAppDelegate {
    var usesPhoneCells = true
    override var isPhone: Bool { usesPhoneCells }
}

@MainActor private final class DuoProfileActivityTable: NSObject, UITableViewDataSource, UITableViewDelegate {
    let source: UITableViewDataSource
    let delegate: UITableViewDelegate
    init(source: UITableViewDataSource, delegate: UITableViewDelegate) {
        self.source = source
        self.delegate = delegate
        super.init()
    }
    // LoginViewControllerTests.swift calls the real profile activity section without loading badges, followers, or network data.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        source.tableView(tableView, numberOfRowsInSection: 1)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        source.tableView(tableView, cellForRowAt: IndexPath(row: indexPath.row, section: 1))
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        delegate.tableView?(tableView, heightForRowAt: IndexPath(row: indexPath.row, section: 1)) ?? 0
    }
}

@MainActor
final class Test_FeedDetailEmptyState: XCTestCase {
    func test_expandedPhoneShowsSelectionPromptInsteadOfLoadingAnUnselectedFeed() {
        let preferences = UserDefaults.standard
        let oldOpening = preferences.object(forKey: "app_opening")
        preferences.set("feeds", forKey: "app_opening")
        defer { preferences.set(oldOpening, forKey: "app_opening") }

        let app = DuoEmptyFeedApp()
        let collection = StoriesCollection()
        collection.appDelegate = app
        app.storiesCollection = collection
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        app.detailViewController = detail
        let stories = DuoEmptyFeedStories()
        stories.fixtureApp = app
        stories.appDelegate = app
        stories.storiesCollection = collection
        app.fixtureStories = stories
        detail.feedDetailViewController = stories
        stories.loadViewIfNeeded()

        for compact in [true, false, true, false] {
            detail.isCompact = compact
            stories.viewWillAppear(false)

            XCTAssertTrue(stories.appDelegate === app, "The fixture must never bind to the signed-in app")
            XCTAssertEqual(stories.messageView.isHidden, compact,
                           "An expanded unselected pane must explain what to select instead of showing a permanent loading row")
            XCTAssertEqual(stories.numberOfSections(in: stories.storyTitlesTable), compact ? 1 : 0)
            XCTAssertEqual(stories.tableView(stories.storyTitlesTable, numberOfRowsInSection: 0), compact ? 1 : 0)
            if !compact {
                XCTAssertEqual(stories.messageLabel.text, "Select a feed to read")
            }
            XCTAssertFalse(stories.pageFetching, "There is no selected feed or pending request in this state")
        }
    }

    func test_expandedSelectionPromptDoesNotCoverSelectedFeedsFoldersOrDailyBriefing() {
        let preferences = UserDefaults.standard
        let oldOpening = preferences.object(forKey: "app_opening")
        preferences.set("feeds", forKey: "app_opening")
        defer { preferences.set(oldOpening, forKey: "app_opening") }

        for selection in ["feed", "everything", "daily_briefing"] {
            let app = DuoEmptyFeedApp()
            let collection = StoriesCollection()
            collection.appDelegate = app
            if selection == "feed" {
                collection.activeFeed = ["id": 1, "feed_title": "Fixture Feed"]
            } else {
                collection.activeFolder = selection
                collection.isRiverView = true
                collection.isDailyBriefing = selection == "daily_briefing"
            }
            app.storiesCollection = collection
            let detail = DuoExpansionDetailController()
            detail.appDelegate = app
            detail.isCompact = false
            app.detailViewController = detail
            let stories = DuoEmptyFeedStories()
            stories.fixtureApp = app
            stories.appDelegate = app
            stories.storiesCollection = collection
            app.fixtureStories = stories
            detail.feedDetailViewController = stories
            stories.loadViewIfNeeded()
            stories.viewWillAppear(false)

            XCTAssertTrue(stories.messageView.isHidden,
                          "The empty-selection prompt must not cover the \(selection) loading or briefing presentation")
            XCTAssertTrue(stories.appDelegate === app)
        }
    }
}

@MainActor private final class DuoEmptyFeedApp: NewsBlurAppDelegate {
    var fixtureStories: FeedDetailViewController?
    override var feedDetailViewController: FeedDetailViewController! { fixtureStories }
    override func unreadCount() -> Int { 0 }
    override func donateFeed() {}
    override func donateFolder() {}
}

@MainActor private final class DuoEmptyFeedStories: FeedDetailViewController {
    var fixtureApp: NewsBlurAppDelegate?
    override var appDelegate: NewsBlurAppDelegate! {
        get { super.appDelegate }
        set { super.appDelegate = fixtureApp ?? newValue }
    }
    override var isPhone: Bool { true }
    override var isLegacyTable: Bool { true }
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 450, height: 669))
        storyTitlesTable = UITableView(frame: view.bounds)
        view.addSubview(storyTitlesTable)
        messageView = UIView(frame: view.bounds)
        messageLabel = UILabel(frame: messageView.bounds)
        messageView.addSubview(messageLabel)
        view.addSubview(messageView)
        searchField = UITextField()
        refreshControl = UIRefreshControl()
        storyTitlesHeaderBar = StoryTitlesHeaderBar()
        storyTitlesHeaderBar.setup(in: view)
        storyTitlesHeaderBar.addSearchField(searchField)
    }
    // LoginViewControllerTests.swift retains the real appearance, theme, and empty-table decisions without fetching account data or mounting reader chrome.
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func reload() {}
    override func updateSidebarButton(for displayMode: UISplitViewController.DisplayMode) {}
    override func fadeSelectedCell(_ deselect: Bool) {}
}

@available(iOS 15.0, *)
@MainActor
final class AddSiteSheetViewControllerTests: XCTestCase {
    func test_loadingViewEmbedsSwiftUIContent() {
        let controller = AddSiteSheetViewController()

        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.children.count, 1)
        XCTAssertEqual(controller.view.subviews.count, 1)
        XCTAssertTrue(controller.children.first?.view.isDescendant(of: controller.view) == true)
    }

    func test_initialFeedAddressSeedsViewModel() throws {
        let controller = AddSiteSheetViewController()
        controller.initialFeedAddress = "https://example.com/feed"

        controller.loadViewIfNeeded()

        let viewModel = try XCTUnwrap(extractViewModel(from: controller))
        XCTAssertEqual(viewModel.searchText, "https://example.com/feed")
    }

    private func extractViewModel(from controller: AddSiteSheetViewController) -> AddSiteViewModel? {
        guard let optionalViewModel = Mirror(reflecting: controller).descendant("viewModel") else {
            return nil
        }

        let mirror = Mirror(reflecting: optionalViewModel)
        return mirror.children.first?.value as? AddSiteViewModel
    }
}

@available(iOS 15.0, *)
@MainActor
final class DetailViewControllerTests: XCTestCase {
    func test_compactHeightPhoneOwnsAndRestoresOnlyItsSplitWidthOverride() {
        let landscapePhone = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: .phone),
            UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: .compact)])
        let expandedPhoneWithHorizontalChrome = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: .phone),
            UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: .regular)])
        XCTAssertFalse(Utilities.usesSystemVerticalBar(expandedPhoneWithHorizontalChrome))
        for existingOverride in [false, true] {
            let split = SplitViewController(style: .doubleColumn)
            if existingOverride { split.traitOverrides.horizontalSizeClass = .regular }
            for _ in 0..<10 {
                split.updatePhoneWidthPolicy(for: landscapePhone)
                XCTAssertTrue(split.traitOverrides.contains(UITraitHorizontalSizeClass.self))
                XCTAssertEqual(split.traitOverrides.horizontalSizeClass, .compact)
            }

            split.updatePhoneWidthPolicy(for: expandedPhoneWithHorizontalChrome)

            XCTAssertEqual(split.traitOverrides.contains(UITraitHorizontalSizeClass.self), existingOverride,
                           "Leaving conventional phone landscape must release only the policy's own override")
            if existingOverride { XCTAssertEqual(split.traitOverrides.horizontalSizeClass, .regular) }
        }
    }

    func test_regularHeightPhoneAndAllPadSizesKeepNativeSplitTraits() {
        for idiom in [UIUserInterfaceIdiom.phone, .pad] {
            for vertical in [UIUserInterfaceSizeClass.compact, .regular] {
                if idiom == .phone && vertical == .compact { continue }
                let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: idiom),
                    UITraitCollection(horizontalSizeClass: .regular), UITraitCollection(verticalSizeClass: vertical)])
                let split = SplitViewController(style: .doubleColumn)

                split.updatePhoneWidthPolicy(for: traits)

                XCTAssertFalse(split.traitOverrides.contains(UITraitHorizontalSizeClass.self),
                               "Duo's regular-height inner display and iPad windows must keep native split sizing")
            }
        }
    }

    func test_conventionalLandscapePhoneKeepsCompactReaderNavigation() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "split_behavior")
        defer { defaults.set(original, forKey: "split_behavior") }
        let detail = ConventionalLandscapePhoneDetailController()
        let stories = FeedDetailViewController()
        let pages = StoryPagesViewController()
        detail.feedDetailViewController = stories
        detail.storyPagesViewController = pages
        // LoginViewControllerTests.swift models a conventional large phone's landscape traits, not Duo's regular-height inner display.
        detail.isCompact = false

        XCTAssertEqual(detail.traitCollection.horizontalSizeClass, .regular)
        XCTAssertEqual(detail.traitCollection.verticalSizeClass, .compact)
        XCTAssertFalse(Utilities.usesSystemVerticalBar(detail.traitCollection), "This fixture must not inherit Duo's native side-bar capability from its test host")
        XCTAssertTrue(detail.isPhoneOrCompact, "A conventional landscape phone must keep its single reader navigation stack")
        XCTAssertTrue(detail.feedDetailNavigationItem === stories.navigationItem)
        XCTAssertTrue(detail.storiesNavigationItem === pages.navigationItem)
        for preference in ["auto", "tile", "displace", "overlay"] {
            defaults.set(preference, forKey: "split_behavior")
            XCTAssertEqual(detail.behaviorString, preference, "Duo's expanded two-column policy must not replace conventional phone preferences")
        }
    }

    func test_phoneBrowserRoutesStatisticsAndOriginalStoriesThroughTheResolvedLayout() {
        for compact in [false, true] {
            for statistics in [false, true] {
                let app = DuoBrowserRoutingApp()
                app.storiesCollection = StoriesCollection()
                app.dictFeeds = ["123": ["id": 123, "feed_title": "Fixture Feed"]]
                let detail = DiscoveryTransitionPhoneDetailController()
                detail.appDelegate = app
                detail.isCompact = compact
                app.detailViewController = detail
                app.splitViewController = DuoSidebarSplitController(style: .doubleColumn)
                let navigation = DuoBrowserRoutingNavigationController(rootViewController: UIViewController())
                app.feedsNavigationController = navigation
                let browser = DuoBrowserRoutingController()
                browser.appDelegate = app
                app.originalStoryViewController = browser
                let anchor = UIBarButtonItem(title: "Open", style: .plain, target: nil, action: nil)

                if statistics {
                    app.openStatistics(withFeed: "123", sender: anchor)
                } else {
                    app.show(inAppBrowser: URL(string: "https://example.com/article"), withCustomTitle: "Article", fromSender: anchor)
                }

                XCTAssertEqual(navigation.shownControllers.count, compact ? 1 : 0,
                               "An expanded phone must not push its browser into the hidden feed sidebar")
                XCTAssertEqual(app.presentedBrowsers.count, compact ? 0 : 1)
                XCTAssertTrue((compact ? navigation.shownControllers.first : app.presentedBrowsers.first) === browser)
                if !compact { XCTAssertTrue(app.browserAnchor === anchor) }
                XCTAssertEqual(browser.loadRequests, 1)
                XCTAssertEqual(browser.customPageTitle, statistics ? "Fixture Feed" : "Article")
            }
        }
    }

    func test_browserCloseDismissesExpandedPresentationAndPreservesCompactPop() {
        for compact in [false, true] {
            let app = DuoBrowserRoutingApp()
            app.storiesCollection = StoriesCollection()
            let detail = DiscoveryTransitionPhoneDetailController()
            detail.appDelegate = app
            detail.isCompact = compact
            app.detailViewController = detail
            let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
            pages.appDelegate = app
            detail.storyPagesViewController = pages
            let navigation = DuoBrowserDismissalNavigationController()
            app.feedsNavigationController = navigation
            let browser = DuoBrowserRoutingController()
            browser.appDelegate = app
            app.originalStoryViewController = browser
            navigation.simulatedControllers = compact ? [pages, browser] : [UIViewController()]
            browser.simulatedPresenter = compact ? nil : navigation

            browser.closeOriginalView()

            XCTAssertEqual(browser.dismissals, compact ? 0 : 1,
                           "The browser's real close action must dismiss its expanded presentation")
            XCTAssertEqual(navigation.popTargets.count, compact ? 1 : 0)
            if compact { XCTAssertTrue(navigation.popTargets.first === pages) }
        }
    }

    func test_showFeedsListHonorsAnimationForCompactAndExpandedNavigation() {
        for collapsed in [true, false] {
            let app = DuoFeedReturnApp()
            let split = DuoFeedReturnSplitController(style: .doubleColumn)
            split.simulatedCollapsed = collapsed
            app.splitViewController = split
            let navigation = DuoFeedReturnNavigationController()
            app.feedsNavigationController = navigation

            app.showFeedsList(animated: false)
            app.showFeedsList(animated: true)

            XCTAssertEqual(navigation.popAnimations, collapsed ? [false, true] : [])
            XCTAssertEqual(app.shownColumns, collapsed ? [] : [.primary, .primary])
            XCTAssertEqual(app.columnAnimations, collapsed ? [] : [false, true],
                           "An immediate feed-list reset must finish before another destination opens")
        }
    }

    func test_keyboardTrainerUsesTheVisibleReaderSettingsAnchor() {
        for vertical in [true, false] {
            let app = DuoTrainerAnchorApp()
            let detail = DetailViewController()
            detail.appDelegate = app
            app.detailViewController = detail
            let pages = DuoTrainerAnchorPages(nibName: nil, bundle: nil)
            pages.appDelegate = app
            pages.simulatedVerticalToolbar = vertical
            detail.storyPagesViewController = pages
            let customSettings = UIBarButtonItem(customView: UIButton())
            let nativeSettings = UIBarButtonItem(title: "Story settings", style: .plain, target: nil, action: nil)
            pages.fontSettingsButton = customSettings
            // LoginViewControllerTests.swift supplies the native item without mounting the entire reader.
            pages.setValue(nativeSettings, forKey: "verticalSettingsButton")
            let source = BaseViewController()
            source.appDelegate = app

            source.showTrain(nil)

            XCTAssertTrue(app.trainerAnchor === (vertical ? nativeSettings : customSettings),
                          "Keyboard training must anchor to the same visible settings control as the reader")
        }
    }

    func test_expandedPhoneUsesTwoReaderColumnsRegardlessOfAspectRatio() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "split_behavior")
        defer { defaults.set(original, forKey: "split_behavior") }
        let detail = DiscoveryTransitionPhoneDetailController()
        detail.isCompact = false
        for preference in ["auto", "tile", "displace"] {
            defaults.set(preference, forKey: "split_behavior")
            XCTAssertEqual(detail.behaviorString, "displace", "Expanded phones must leave room for both story titles and the article")
        }
        defaults.set("overlay", forKey: "split_behavior")
        XCTAssertEqual(detail.behaviorString, "overlay")
        detail.isCompact = true
        defaults.set("auto", forKey: "split_behavior")
        XCTAssertEqual(detail.behaviorString, "auto", "Folding must not rewrite the saved preference")
    }

    func test_showingExpandedFeedsDoesNotQueueAConflictingHiddenDisplayMode() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "split_behavior")
        defer { defaults.set(original, forKey: "split_behavior") }
        defaults.set("auto", forKey: "split_behavior")
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let split = DuoSidebarSplitController(style: .doubleColumn)
        split.view.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
        split.simulatedDisplayMode = .oneBesideSecondary
        split.preferredDisplayMode = .oneBesideSecondary
        app.splitViewController = split

        detail.show(column: .primary, animated: false)

        XCTAssertEqual(split.shownColumns, [.primary])
        XCTAssertEqual(split.preferredSplitBehavior, .overlay)
        XCTAssertEqual(split.preferredDisplayMode, .oneOverSecondary,
                       "Showing an already appearing primary must not queue secondaryOnly and hide it after the show call")
    }

    func test_showingFeedsCancelsPendingHiddenDisplayModesForTheCurrentSplitStyle() {
        let defaults = UserDefaults.standard
        let originalBehavior = defaults.object(forKey: "split_behavior")
        let originalPosition = defaults.object(forKey: "pending-hide-fixture:story_titles_position")
        defaults.set("titles_on_left", forKey: "pending-hide-fixture:story_titles_position")
        defer {
            defaults.set(originalBehavior, forKey: "split_behavior")
            defaults.set(originalPosition, forKey: "pending-hide-fixture:story_titles_position")
        }
        let cases: [(phone: Bool, style: UISplitViewController.Style, behavior: String,
                     visibleMode: UISplitViewController.DisplayMode, nativeBehavior: UISplitViewController.SplitBehavior)] = [
            (true, .doubleColumn, "auto", .oneOverSecondary, .overlay),
            (true, .doubleColumn, "tile", .oneOverSecondary, .overlay),
            (true, .doubleColumn, "displace", .oneOverSecondary, .overlay),
            (true, .doubleColumn, "overlay", .oneOverSecondary, .overlay),
            (true, .tripleColumn, "auto", .twoDisplaceSecondary, .displace),
            (true, .tripleColumn, "displace", .twoDisplaceSecondary, .displace),
            (false, .doubleColumn, "tile", .oneBesideSecondary, .tile),
            (false, .doubleColumn, "displace", .oneBesideSecondary, .displace),
            (false, .doubleColumn, "overlay", .oneOverSecondary, .overlay),
            (false, .tripleColumn, "tile", .twoBesideSecondary, .tile),
            (false, .tripleColumn, "displace", .twoDisplaceSecondary, .displace),
            (false, .tripleColumn, "overlay", .twoOverSecondary, .overlay)
        ]

        for scenario in cases {
            defaults.set(scenario.behavior, forKey: "split_behavior")
            let app = NewsBlurAppDelegate()
            let collection = StoriesCollection()
            collection.appDelegate = app
            collection.activeFeed = ["id": "pending-hide-fixture"]
            app.storiesCollection = collection
            let detail = DuoExpansionDetailController()
            detail.simulatesPhone = scenario.phone
            detail.appDelegate = app
            detail.isCompact = false
            app.detailViewController = detail
            let split = DuoSidebarSplitController(style: scenario.style)
            split.view.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
            split.simulatedDisplayMode = scenario.visibleMode
            split.preferredDisplayMode = scenario.visibleMode
            app.splitViewController = split
            XCTAssertTrue(detail.storyTitlesOnLeft)

            // LoginViewControllerTests.swift reproduces checkLayout's queued hide while UIKit still reports the visible primary.
            app.updateSplitBehavior(false)
            if scenario.behavior != "tile" {
                XCTAssertEqual(split.preferredDisplayMode, .secondaryOnly)
            } else {
                split.preferredDisplayMode = .secondaryOnly
            }
            detail.show(column: .primary, animated: false)

            XCTAssertEqual(split.shownColumns, [.primary])
            XCTAssertEqual(split.preferredDisplayMode, scenario.visibleMode,
                           "Explicit Feeds navigation must cancel a pending hide with a mode allowed by this split style and behavior")
            XCTAssertEqual(split.preferredSplitBehavior, scenario.nativeBehavior,
                           "Making Feeds visible must use a supported reveal for \(scenario.phone ? "phone" : "iPad") style \(scenario.style.rawValue)")
            XCTAssertEqual(defaults.string(forKey: "split_behavior"), scenario.behavior,
                           "Native reveal compatibility must not rewrite the user's layout preference")
        }
    }

    func test_expandedPhoneDiscoveryKeepsItsTiledFeedSidebar() {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        detail.simulatesDiscovery = true
        app.detailViewController = detail
        let split = DuoSidebarSplitController(style: .doubleColumn)
        split.view.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
        app.splitViewController = split

        detail.show(column: .primary, animated: false)

        XCTAssertEqual(split.shownColumns, [.primary])
        XCTAssertEqual(split.preferredSplitBehavior, .tile)
        XCTAssertEqual(split.preferredDisplayMode, .oneBesideSecondary,
                       "Discover Sites has no embedded article pane and retains its two-column tiled layout")
    }

    func test_tiledFeedSidebarPairsWithTitlesOnlyForAnExpandedDoubleColumnPhone() {
        for excludedCondition in -1..<5 {
            for mode in [StorySplitPreferredDisplayMode.oneBesideSecondary, .oneOverSecondary, .secondaryOnly, .twoBesideSecondary] {
                let result = StorySplitBehaviorDecision.shouldShowStoryTitlesBesideTiledFeeds(
                    isPhone: excludedCondition != 0,
                    isCompact: excludedCondition == 1,
                    isDoubleColumn: excludedCondition != 2,
                    isDiscoverSitesVisible: excludedCondition == 3,
                    storyTitlesOnLeft: excludedCondition != 4,
                    displayMode: mode
                )
                XCTAssertEqual(result, excludedCondition == -1 && mode == .oneBesideSecondary,
                               "Only an expanded double-column phone replaces its reading columns with tiled Feeds and titles")
            }
        }
    }

    func test_rightArrowRevealsEmbeddedTitlesWithoutRequestingAnUnavailableSplitColumn() {
        let defaults = UserDefaults.standard
        let originalBehavior = defaults.object(forKey: "split_behavior")
        let positionKey = "keyboard-sidebar-fixture:story_titles_position"
        let originalPosition = defaults.object(forKey: positionKey)
        defaults.set("titles_on_left", forKey: positionKey)
        defer {
            defaults.set(originalBehavior, forKey: "split_behavior")
            defaults.set(originalPosition, forKey: positionKey)
        }
        let scenarios: [(phone: Bool, style: UISplitViewController.Style, behavior: String)] = [
            (true, .doubleColumn, "displace"),
            (true, .doubleColumn, "overlay"),
            (false, .doubleColumn, "displace"),
            (false, .tripleColumn, "displace")
        ]
        for scenario in scenarios {
            defaults.set(scenario.behavior, forKey: "split_behavior")
            let app = NewsBlurAppDelegate()
            let collection = StoriesCollection()
            collection.appDelegate = app
            collection.activeFeed = ["id": "keyboard-sidebar-fixture"]
            app.storiesCollection = collection
            let detail = DuoExpansionDetailController()
            detail.appDelegate = app
            detail.simulatesPhone = scenario.phone
            detail.isCompact = false
            let stories = DuoSidebarLayoutStories()
            stories.appDelegate = app
            detail.feedDetailViewController = stories
            app.detailViewController = detail
            let split = DuoSidebarSplitController(style: scenario.style)
            split.simulatedDisplayMode = .secondaryOnly
            app.splitViewController = split
            detail.simulatedSplitViewController = split
            detail.loadViewIfNeeded()
            let titles = UIView()
            let divider = UIView()
            detail.view.addSubview(titles)
            detail.view.addSubview(divider)
            divider.translatesAutoresizingMaskIntoConstraints = false
            let leading = divider.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor)
            leading.isActive = true
            detail.leftContainerView = titles
            detail.verticalDividerView = divider
            detail.verticalDividerViewLeadingConstraint = leading
            titles.isHidden = true
            titles.alpha = 0
            divider.isHidden = true
            divider.alpha = 0
            XCTAssertTrue(detail.areStoryTitlesCollapsed)

            // LoginViewControllerTests.swift invokes the real Right Arrow route without asking UIKit to perform an invalid column request.
            UIView.performWithoutAnimation { stories.showStoryTitlesSidebar(nil) }

            let expectedColumns: [UISplitViewController.Column] = scenario.style == .tripleColumn ? [.supplementary] : []
            XCTAssertEqual(split.shownColumns, expectedColumns,
                           "Double-column readers must reveal embedded titles; supplementary exists only in triple-column splits")
            XCTAssertTrue(split.hiddenColumns.isEmpty)
            XCTAssertFalse(detail.areStoryTitlesCollapsed)
            XCTAssertFalse(titles.isHidden)
            XCTAssertEqual(titles.alpha, 1)
            XCTAssertEqual(leading.constant, detail.verticalDividerPosition)
            XCTAssertEqual(detail.fullscreenSidebarPresentation, .storyTitles)
        }
    }

    func test_tiledFeedSidebarPairsWithTitlesAndRestoresItsRetainedReaderWhenDismissed() {
        let defaults = UserDefaults.standard
        let behavior = defaults.object(forKey: "split_behavior")
        let positionKey = "tiled-sidebar-fixture:story_titles_position"
        let position = defaults.object(forKey: positionKey)
        defaults.set("auto", forKey: "split_behavior")
        defaults.set("titles_on_left", forKey: positionKey)
        defer {
            defaults.set(behavior, forKey: "split_behavior")
            defaults.set(position, forKey: positionKey)
        }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.storiesCollection.activeFeed = ["id": "tiled-sidebar-fixture"]
        app.activeStory = ["story_hash": "tiled-sidebar-fixture:article"]
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        let stories = DuoSidebarLayoutStories()
        detail.feedDetailViewController = stories
        app.detailViewController = detail
        let split = DuoSidebarSplitController(style: .doubleColumn)
        app.splitViewController = split
        detail.loadViewIfNeeded()
        let titles = UIView()
        let divider = UIView()
        let article = UIView()
        for child in [titles, divider, article] {
            child.translatesAutoresizingMaskIntoConstraints = false
            detail.view.addSubview(child)
        }
        detail.leftContainerView = titles
        detail.verticalDividerView = divider
        detail.topContainerView = article
        let titleWidth = detail.verticalDividerPosition
        let leading = divider.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor, constant: titleWidth)
        detail.verticalDividerViewLeadingConstraint = leading
        NSLayoutConstraint.activate([
            leading, titles.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor),
            titles.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 5),
            article.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: -4),
            article.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor)
        ] + [titles, divider, article].flatMap { child in [
            child.topAnchor.constraint(equalTo: detail.view.topAnchor),
            child.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor)
        ] })
        detail.view.layoutIfNeeded()
        let originalReaderWidth = article.bounds.width

        for (behavior, keyboard) in [("auto", false), ("auto", true), ("overlay", false), ("overlay", true)] {
            defaults.set(behavior, forKey: "split_behavior")
            if keyboard { app.activeStory = nil }
            split.simulatedDisplayMode = .oneBesideSecondary
            detail.syncFullscreenSidebarPresentation(for: .oneBesideSecondary)
            detail.view.frame.size.width = 644
            detail.updateResolvedFeedSidebarLayout()
            detail.view.layoutIfNeeded()
            XCTAssertFalse(titles.isHidden, "Feeds must remain beside the source's story-title list")
            XCTAssertTrue(article.isHidden, "The retained article must not replace the story-title list beside Feeds")
            XCTAssertTrue(divider.isHidden)
            XCTAssertEqual(titles.bounds.width, detail.view.safeAreaLayoutGuide.layoutFrame.width, accuracy: 0.5)
            XCTAssertEqual(article.bounds.width, originalReaderWidth, accuracy: 0.5,
                           "Hiding the reader must preserve its document viewport")
            XCTAssertTrue(article.superview === detail.view, "The loaded reader stays mounted while source titles are shown")
            XCTAssertEqual(detail.verticalDividerPosition, titleWidth, "The fallback must not overwrite the preferred column width")
            app.activeStory = ["story_hash": "tiled-sidebar-fixture:article"]
            if keyboard {
                detail.showStoryTitlesFromKeyboard(nil)
            } else {
                detail.show(column: .secondary, animated: false)
            }
            XCTAssertEqual(split.hiddenColumns.last, .primary, "Selecting a story or returning to reading must dismiss tiled Feeds first")

            split.simulatedDisplayMode = .secondaryOnly
            // SplitViewDelegate.swift reports the new mode before the still-collapsed title constraints have been restored.
            detail.syncFullscreenSidebarPresentation(for: .secondaryOnly)
            detail.view.frame.size.width = 951
            var lastBoundCollapsedState: Bool?
            var checkedRestoredLayout = false
            stories.sidebarUpdated = { lastBoundCollapsedState = detail.areStoryTitlesCollapsed }
            let root = detail.view as! DuoSidebarLayoutView
            root.didLayout = {
                guard leading.constant == titleWidth else { return }
                checkedRestoredLayout = true
                XCTAssertEqual(lastBoundCollapsedState, false,
                               "The next Sidebar tap must target Feeds before restored title frames become visible")
            }
            UIView.performWithoutAnimation { detail.updateResolvedFeedSidebarLayout() }
            detail.view.layoutIfNeeded()
            root.didLayout = nil
            stories.sidebarUpdated = nil
            XCTAssertTrue(checkedRestoredLayout, "The control binding must be checked during the real constraint restoration")
            XCTAssertFalse(titles.isHidden)
            XCTAssertFalse(article.isHidden)
            XCTAssertFalse(divider.isHidden)
            XCTAssertEqual(detail.fullscreenSidebarPresentation, .storyTitles,
                           "The explicit \(keyboard ? "keyboard" : "button") reveal must survive \(behavior) sidebar dismissal")
            XCTAssertEqual(leading.constant, titleWidth)
            XCTAssertEqual(article.bounds.width, originalReaderWidth, accuracy: 0.5)
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, "tiled-sidebar-fixture:article")
        }
    }

    func test_discoveryRoundTripRestoresTheReaderHiddenByTiledFeeds() {
        let defaults = UserDefaults.standard
        let behavior = defaults.object(forKey: "split_behavior")
        let positionKey = "tiled-discovery-fixture:story_titles_position"
        let position = defaults.object(forKey: positionKey)
        defaults.set("auto", forKey: "split_behavior")
        defaults.set("titles_on_left", forKey: positionKey)
        defer {
            defaults.set(behavior, forKey: "split_behavior")
            defaults.set(position, forKey: positionKey)
        }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.appDelegate = app
        app.storiesCollection.activeFeed = ["id": "tiled-discovery-fixture"]
        app.activeStory = ["story_hash": "tiled-discovery-fixture:article"]
        app.feedsNavigationController = UINavigationController()
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        detail.feedDetailViewController = DuoSidebarLayoutStories()
        app.detailViewController = detail
        let split = DuoSidebarSplitController(style: .doubleColumn)
        app.splitViewController = split
        detail.loadViewIfNeeded()
        let titles = UIView()
        let divider = UIView()
        let article = UIView()
        for child in [titles, divider, article] {
            child.translatesAutoresizingMaskIntoConstraints = false
            detail.view.addSubview(child)
        }
        detail.leftContainerView = titles
        detail.verticalDividerView = divider
        detail.topContainerView = article
        let leading = divider.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor, constant: detail.verticalDividerPosition)
        detail.verticalDividerViewLeadingConstraint = leading
        NSLayoutConstraint.activate([
            leading, titles.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor),
            titles.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 5),
            article.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: -4),
            article.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor)
        ] + [titles, divider, article].flatMap { child in [
            child.topAnchor.constraint(equalTo: detail.view.topAnchor),
            child.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor)
        ] })
        detail.view.layoutIfNeeded()
        let readerWidth = article.bounds.width
        let retainedArticle = UIScrollView(frame: article.bounds)
        retainedArticle.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        retainedArticle.contentSize = CGSize(width: readerWidth, height: 3000)
        retainedArticle.contentOffset.y = 320
        article.addSubview(retainedArticle)
        split.simulatedDisplayMode = .oneBesideSecondary
        detail.syncFullscreenSidebarPresentation(for: .oneBesideSecondary)
        detail.view.frame.size.width = 644
        detail.updateResolvedFeedSidebarLayout()
        XCTAssertTrue(article.isHidden)

        detail.showDiscoverSites(DiscoveryTransitionTestController())
        XCTAssertTrue(detail.isDiscoverSitesVisible)
        detail.updateResolvedFeedSidebarLayout()
        XCTAssertTrue(article.isHidden, "Restoring temporary tiled constraints must not uncover the reader behind Discover")

        // LoginViewControllerTests.swift exercises real discovery unmounting without bootstrapping unrelated account-backed reader controllers.
        detail.topContainerView = nil
        detail.dismissDiscoverSites()
        detail.topContainerView = article
        split.simulatedDisplayMode = .secondaryOnly
        detail.syncFullscreenSidebarPresentation(for: .secondaryOnly)
        detail.view.frame.size.width = 951
        UIView.performWithoutAnimation { detail.updateResolvedFeedSidebarLayout() }
        detail.view.layoutIfNeeded()

        XCTAssertFalse(detail.isDiscoverSitesVisible)
        XCTAssertFalse(article.isHidden, "Discover must restore the reader's pre-tile visibility, not the temporary hidden state")
        XCTAssertTrue(retainedArticle.superview === article)
        XCTAssertTrue(article.superview === detail.view)
        XCTAssertEqual(article.bounds.width, readerWidth, accuracy: 0.5)
        XCTAssertEqual(retainedArticle.contentOffset.y, 320, accuracy: 0.5)
        XCTAssertEqual(app.activeStory?["story_hash"] as? String, "tiled-discovery-fixture:article")
    }

    func test_phoneExpansionPreservesTheVisibleFeedListBeforeReparentingTheCompactStack() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "split_behavior")
        defer { defaults.set(original, forKey: "split_behavior") }
        defaults.set("auto", forKey: "split_behavior")
        for phone in [true, false] {
            for showingFeeds in [true, false] {
                let app = NewsBlurAppDelegate()
                app.storiesCollection = StoriesCollection()
                // LoginViewControllerTests.swift retains a previous feed selection while checking the actually visible compact screen.
                app.storiesCollection.activeFeed = ["id": 1, "feed_title": "Previously selected feed"]
                let detail = DuoExpansionDetailController()
                detail.simulatesPhone = phone
                detail.appDelegate = app
                detail.isCompact = true
                app.detailViewController = detail
                let feeds = FeedsViewController()
                app.feedsViewController = feeds
                let primary = UINavigationController(rootViewController: feeds)
                if !showingFeeds { primary.setViewControllers([feeds, UIViewController()], animated: false) }
                app.feedsNavigationController = primary
                let split = DuoSidebarSplitController(style: .doubleColumn)
                app.splitViewController = split
                split.setViewController(primary, for: .primary)
                split.setViewController(UINavigationController(rootViewController: detail), for: .secondary)

                let mode = SplitViewDelegate().splitViewController(split, displayModeForExpandingToProposedDisplayMode: .twoBesideSecondary)

                XCTAssertFalse(detail.isCompact)
                XCTAssertTrue(primary.topViewController === feeds)
                let expected: UISplitViewController.DisplayMode = phone ?
                    (showingFeeds ? .oneBesideSecondary : .secondaryOnly) : .twoBesideSecondary
                XCTAssertEqual(mode, expected,
                               "Expansion must retain the visible source without restoring three tiled phone columns or changing iPad policy")
            }
        }
    }

    func test_regularReaderContainerEndsAtItsHostWhenTheHorizontalDividerIsHidden() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared)
        let detail = try XCTUnwrap(app.detailViewController)
        guard !detail.isPhoneOrCompact, detail.storyTitlesOnLeft else {
            throw XCTSkip("This regression checks the real regular-width storyboard containment")
        }
        detail.checkLayout()
        detail.view.setNeedsLayout()
        detail.view.layoutIfNeeded()
        let container = try XCTUnwrap(detail.topContainerView)
        let divider = try XCTUnwrap(detail.horizontalDividerView)
        let readerFrame = container.convert(container.bounds, to: detail.view)
        let dividerFrame = divider.convert(divider.bounds, to: detail.view)
        XCTAssertEqual(readerFrame.maxY, detail.view.bounds.maxY, accuracy: 0.5,
                       "Hiding MainInterface.storyboard's divider must not extend the reader seven points below its host")
        XCTAssertGreaterThanOrEqual(dividerFrame.minY, detail.view.bounds.maxY,
                                    "The unused horizontal divider must remain outside the visible reader")
    }

    func test_expandedArticleTopDoesNotFollowTheStoryTitleHeadersSafeArea() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared)
        let detail = try XCTUnwrap(app.detailViewController)
        let split = try XCTUnwrap(app.splitViewController)
        guard detail.isPhone, !detail.isPhoneOrCompact, detail.storyTitlesOnLeft else {
            throw XCTSkip("This regression checks expanded Duo's real storyboard columns")
        }
        let originalInsets = detail.additionalSafeAreaInsets
        let wasShowingFeeds = !split.isFeedsListHidden
        defer {
            detail.additionalSafeAreaInsets = originalInsets
            detail.view.setNeedsLayout()
            detail.view.window?.layoutIfNeeded()
            if wasShowingFeeds { detail.show(column: .primary, animated: false) }
        }
        split.hide(.primary)
        let deadline = Date().addingTimeInterval(5)
        while (!split.isFeedsListHidden || split.transitionCoordinator != nil) && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(split.isFeedsListHidden)
        detail.checkLayout()
        let window = try XCTUnwrap(detail.view.window)
        let titles = try XCTUnwrap(detail.leftContainerView)
        let reader = try XCTUnwrap(detail.topContainerView)
        let protectedTop = window.bounds.minY + window.safeAreaInsets.top

        for headerInset in [CGFloat(0), 58, 0, 32, 0] {
            // LoginViewControllerTests.swift varies the actual shared safe area that native title minimization changes.
            var insets = originalInsets
            insets.top += headerInset
            detail.additionalSafeAreaInsets = insets
            detail.view.setNeedsLayout()
            window.layoutIfNeeded()
            let titleTop = titles.convert(titles.bounds, to: window).minY
            let readerTop = reader.convert(reader.bounds, to: window).minY
            let sharedSafeTop = detail.view.convert(detail.view.safeAreaLayoutGuide.layoutFrame, to: window).minY
            XCTAssertEqual(titleTop, sharedSafeTop, accuracy: 1,
                           "The left story list retains its own native header protection")
            XCTAssertEqual(readerTop, protectedTop, accuracy: 1,
                           "Changing the left header must not move the right article or leave a shared top band")
            print("DUO_INDEPENDENT_HEADER_GEOMETRY inset=\(headerInset) safe=\(sharedSafeTop) titles=\(titleTop) reader=\(readerTop) protected=\(protectedTop)")
        }
    }

    func test_expandedPhoneSidebarToggleUsesThePrimaryColumnInBothDirections() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "split_behavior")
        defer { defaults.set(original, forKey: "split_behavior") }
        defaults.set("auto", forKey: "split_behavior")
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DiscoveryTransitionPhoneDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let split = DuoSidebarSplitController(style: .doubleColumn)
        split.view.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
        app.splitViewController = split
        let source = BaseViewController()
        source.appDelegate = app

        source.toggleFeeds(nil)
        XCTAssertEqual(split.shownColumns, [.primary])
        XCTAssertEqual(split.preferredSplitBehavior, .overlay)
        split.simulatedDisplayMode = .oneOverSecondary
        source.toggleFeeds(nil)
        XCTAssertEqual(split.hiddenColumns, [.primary])
        split.simulatedDisplayMode = .secondaryOnly
        source.toggleFeeds(nil)
        XCTAssertEqual(split.shownColumns, [.primary, .primary], "The feed list must remain reopenable after hiding")
    }

    func test_feedSidebarVisibilityDistinguishesPrimaryFromSupplementaryOverlay() {
        let double = DuoSidebarSplitController(style: .doubleColumn)
        double.simulatedDisplayMode = .oneOverSecondary
        XCTAssertFalse(double.isFeedsListHidden, "The only sidebar in a double-column split is the feed list")
        let triple = DuoSidebarSplitController(style: .tripleColumn)
        triple.simulatedDisplayMode = .oneOverSecondary
        XCTAssertTrue(triple.isFeedsListHidden, "A supplementary overlay in a triple-column split does not show feeds")
        triple.simulatedDisplayMode = .oneBesideSecondary
        XCTAssertTrue(triple.isFeedsListHidden)
        triple.simulatedDisplayMode = .twoOverSecondary
        XCTAssertFalse(triple.isFeedsListHidden)
    }

    func test_phoneSplitTransitionsUseTheResolvedLayoutBeforeTraitsCatchUp() {
        let detail = DiscoveryTransitionPhoneDetailController()
        let stories = FeedDetailViewController()
        let pages = StoryPagesViewController()
        detail.feedDetailViewController = stories
        detail.storyPagesViewController = pages
        detail.traitOverrides.horizontalSizeClass = .compact
        XCTAssertTrue(detail.isPhoneOrCompact)
        XCTAssertTrue(detail.feedDetailNavigationItem === stories.navigationItem)
        XCTAssertTrue(detail.storiesNavigationItem === pages.navigationItem)

        // LoginViewControllerTests.swift models the split delegate expanding before UIKit updates child traits.
        detail.isCompact = false
        XCTAssertFalse(detail.isPhoneOrCompact)
        XCTAssertTrue(detail.feedDetailNavigationItem === detail.navigationItem)
        XCTAssertTrue(detail.storiesNavigationItem === detail.navigationItem)
        detail.traitOverrides.horizontalSizeClass = .regular
        detail.isCompact = true
        XCTAssertTrue(detail.isPhoneOrCompact)
        XCTAssertTrue(detail.feedDetailNavigationItem === stories.navigationItem)
        XCTAssertTrue(detail.storiesNavigationItem === pages.navigationItem)
        detail.isCompact = false
        XCTAssertFalse(detail.isPhoneOrCompact)
    }

    func test_expandedPhoneFeedSelectionKeepsTheSplitReaderVisible() {
        let app = DuoFeedSelectionApp()
        let detail = DiscoveryTransitionPhoneDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        app.feedsNavigationController = UINavigationController()

        app.perform(Selector(("presentFeedDetailAfterFeedSelection")))

        XCTAssertEqual(app.readerLoads, 1)
        XCTAssertEqual(app.feedsPresentations, 0, "Expanded Duo should load stories without resetting compact navigation")
    }

    func test_tryFeedEntryPointKeepsDiscoveryBelowReader() {
        let app = DiscoverPreviewNavigationApp()
        let stories = StoriesCollection()
        app.storiesCollection = stories
        app.dictFeeds = NSMutableDictionary(dictionary: ["1": ["id": 1, "feed_title": "Preview Feed"]])
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let feeds = FeedsViewController()
        let discovery = DiscoveryTransitionTestController()
        let reader = FeedDetailViewController()
        reader.appDelegate = app
        detail.feedDetailViewController = reader
        let navigation = UINavigationController()
        app.feedsNavigationController = navigation
        app.feedsViewController = feeds
        navigation.setViewControllers([feeds, discovery], animated: false)

        app.loadTryFeedDetailView("1", withStory: nil, isSocial: false, withUser: nil, showFindingStory: false)

        XCTAssertEqual(app.readerLoads, 1)
        XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), [feeds, discovery, reader].map(ObjectIdentifier.init))
        navigation.popViewController(animated: false)
        XCTAssertTrue(navigation.topViewController === discovery)
    }

    func test_discoverySurvivesExpansionAndCompactReaderRestoration() throws {
        for (includesDiscovery, phone) in [(false, false), (true, false), (false, true), (true, true)] {
            let app = NewsBlurAppDelegate()
            let stories = StoriesCollection()
            stories.activeFeed = ["id": 1, "feed_title": "Preview Feed"]
            app.storiesCollection = stories
            let detail: DetailViewController = phone
                ? DiscoveryTransitionPhoneDetailController()
                : DiscoveryTransitionPadDetailController()
            detail.appDelegate = app
            detail.isCompact = true
            XCTAssertTrue(detail.isPhoneOrCompact)
            app.detailViewController = detail
            let feeds = FeedsViewController()
            let discovery = DiscoveryTransitionTestController()
            discovery.initialTab = .reddit
            let reader = try XCTUnwrap(
                UIStoryboard(name: "MainInterface", bundle: nil)
                    .instantiateViewController(withIdentifier: "FeedDetailViewController") as? FeedDetailViewController
            )
            reader.appDelegate = app
            reader.storiesCollection = stories
            detail.feedDetailViewController = reader
            let navigation = UINavigationController()
            app.feedsNavigationController = navigation
            app.feedsViewController = feeds
            let prefix: [UIViewController] = includesDiscovery ? [feeds, discovery] : [feeds]
            navigation.setViewControllers([feeds], animated: false)
            if includesDiscovery {
                // LoginViewControllerTests.swift uses the same retained discovery ownership as the Try action.
                detail.showDiscoverSites(discovery)
                detail.beginDiscoverPreview()
            }
            navigation.setViewControllers(prefix + [reader], animated: false)

            detail.expandToTwoColumns()

            XCTAssertFalse(detail.isPhoneOrCompact)
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), [ObjectIdentifier(feeds)])
            XCTAssertEqual(detail.canReturnToDiscoverSites, includesDiscovery)
            XCTAssertFalse(detail.isDiscoverSitesVisible)
            detail.collapseToSingleColumn()
            XCTAssertTrue(detail.isPhoneOrCompact)
            detail.restoreCompactNavigationAfterSplitCollapse(showFeed: true, showStory: false)
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), (prefix + [reader]).map(ObjectIdentifier.init))
            navigation.popViewController(animated: false)
            XCTAssertTrue(navigation.topViewController === prefix.last)
            XCTAssertEqual(discovery.initialTab, .reddit)
        }
    }

    func test_compactPreviewPreservesDiscoveryAndAvoidsDuplicateReaderControllers() {
        for showStory in [false, true] {
            let app = NewsBlurAppDelegate()
            let stories = StoriesCollection()
            stories.activeFeed = ["id": 1, "feed_title": "Preview Feed"]
            app.storiesCollection = stories
            app.activeStory = showStory ? ["story_hash": "preview:story"] : nil
            let detail = DetailViewController()
            detail.appDelegate = app
            detail.isCompact = true
            app.detailViewController = detail
            let feeds = FeedsViewController()
            let discovery = UIViewController()
            let reader = FeedDetailViewController()
            reader.appDelegate = app
            let pages = StoryPagesViewController()
            pages.appDelegate = app
            detail.feedDetailViewController = reader
            detail.storyPagesViewController = pages
            let navigation = UINavigationController()
            app.feedsNavigationController = navigation
            app.feedsViewController = feeds
            navigation.setViewControllers([feeds, discovery], animated: false)

            detail.show(column: .secondary, animated: false)
            detail.show(column: .secondary, animated: false)

            let expected: [UIViewController] = showStory ? [feeds, discovery, reader, pages] : [feeds, discovery, reader]
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), expected.map(ObjectIdentifier.init))
            if showStory { navigation.popViewController(animated: false) }
            navigation.popViewController(animated: false)
            XCTAssertTrue(navigation.topViewController === discovery)
        }
    }

    func test_collapseToSingleColumnDoesNotRequireLoadedView() throws {
        let detailController = try XCTUnwrap(
            UIStoryboard(name: "MainInterface", bundle: nil)
                .instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController
        )

        XCTAssertFalse(detailController.isViewLoaded)

        detailController.collapseToSingleColumn()

        XCTAssertFalse(detailController.isViewLoaded)
    }

    func test_showSecondaryInCompactRemovesStaleStoryPagesWhenNoStoryIsSelected() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection
        appDelegate.activeStory = nil

        let detailController = DetailViewController()
        detailController.appDelegate = appDelegate
        detailController.isCompact = true
        appDelegate.detailViewController = detailController

        let feedsViewController = FeedsViewController()
        let feedDetailViewController = FeedDetailViewController()
        let storyPagesViewController = StoryPagesViewController()
        feedDetailViewController.appDelegate = appDelegate
        storyPagesViewController.appDelegate = appDelegate
        storyPagesViewController.loadViewIfNeeded()
        storyPagesViewController.currentPage.clearStory()
        storyPagesViewController.currentPage.view.isHidden = true

        detailController.feedDetailViewController = feedDetailViewController
        detailController.storyPagesViewController = storyPagesViewController

        let navigationController = UINavigationController()
        appDelegate.feedsNavigationController = navigationController
        appDelegate.feedsViewController = feedsViewController
        navigationController.setViewControllers(
            [feedsViewController, feedDetailViewController, storyPagesViewController],
            animated: false
        )

        detailController.show(column: .secondary, animated: false)

        XCTAssertEqual(navigationController.viewControllers.count, 2)
        XCTAssertTrue(navigationController.viewControllers[0] === feedsViewController)
        XCTAssertTrue(navigationController.viewControllers[1] === feedDetailViewController)
    }

    func test_appDelegateUpdatesCompactFeedDetailTitleItem() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection

        let detailController = DetailViewController()
        let feedDetailViewController = FeedDetailViewController()
        detailController.appDelegate = appDelegate
        detailController.feedDetailViewController = feedDetailViewController
        feedDetailViewController.appDelegate = appDelegate
        appDelegate.detailViewController = detailController

        appDelegate.perform(Selector(("updateFeedDetailTitleView")))

        XCTAssertNotNil(detailController.navigationItem.titleView)
        XCTAssertNotNil(feedDetailViewController.navigationItem.titleView)
    }

    func test_resetFeedDetailClearsVisibleStoryRowsImmediately() throws {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.appDelegate = appDelegate
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection
        appDelegate.unreadStoryHashes = NSMutableDictionary()
        appDelegate.recentlyReadStories = NSMutableDictionary()

        let detailController = DetailViewController()
        detailController.appDelegate = appDelegate
        detailController.isCompact = true
        appDelegate.detailViewController = detailController

        let storyPagesViewController = StoryPagesViewController()
        storyPagesViewController.appDelegate = appDelegate
        storyPagesViewController.loadViewIfNeeded()
        detailController.storyPagesViewController = storyPagesViewController

        let feedDetailViewController = try XCTUnwrap(
            UIStoryboard(name: "MainInterface", bundle: nil)
                .instantiateViewController(withIdentifier: "FeedDetailViewController") as? FeedDetailViewController
        )
        feedDetailViewController.appDelegate = appDelegate
        feedDetailViewController.storiesCollection = storiesCollection
        detailController.feedDetailViewController = feedDetailViewController
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.messageView.isHidden = true

        storiesCollection.setStories([
            [
                "story_hash": "old:story",
                "story_title": "Old story",
                "read_status": 0,
                "intelligence": [:],
            ],
        ])
        feedDetailViewController.reloadImmediately()
        XCTAssertGreaterThan(feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0), 1)

        feedDetailViewController.resetFeedDetail()

        XCTAssertLessThanOrEqual(feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0), 1)
    }
}

@MainActor private final class DiscoveryTransitionPadDetailController: DetailViewController {
    // LoginViewControllerTests.swift exercises iPad expansion even when the test host is an iPhone.
    override var isPhone: Bool { false }
}

@MainActor private final class ConventionalLandscapePhoneDetailController: DetailViewController {
    override var isPhone: Bool { true }
    override var traitCollection: UITraitCollection {
        // LoginViewControllerTests.swift supplies ordinary phone traits without inheriting the Duo simulator's native vertical-bar trait.
        UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: .phone),
                                      UITraitCollection(horizontalSizeClass: .regular),
                                      UITraitCollection(verticalSizeClass: .compact)])
    }
}

@MainActor private class DuoRegularHeightDetailController: DetailViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // LoginViewControllerTests.swift keeps synthetic Duo inner-display fixtures independent of the test device's orientation.
        traitOverrides.verticalSizeClass = .regular
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        traitOverrides.verticalSizeClass = .regular
    }
}

@MainActor private final class DiscoveryTransitionPhoneDetailController: DuoRegularHeightDetailController {
    override var isPhone: Bool { true }
}

@MainActor private final class DuoSidebarSplitController: SplitViewController {
    var simulatedDisplayMode: UISplitViewController.DisplayMode = .secondaryOnly
    var shownColumns: [UISplitViewController.Column] = []
    var hiddenColumns: [UISplitViewController.Column] = []
    override var displayMode: UISplitViewController.DisplayMode { simulatedDisplayMode }
    // LoginViewControllerTests.swift checks native column operations without requiring a live fold transition.
    override func show(_ column: UISplitViewController.Column) { shownColumns.append(column) }
    override func hide(_ column: UISplitViewController.Column) { hiddenColumns.append(column) }
}

@MainActor private final class DuoSidebarLayoutStories: FeedDetailViewController {
    var sidebarUpdated: (() -> Void)?
    // LoginViewControllerTests.swift isolates the column constraints from the singleton's live navigation controls.
    override func updateSidebarButton(for displayMode: UISplitViewController.DisplayMode) { sidebarUpdated?() }
}

@MainActor private final class DuoSidebarLayoutView: UIView {
    var didLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        didLayout?()
    }
}

@MainActor private final class DuoExpansionDetailController: DuoRegularHeightDetailController {
    var simulatesPhone = true
    var simulatesDiscovery: Bool?
    weak var simulatedSplitViewController: UISplitViewController?
    override var isPhone: Bool { simulatesPhone }
    override var splitViewController: UISplitViewController? { simulatedSplitViewController ?? super.splitViewController }
    override var isDiscoverSitesVisible: Bool { simulatesDiscovery ?? super.isDiscoverSitesVisible }
    override func loadView() { view = DuoSidebarLayoutView(frame: CGRect(x: 0, y: 0, width: 951, height: 669)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    // LoginViewControllerTests.swift exercises SplitViewDelegate.swift's routing before the compact stack is dismantled.
    override func expandToTwoColumns() {
        isCompact = false
        appDelegate.feedsNavigationController.popToRootViewController(animated: false)
    }
    override func resetStoryTitlesRevealOverride() {}
    override func collapseFeedListIfNeededForStory() {}
}

@MainActor private final class DuoFeedReturnSplitController: SplitViewController {
    var simulatedCollapsed = false
    override var isCollapsed: Bool { simulatedCollapsed }
}

@MainActor private final class DuoBrowserRoutingApp: NewsBlurAppDelegate {
    var presentedBrowsers: [UIViewController] = []
    var browserAnchor: UIBarButtonItem?
    override var isPhone: Bool { true }
    override var url: String! { "https://newsblur.com" }
    override func showPopover(with viewController: UIViewController!, contentSize: CGSize, barButtonItem: UIBarButtonItem!) {
        presentedBrowsers.append(viewController)
        browserAnchor = barButtonItem
    }
}

@MainActor private final class DuoBrowserRoutingNavigationController: UINavigationController {
    var shownControllers: [UIViewController] = []
    override func show(_ vc: UIViewController, sender: Any?) { shownControllers.append(vc) }
}

@MainActor private final class DuoBrowserRoutingController: OriginalStoryViewController {
    var loadRequests = 0
    var dismissals = 0
    weak var simulatedPresenter: UIViewController?
    override var presentingViewController: UIViewController? { simulatedPresenter }
    override func loadView() { view = UIView() }
    override func viewDidLoad() {}
    // LoginViewControllerTests.swift checks routing without loading Statistics or article network content.
    override func loadInitialStory() { loadRequests += 1 }
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1
        completion?()
    }
}

@MainActor private final class DuoBrowserDismissalNavigationController: UINavigationController {
    var simulatedControllers: [UIViewController] = []
    var popTargets: [UIViewController] = []
    override var viewControllers: [UIViewController] {
        get { simulatedControllers }
        set { simulatedControllers = newValue }
    }
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        popTargets.append(viewController)
        return nil
    }
}

@MainActor private final class DuoFeedReturnNavigationController: UINavigationController {
    var popAnimations: [Bool] = []
    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        popAnimations.append(animated)
        return nil
    }
}

@MainActor private final class DuoFeedReturnApp: NewsBlurAppDelegate {
    var shownColumns: [UISplitViewController.Column] = []
    var columnAnimations: [Bool] = []
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {
        shownColumns.append(column)
        columnAnimations.append(animated)
    }
}

@MainActor private final class DuoTrainerAnchorPages: StoryPagesViewController {
    var simulatedVerticalToolbar = false
    override var usesVerticalReaderToolbar: Bool { simulatedVerticalToolbar }
}

@MainActor private final class DuoTrainerAnchorApp: NewsBlurAppDelegate {
    var trainerAnchor: AnyObject?
    override func openTrainStory(_ sender: Any!) {
        trainerAnchor = sender as AnyObject?
    }
}

@MainActor private final class DuoFeedSelectionApp: NewsBlurAppDelegate {
    var readerLoads = 0
    var feedsPresentations = 0
    override var isPhone: Bool { true }
    // LoginViewControllerTests.swift records presentation decisions without loading account data.
    override func loadFeedDetailView() { readerLoads += 1 }
    override func showFeedsList(animated: Bool) { feedsPresentations += 1 }
    override func hidePopover(animated: Bool, completion: (() -> Void)!) { completion?() }
}

@available(iOS 15.0, *)
private final class DiscoveryTransitionTestController: DiscoverSitesViewController {
    // LoginViewControllerTests.swift exercises navigation ownership without starting discovery network requests.
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
}

@MainActor private final class DiscoverPreviewNavigationApp: NewsBlurAppDelegate {
    var readerLoads = 0
    override var isPhone: Bool { true }
    // LoginViewControllerTests.swift exercises the real preview entry point and navigation without fetching stories.
    override func loadFeedDetailView() {
        readerLoads += 1
        detailViewController.show(column: .secondary, animated: false)
    }
}

@available(iOS 15.0, *)
@MainActor
final class StoryPagesViewControllerTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let horizontalPagingKey = "scroll_stories_horizontally"
    private var savedHorizontalPagingValue: Any?

    override func setUp() {
        super.setUp()

        savedHorizontalPagingValue = defaults.object(forKey: horizontalPagingKey)
        defaults.set(true, forKey: horizontalPagingKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: horizontalPagingKey)
        if let savedHorizontalPagingValue {
            defaults.set(savedHorizontalPagingValue, forKey: horizontalPagingKey)
        }

        savedHorizontalPagingValue = nil
        super.tearDown()
    }

    func test_readerKeyboardCommandsResolveAndForwardToTheCurrentArticle() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared)
        let registeredPages = try XCTUnwrap(app.storyPagesViewController)
        registeredPages.loadViewIfNeeded()
        let commands = try XCTUnwrap(registeredPages.keyCommands)
        XCTAssertFalse(commands.isEmpty)
        for command in commands {
            let action = try XCTUnwrap(command.action)
            XCTAssertTrue(registeredPages.responds(to: action),
                          "Registered reader command has no handler: \(NSStringFromSelector(action))")
        }

        let comments = try XCTUnwrap(commands.first { $0.input == "c" && $0.modifierFlags.isEmpty })
        let share = try XCTUnwrap(commands.first { $0.input == "s" && $0.modifierFlags == .shift })
        let commentsAction = try XCTUnwrap(comments.action)
        let shareAction = try XCTUnwrap(share.action)
        let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
        let first = DuoKeyboardArticlePage(nibName: nil, bundle: nil)
        let second = DuoKeyboardArticlePage(nibName: nil, bundle: nil)
        first.pageIndex = 0
        second.pageIndex = 1
        pages.previousPage = first
        pages.nextPage = second

        for current in [first, second] {
            pages.currentPage = current
            for command in [comments, share] {
                let action = try XCTUnwrap(command.action)
                XCTAssertTrue(pages.canPerformAction(action, withSender: command))
                // LoginViewControllerTests.swift reports a missing selector without repeating the normal-app crash.
                guard pages.responds(to: action) else {
                    XCTFail("Reader must forward \(NSStringFromSelector(action)) to its current article")
                    continue
                }
                XCTAssertTrue(UIApplication.shared.sendAction(action, to: pages, from: command, for: nil))
            }
            XCTAssertEqual(current.commentsCommands, 1)
            XCTAssertEqual(current.shareCommands, 1)
        }
        XCTAssertEqual(first.commentsCommands, 1, "Changing pages must not send commands to the outgoing article")
        XCTAssertEqual(first.shareCommands, 1)
        second.pageIndex = -1
        XCTAssertFalse(pages.canPerformAction(commentsAction, withSender: comments))
        XCTAssertFalse(pages.canPerformAction(shareAction, withSender: share))
        pages.currentPage = nil
    }

    func test_readerViewportResizesWhenLayoutChangesBeforeTheNewDocumentCommits() async throws {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let page = DuoViewportLayoutPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        let web = try XCTUnwrap(page.webView)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(page.view)
        window.isHidden = false
        defer { window.isHidden = true }

        let navigation = DuoViewportNavigationDelegate()
        web.navigationDelegate = navigation
        defer { navigation.resume() }
        let outgoingLoaded = expectation(description: "Outgoing article loaded")
        navigation.finished = { _ in outgoingLoaded.fulfill() }
        web.loadHTMLString(Self.viewportFixtureHTML, baseURL: nil)
        await fulfillment(of: [outgoingLoaded], timeout: 5)

        let incomingPaused = expectation(description: "New document waits before committing")
        let incomingLoaded = expectation(description: "New article loaded at the final native width")
        navigation.paused = { incomingPaused.fulfill() }
        navigation.finished = { incoming in
            page.webView(web, didFinish: incoming)
            incomingLoaded.fulfill()
        }
        // LoginViewControllerTests.swift holds navigation so the safe-area resize updates the outgoing document first.
        page.setValue(Self.viewportFixtureHTML, forKey: "fullStoryHTML")
        page.perform(Selector(("loadStory")))
        await fulfillment(of: [incomingPaused], timeout: 5)
        page.view.frame.size.width = 382
        web.frame = page.view.bounds
        web.layoutIfNeeded()
        page.changeWebViewWidth()
        let outgoingViewport = try await web.evaluateJavaScript("document.getElementById('viewport').content") as? String
        XCTAssertTrue(outgoingViewport?.contains("width=382,") == true)

        navigation.resume()
        await fulfillment(of: [incomingLoaded], timeout: 5)
        let layout = try await web.callAsyncJavaScript("""
            await new Promise(requestAnimationFrame);
            await new Promise(requestAnimationFrame);
            return {viewport: window.innerWidth, body: document.body.getBoundingClientRect().width,
                    story: document.getElementById('NB-story').getBoundingClientRect().width,
                    meta: document.getElementById('viewport').content};
            """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
        let metrics = try XCTUnwrap(layout)
        for key in ["viewport", "body", "story"] {
            XCTAssertEqual(try XCTUnwrap(metrics[key] as? Double), 382, accuracy: 1,
                           "The committed article must wrap within the native reader width")
        }
        XCTAssertTrue((metrics["meta"] as? String)?.contains("width=382,") == true)
    }

    private static let viewportFixtureHTML = """
        <!doctype html><html><head>
        <meta name="viewport" id="viewport" content="width=466, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no">
        <style>html,body {margin:0;padding:0} #NB-story {padding:12px;box-sizing:border-box}</style>
        </head><body><article id="NB-story">A readable article paragraph must wrap before the native toolbar.
        Its final words must remain visible when the available reading width changes during navigation.</article></body></html>
        """

    func test_nativeReaderTopInsetUsesOnlyTheWindowsRemainingProtectedArea() {
        let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
        pages.simulatedVerticalToolbar = true
        let readerView = DuoReaderSafeAreaView(frame: CGRect(x: 0, y: 0, width: 382, height: 678))
        pages.view = readerView
        let window = DuoReaderSafeAreaWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        window.addSubview(readerView)

        // LoginViewControllerTests.swift separates navigation-container spacing from real window protection.
        let cases: [(protectedTop: CGFloat, readerOrigin: CGFloat, expected: CGFloat)] = [
            (0, 0, 0), (59, 0, 59), (59, 20, 39), (59, 70, 0)
        ]
        for test in cases {
            window.protectedTop = test.protectedTop
            readerView.frame.origin.y = test.readerOrigin
            for alpha in [CGFloat(0), 1] {
                XCTAssertEqual(pages.topInset(forNavigationBarAlpha: alpha), test.expected, accuracy: 0.5,
                               "A side navigation bar must not add a phantom horizontal obstruction")
            }
        }

        readerView.removeFromSuperview()
        XCTAssertNil(readerView.window)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 1), 24,
                       "Detached readers retain their local safe-area fallback until a window is available")
    }

    func test_nativeReaderFeedHeaderPinsReadingAndFollowsRestoredTopOverscroll() {
        let app = NewsBlurAppDelegate()
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let pages = DuoTrainerAnchorPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        pages.simulatedVerticalToolbar = true
        detail.storyPagesViewController = pages
        let page = DuoGradientLayoutPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        pages.currentPage = page
        let web = page.webView!
        let gradient = UIView(frame: CGRect(x: 0, y: 22, width: 360, height: 25))
        page.feedTitleGradient = gradient
        web.addSubview(gradient)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.contentSize = CGSize(width: 360, height: 2_000)

        // LoginViewControllerTests.swift preserves sticky header positioning through saved-position and layout restoration, including a top pull.
        let poses = [(vertical: true, compact: true), (vertical: true, compact: false),
                     (vertical: false, compact: false)]
        for pose in poses {
            detail.isCompact = pose.compact
            pages.simulatedVerticalToolbar = pose.vertical
            for protectedTop in [CGFloat(0), 22, 59] {
                web.scrollView.contentInset.top = protectedTop
                for offset in [-protectedTop, 120, 320, -protectedTop - 30] {
                    web.scrollView.contentOffset.y = offset
                    page.updateFeedTitleGradientPosition()
                    XCTAssertEqual(gradient.frame.minY, max(protectedTop, -offset), accuracy: 0.5,
                                   "Restoration must pin the feed header during reading and follow the page during a top pull: \(pose)")
                    XCTAssertEqual(gradient.frame.height, 25, accuracy: 0.5)
                    XCTAssertEqual(web.scrollView.contentInset.top, protectedTop,
                                   "Restoring the header must not introduce extra blank space above the article")
                }
            }
        }
    }

    func test_nativeReaderRevealedFeedHeaderDoesNotRevealArticleText() throws {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.isRiverView = true
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let pages = DuoTrainerAnchorPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        pages.simulatedVerticalToolbar = true
        detail.storyPagesViewController = pages
        let page = DuoGradientLayoutPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        pages.currentPage = page
        let gradient = try XCTUnwrap(app.makeFeedTitleGradient([
            "id": "1", "feed_title": "Example feed", "favicon_fade": "808080",
            "favicon_color": "505050", "favicon_border": "303030", "favicon_text_color": "white"
        ], with: CGRect(x: 0, y: 0, width: 360, height: 25)))
        page.feedTitleGradient = gradient
        page.webView.addSubview(gradient)
        page.webView.scrollView.contentOffset.y = 300
        // LoginViewControllerTests.swift samples an unlabelled header pixel; UIView.isOpaque alone does not prevent article bleed-through.
        for vertical in [true, false, true] {
            pages.simulatedVerticalToolbar = vertical
            page.updateFeedTitleGradientPosition()
            var pixel = [UInt8](repeating: 0, count: 4)
            let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: -350, y: -12)
            gradient.layer.render(in: context)
            XCTAssertEqual(pixel[3], 255,
                           "The expanded phone header must cover scrolling text with either toolbar orientation, vertical=\(vertical)")
        }

        // LoginViewControllerTests.swift preserves legacy horizontal compact-phone and iPad rendering after leaving the expanded reader.
        for legacy in [(phone: true, compact: true), (phone: false, compact: false)] {
            pages.simulatedVerticalToolbar = false
            detail.simulatesPhone = legacy.phone
            detail.isCompact = legacy.compact
            page.updateFeedTitleGradientPosition()
            XCTAssertEqual(gradient.backgroundColor?.cgColor.alpha ?? 0, 0,
                           "Legacy horizontal rendering must restore its original gradient appearance: \(legacy)")
        }
    }

    func test_nativeReaderSideBackgroundUsesTheAppHeaderThemeAndRestoresHorizontalBackground() throws {
        let defaults = UserDefaults.standard
        let keys = ["theme_style", "theme_light", "theme_dark"]
        let original = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer { for key in keys { defaults.set(original[key] ?? nil, forKey: key) } }
        let manager = try XCTUnwrap(ThemeManager.shared)
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        pages.storyToolbar = StoryToolbar()
        pages.traverseView = UIView()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        detail.storyPagesViewController = pages
        let navigation = UINavigationController(rootViewController: pages)
        navigation.loadViewIfNeeded()

        for theme in ["light", "sepia", "medium", "dark"] {
            let dark = theme == "medium" || theme == "dark"
            defaults.set(dark ? "dark" : "light", forKey: "theme_style")
            defaults.set(theme, forKey: dark ? "theme_dark" : "theme_light")
            pages.simulatedVerticalToolbar = false
            pages.updateTheme()
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            let horizontalBackground = pages.view.backgroundColor
            // LoginViewControllerTests.swift uses ThemeManager.m's app header palette, independent of a feed's brand color.
            let headerBackground = manager.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xF3E2CB, mediumRGB: 0x333333, darkRGB: 0x222222)

            pages.simulatedVerticalToolbar = true
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            XCTAssertEqual(pages.view.backgroundColor, headerBackground,
                           "Entering native side navigation must extend the app theme beneath the rail")
            pages.updateTheme()
            XCTAssertEqual(pages.view.backgroundColor, headerBackground,
                           "A theme refresh must preserve the rail's app header color")
            XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundColor?.cgColor.alpha ?? 0, 0,
                           "The rail background must not restore the unwanted horizontal navigation strip")

            pages.simulatedVerticalToolbar = false
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            XCTAssertEqual(pages.view.backgroundColor, horizontalBackground,
                           "Horizontal phone and iPad reader backgrounds retain their existing theme behavior")
        }
    }

    func test_nativeReaderAppearanceClearsHorizontalBackgroundAndRestoresThemeAfterFolding() {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        pages.storyToolbar = StoryToolbar()
        pages.traverseView = UIView()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        detail.storyPagesViewController = pages
        let navigation = UINavigationController(rootViewController: pages)
        navigation.loadViewIfNeeded()
        pages.updateTheme()
        pages.perform(Selector(("updateReaderToolbarPresentation")))
        let horizontalColor = navigation.navigationBar.standardAppearance.backgroundColor
        XCTAssertGreaterThan(horizontalColor?.cgColor.alpha ?? 0, 0.99)

        for vertical in [true, false, true, false] {
            pages.simulatedVerticalToolbar = vertical
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            let bar = navigation.navigationBar
            for appearance in [bar.standardAppearance, bar.scrollEdgeAppearance, bar.compactAppearance].compactMap({ $0 }) {
                if vertical {
                    XCTAssertEqual(appearance.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.001,
                                   "A vertical reader must not paint a horizontal background strip")
                    XCTAssertEqual(appearance.shadowColor?.cgColor.alpha ?? 0, 0, accuracy: 0.001)
                    XCTAssertNil(appearance.backgroundEffect)
                } else {
                    XCTAssertEqual(appearance.backgroundColor, horizontalColor,
                                   "Returning to horizontal chrome must restore the reader's current theme")
                }
            }
        }
    }

    func test_expandedReaderRestoresItsSharedBarAfterStorySearchUpdatesTheTheme() {
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = DuoEmbeddedReaderDetail()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let pages = DuoReaderAppearancePages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        pages.simulatedVerticalToolbar = true
        pages.storyToolbar = StoryToolbar()
        pages.traverseView = UIView()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        detail.storyPagesViewController = pages
        let stories = DuoSearchThemeStories()
        stories.appDelegate = app
        stories.storiesCollection = app.storiesCollection
        detail.feedDetailViewController = stories
        detail.loadViewIfNeeded()
        for child in [pages as UIViewController, stories] {
            detail.addChild(child)
            detail.view.addSubview(child.view)
            child.didMove(toParent: detail)
        }
        let navigation = UINavigationController(rootViewController: detail)
        navigation.loadViewIfNeeded()
        XCTAssertTrue(pages.navigationController === stories.navigationController)
        pages.perform(Selector(("updateReaderToolbarPresentation")))
        XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundColor?.cgColor.alpha ?? 0, 0)

        // LoginViewControllerTests.swift models expanded containment; search invokes FeedDetailObjCViewController.m's real theme path.
        for _ in 0..<2 {
            XCTAssertTrue((stories as UITextFieldDelegate).textFieldShouldBeginEditing?(stories.searchField) == true)
            XCTAssertGreaterThan(navigation.navigationBar.standardAppearance.backgroundColor?.cgColor.alpha ?? 0, 0.99,
                                 "The search callback must exercise the shared navigation-bar overwrite")
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            for appearance in [navigation.navigationBar.standardAppearance,
                               navigation.navigationBar.scrollEdgeAppearance,
                               navigation.navigationBar.compactAppearance].compactMap({ $0 }) {
                XCTAssertEqual(appearance.backgroundColor?.cgColor.alpha ?? 0, 0, accuracy: 0.001,
                               "The visible reader must restore side-bar appearance even when its layout mode is unchanged")
                XCTAssertNil(appearance.backgroundEffect)
            }
            let repairedAppearance = navigation.navigationBar.standardAppearance
            pages.perform(Selector(("updateReaderToolbarPresentation")))
            XCTAssertTrue(navigation.navigationBar.standardAppearance === repairedAppearance,
                          "A settled reader layout must not recreate its navigation appearance")
        }

        let other = UIViewController()
        navigation.setViewControllers([detail, other], animated: false)
        let otherAppearance = UINavigationBarAppearance()
        otherAppearance.configureWithOpaqueBackground()
        otherAppearance.backgroundColor = .red
        navigation.navigationBar.standardAppearance = otherAppearance
        pages.perform(Selector(("updateReaderToolbarPresentation")))
        XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundColor, .red,
                       "A retained reader must leave the new top controller's appearance alone")
    }

    func test_setStoryFromScrollRefreshesVisiblePageChromeAfterPageSwap() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.storyLocationsCount = 3
        appDelegate.storiesCollection = storiesCollection

        let controller = StoryPagesObjCViewController()
        controller.appDelegate = appDelegate
        controller.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        controller.scrollView.contentSize = CGSize(width: 300, height: 100)

        let previousPage = GradientSpyStoryDetailViewController(pageIndex: -1)
        let currentPage = GradientSpyStoryDetailViewController(pageIndex: 0)
        let nextPage = GradientSpyStoryDetailViewController(pageIndex: 1)

        [currentPage, nextPage, previousPage].forEach { controller.scrollView.addSubview($0.view) }
        controller.currentPage = currentPage
        controller.nextPage = nextPage
        controller.previousPage = previousPage
        controller.scrollingToPage = 2
        controller.scrollView.contentOffset = CGPoint(x: 60, y: 0)

        controller.setStoryFromScroll()

        XCTAssertTrue(controller.currentPage === nextPage)
        XCTAssertTrue(controller.scrollView.subviews.last === nextPage.view)
        XCTAssertEqual(nextPage.drawFeedGradientCallCount, 1)
    }

    func test_feedResetIgnoresOutgoingPagerOffsetsAndCompletion() {
        let app = DuoInterruptedPagerApp()
        let detail = DuoExpansionDetailController()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        app.readStories = NSMutableArray()
        let feed = DuoInterruptedPagerFeed()
        feed.appDelegate = app
        app.fixtureFeed = feed
        let pages = DuoInterruptedPagerPages()
        pages.appDelegate = app
        app.fixturePages = pages
        detail.storyPagesViewController = pages
        pages.loadViewIfNeeded()
        let pageViews = (0..<3).map { _ -> DuoInterruptedPagerPage in
            let page = DuoInterruptedPagerPage()
            page.appDelegate = app
            page.loadViewIfNeeded()
            pages.scrollView.addSubview(page.view)
            return page
        }
        pages.currentPage = pageViews[0]
        pages.nextPage = pageViews[1]
        pages.previousPage = pageViews[2]
        pages.scrollingToPage = -1

        func collection(_ prefix: String) -> StoriesCollection {
            let result = StoriesCollection()
            result.appDelegate = app
            result.activeFeed = ["id": prefix]
            result.activeFeedStories = (0..<2).map {
                ["story_hash": "\(prefix):\($0)", "read_status": 0] as [String: Any]
            }
            result.activeFeedStoryLocations = NSMutableArray(array: [0, 1])
            result.activeFeedStoryLocationIds = NSMutableArray(array: ["\(prefix):0", "\(prefix):1"])
            result.storyCount = 2
            result.storyLocationsCount = 2
            return result
        }
        let outgoing = collection("outgoing")
        app.storiesCollection = outgoing
        feed.storiesCollection = outgoing
        app.activeStory = outgoing.activeFeedStories[0] as? [AnyHashable: Any]
        pages.currentPage.activeStory = NSMutableDictionary(dictionary: app.activeStory)
        pages.currentPage.activeStoryId = "outgoing:0"
        pages.currentPage.pageIndex = 0
        pages.nextPage.pageIndex = 1
        pages.previousPage.pageIndex = -1
        pages.scrollView.contentSize = CGSize(width: 880, height: 640)
        // LoginViewControllerTests.swift installs the same content-offset observer as the real expanded reader.
        pages.scrollView.addObserver(pages, forKeyPath: "contentOffset", options: [.new], context: nil)
        defer { pages.scrollView.removeObserver(pages, forKeyPath: "contentOffset") }
        pages.scrollViewWillBeginDragging(pages.scrollView)
        XCTAssertTrue(pages.isDraggingScrollview)

        // LoginViewControllerTests.swift reproduces FeedDetail.resetFeedDetail clearing selection before a replacement feed arrives.
        app.activeStory = nil
        outgoing.activeFeedStories = []
        outgoing.activeFeedStoryLocations = NSMutableArray()
        outgoing.activeFeedStoryLocationIds = NSMutableArray()
        outgoing.storyCount = 0
        outgoing.storyLocationsCount = 0
        pages.resetPages()
        let incoming = collection("incoming")
        app.storiesCollection = incoming
        feed.storiesCollection = incoming

        // The outgoing scroll still delivers offset and completion callbacks after the feed was reset.
        pages.scrollView.contentOffset = CGPoint(x: 24, y: 0)
        pages.scrollViewDidEndDecelerating(pages.scrollView)

        XCTAssertNil(app.activeStory, "An outgoing swipe must not select a story in the replacement feed")
        XCTAssertEqual(app.selectedHashes, [], "Stale pager events must not move the new feed's row selection")
        XCTAssertEqual(feed.markedHashes, [], "Stale pager events must not mark either feed's stories as read")
        XCTAssertEqual(app.readStories.count, 0, "Stale pager events must not enter either hash into read history")
        XCTAssertNil(pages.currentPage.activeStoryId)

        // LoginViewControllerTests.swift verifies that resetting an outgoing gesture does not disable a fresh gesture in the new feed.
        pages.scrollView.contentSize = CGSize(width: 880, height: 640)
        pages.scrollViewWillBeginDragging(pages.scrollView)
        pages.scrollView.contentOffset = CGPoint(x: 440, y: 0)
        XCTAssertEqual(app.activeStory?["story_hash"] as? String, "incoming:1")
        XCTAssertEqual(app.selectedHashes, ["incoming:1"])
        XCTAssertEqual(feed.markedHashes, [], "Offset tracking selects a row without marking it before the new gesture completes")
    }

    func test_resetPagesClearsStalePageStories() {
        let appDelegate = NewsBlurAppDelegate()
        // LoginViewControllerTests.swift supplies the collection queried by the real iPad pager's layout setup.
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.storiesCollection.appDelegate = appDelegate
        let detailController = DetailViewController()
        let controller = StoryPagesViewController()

        appDelegate.detailViewController = detailController
        detailController.appDelegate = appDelegate
        detailController.storyPagesViewController = controller
        controller.appDelegate = appDelegate
        controller.loadViewIfNeeded()

        let staleStory: NSMutableDictionary = ["story_hash": "stale:story"]
        controller.currentPage.activeStory = staleStory
        controller.nextPage.activeStory = staleStory
        controller.previousPage.activeStory = staleStory

        controller.resetPages()

        XCTAssertNil(controller.currentPage.activeStory)
        XCTAssertNil(controller.currentPage.activeStoryId)
        XCTAssertNil(controller.nextPage.activeStory)
        XCTAssertNil(controller.nextPage.activeStoryId)
        XCTAssertNil(controller.previousPage.activeStory)
        XCTAssertNil(controller.previousPage.activeStoryId)
    }
}

@MainActor private final class DuoInterruptedPagerApp: NewsBlurAppDelegate {
    var fixturePages: StoryPagesViewController?
    var fixtureFeed: FeedDetailViewController?
    var selectedHashes: [String] = []
    override var storyPagesViewController: StoryPagesViewController! { fixturePages }
    override var feedDetailViewController: FeedDetailViewController! { fixtureFeed }
    override func changeActiveFeedDetailRow() {
        selectedHashes.append(activeStory?["story_hash"] as? String ?? "missing")
    }
}

@MainActor private final class DuoInterruptedPagerFeed: FeedDetailViewController {
    var markedHashes: [String] = []
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        markedHashes.append(story?["story_hash"] as? String ?? "missing")
        return false
    }
}

@MainActor private final class DuoInterruptedPagerPages: StoryPagesViewController {
    override var isHorizontal: Bool { true }
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 640))
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func updateStoryTitleNavigationButtons() {}
    override func setNextPreviousButtons() {}
    override func setTextButton() {}
}

@MainActor private final class DuoInterruptedPagerPage: StoryDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 640)) }
    override func viewDidLoad() {}
    override func clearStory() {
        activeStoryId = activeStory?["story_hash"] as? String
        hasStory = false
    }
    override func hideStory() {
        activeStoryId = nil
        hasStory = false
    }
}

@MainActor private final class DuoViewportNavigationDelegate: NSObject, WKNavigationDelegate {
    var paused: (() -> Void)?
    var finished: ((WKNavigation?) -> Void)?
    private var heldDecision: ((WKNavigationActionPolicy) -> Void)?

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let paused {
            self.paused = nil
            heldDecision = decisionHandler
            paused()
        } else {
            decisionHandler(.allow)
        }
    }

    func resume() {
        let decision = heldDecision
        heldDecision = nil
        decision?(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished?(navigation)
    }
}

@MainActor private final class DuoViewportLayoutPage: StoryDetailViewController {
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        webView = WKWebView(frame: view.bounds)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(webView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}

    deinit {
        // LoginViewControllerTests.swift does not install StoryDetailObjCViewController.m's content-offset observer.
        webView = nil
    }
}

@MainActor private final class DuoGradientLayoutPage: StoryDetailViewController {
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
        webView = WKWebView(frame: view.bounds)
        view.addSubview(webView)
    }

    override func viewDidLoad() {}
    // LoginViewControllerTests.swift invokes gradient positioning directly; full reader layout would load the fixture pager's missing storyboard outlets asynchronously.
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}

    deinit {
        // LoginViewControllerTests.swift does not install StoryDetailObjCViewController.m's content-offset observer.
        webView = nil
    }
}

@MainActor private final class DuoReaderAppearancePages: StoryPagesViewController {
    var simulatedVerticalToolbar = false
    override var usesVerticalReaderToolbar: Bool { simulatedVerticalToolbar }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 640)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewSafeAreaInsetsDidChange() {}
    override func updateStoryTitleNavigationButtons() {}
    override func updateStatusBarState() {}
    override func setNextPreviousButtons() {}
}

@MainActor private final class DuoKeyboardArticlePage: StoryDetailViewController {
    var commentsCommands = 0
    var shareCommands = 0
    override func scrolltoComment() { commentsCommands += 1 }
    override func openShareDialog() { shareCommands += 1 }
}

@MainActor private final class DuoEmbeddedReaderDetail: DuoRegularHeightDetailController {
    override var isPhone: Bool { true }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 900, height: 678)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
}

@MainActor private final class DuoSearchThemeStories: FeedDetailViewController {
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 678))
        searchField = UITextField()
        storyTitlesTable = UITableView(frame: view.bounds)
    }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    // LoginViewControllerTests.swift retains real search/theming while excluding unrelated data reloads.
    override func reload() {}
}

@MainActor private final class DuoReaderSafeAreaView: UIView {
    override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: 24, left: 0, bottom: 34, right: 84) }
}

@MainActor private final class DuoReaderSafeAreaWindow: UIWindow {
    var protectedTop: CGFloat = 0
    override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: protectedTop, left: 0, bottom: 34, right: 84) }
}

@available(iOS 15.0, *)
@MainActor
private final class GradientSpyStoryDetailViewController: StoryDetailViewController {
    private(set) var drawFeedGradientCallCount = 0

    init(pageIndex: Int) {
        super.init(nibName: nil, bundle: nil)
        self.pageIndex = pageIndex
        loadViewIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let webView = WKWebView(frame: rootView.bounds)
        rootView.addSubview(webView)

        view = rootView
        self.webView = webView
        noStoryMessage = UIView(frame: .zero)
    }

    override func drawFeedGradient() {
        drawFeedGradientCallCount += 1
    }

    override func becomeFirstResponder() -> Bool {
        true
    }
}
