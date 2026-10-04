import XCTest
import MetalKit
import ImageIO
import Combine
@testable import NewsBlur

@MainActor final class Test_Onboarding: XCTestCase {
    func test_iPadSyncStatusSharesAccountNameRowWithoutCoveringCountsOrNavigationControls() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let titleView = UIView(frame: CGRect(x: 24, y: 50, width: 230, height: 60))
        controller.view.addSubview(titleView)
        let name = UILabel(frame: CGRect(x: 38, y: 12, width: 180, height: 18))
        name.font = .systemFont(ofSize: 14)
        name.text = "a-very-long-newsblur-account-name"
        titleView.addSubview(name)
        let counts = UILabel(frame: CGRect(x: 38, y: 34, width: 110, height: 16))
        counts.text = "7,318 unread"
        titleView.addSubview(counts)
        let notifier = SyncNotifierView(title: "Syncing stories…")
        notifier.accountNameLabel = name
        titleView.addSubview(notifier)
        notifier.showIn(0)
        for width in [230.0, 180.0, 300.0] {
            titleView.frame.size.width = width
            notifier.updateFrameInSuperview()
            XCTAssertEqual(notifier.frame.minX, name.frame.maxX + 8, accuracy: 1)
            XCTAssertEqual(notifier.frame.midY, name.frame.midY, accuracy: 1)
            XCTAssertLessThanOrEqual(notifier.frame.maxX, titleView.bounds.maxX)
            XCTAssertGreaterThan(name.bounds.width, 0)
            XCTAssertFalse(notifier.frame.intersects(counts.frame))
        }
        notifier.hideIn(0)
        XCTAssertEqual(name.bounds.width, min(name.intrinsicContentSize.width, 258), accuracy: 1)
    }

    func test_syncNotifierStaysAtTrailingEdgeWhenShownAfterHiddenLayout() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let column = UIView(frame: CGRect(x: 0, y: 50, width: 320, height: 60))
        controller.view.addSubview(column)
        let notifier = SyncNotifierView(title: "Loading your feeds…")
        column.addSubview(notifier)
        notifier.updateFrameInSuperview()
        notifier.showIn(0)
        XCTAssertGreaterThanOrEqual(notifier.frame.minX, 0, "Hidden translation must not shift the shown notifier off the column.")
        XCTAssertEqual(notifier.frame.maxX, column.bounds.maxX, accuracy: 12, "The shown notifier belongs at the trailing edge of its column.")
        notifier.hideIn(0)
        column.frame.size.width = 400
        notifier.updateFrameInSuperview()
        notifier.showIn(0)
        XCTAssertGreaterThanOrEqual(notifier.frame.minX, 0)
        XCTAssertEqual(notifier.frame.maxX, column.bounds.maxX, accuracy: 12)
        notifier.isPresentationSuppressed = true
        notifier.showWithStyle(.syncing, title: "Loading your feeds…")
        XCTAssertTrue(notifier.isHidden, "Background additions must stay quiet behind onboarding.")
        notifier.isPresentationSuppressed = false
        XCTAssertFalse(notifier.isHidden, "Closing onboarding must restore pending reader progress.")
    }

    func test_syncNotifierUsesFeedColumnInsteadOfNarrowNavigationTitle() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let column = UIView(frame: CGRect(x: 0, y: 50, width: 320, height: 700))
        controller.view.addSubview(column)
        let titleView = UIView(frame: CGRect(x: 35, y: 0, width: 140, height: 60))
        column.addSubview(titleView)
        let notifier = SyncNotifierView(title: "Loading your feeds…")
        notifier.horizontalLayoutView = column
        titleView.addSubview(notifier)
        notifier.showIn(0)
        // OnboardingTests.swift checks portrait overlay, two-column, and wider three-column sidebar geometry.
        for width in [320.0, 375.0, 440.0] {
            column.frame.size.width = width
            notifier.updateFrameInSuperview()
            let frame = notifier.convert(notifier.bounds, to: column)
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertEqual(frame.maxX, column.bounds.maxX, accuracy: 1)
            XCTAssertEqual(frame.midY, titleView.frame.midY, accuracy: 1)
        }
    }

    func test_dismissingEmptyAccountSetupSuppressesAutomaticReopeningWithoutCompletingIt() throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let previousUsername = app.activeUsername
        let username = "onboarding-dismissal-" + UUID().uuidString
        let completionKey = "onboarding_completed_" + username
        defer {
            app.activeUsername = previousUsername
            UserDefaults.standard.removeObject(forKey: completionKey)
        }
        app.activeUsername = username
        XCTAssertTrue(OnboardingViewController.shouldShow(forUsername: username))
        let controller = OnboardingViewController()
        let delegate = (controller as AnyObject) as? UIAdaptivePresentationControllerDelegate
        delegate?.presentationControllerDidDismiss?(UIPresentationController(presentedViewController: controller, presenting: nil))
        XCTAssertFalse(OnboardingViewController.shouldShow(forUsername: username),
                       "An empty feed-list refresh must not reopen setup after dismissal.")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: completionKey),
                       "Closing setup must not mark it completed.")
        XCTAssertTrue(OnboardingViewController.shouldShow(forUsername: username + "-another-account"))
    }

    func test_loginRetainsAnimatedMetalBackground() throws {
        let controller = OnboardingAccountViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.viewWillAppear(false)
        controller.view.layoutIfNeeded()
        func metalView(in view: UIView) -> MTKView? {
            if let metal = view as? MTKView { return metal }
            return view.subviews.lazy.compactMap { metalView(in: $0) }.first
        }
        let background = try XCTUnwrap(metalView(in: controller.view), "The login redesign must preserve the original animated background.")
        XCTAssertNotNil(background.device)
        XCTAssertNotNil(background.delegate)
        XCTAssertFalse(background.isPaused)
        controller.viewDidDisappear(false)
        XCTAssertTrue(background.isPaused, "The login animation must stop when the screen closes.")
    }

    func test_olderPartialFeedResponseCannotReplaceLatestRefresh() {
        let app = OnboardingRefreshAppDelegate()
        let feeds = OnboardingRefreshFeedsController()
        feeds.appDelegate = app
        feeds.fetchFeedList(false)
        feeds.fetchFeedList(false)
        XCTAssertEqual(app.responses.count, 2)
        app.responses[1](nil, ["marker": "complete"])
        app.responses[0](nil, ["marker": "partial"])
        XCTAssertEqual(feeds.appliedMarkers, ["complete"], "A slow partial response must not overwrite the final feed list.")
    }

    func test_failedFinalRefreshEndsLoadingBeforeShowingOfflineError() {
        let app = OnboardingRefreshAppDelegate()
        let feeds = OnboardingRefreshFeedsController()
        feeds.appDelegate = app
        OnboardingFeedLoading.shared.requestRefresh()
        feeds.fetchFeedList(false)
        app.failures[0](nil, URLError(.notConnectedToInternet))
        XCTAssertEqual(feeds.loadingWhenShowingError, [false], "The final error must be allowed to show Offline instead of being replaced by Loading.")
    }

    override func tearDown() {
        OnboardingFeedLoading.shared.reset()
        OnboardingAPI.session = .shared
        OnboardingURLProtocol.handler = nil
        OnboardingURLProtocol.deferredHandler = nil
        super.tearDown()
    }

    private func network(_ handler: @escaping (URLRequest) throws -> (Int, [String: Any])) {
        OnboardingURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OnboardingURLProtocol.self]
        OnboardingAPI.session = URLSession(configuration: configuration)
    }

    func test_socialExplicitLinkPreservesIdentityAndRetriesWithReplacementTicket() async throws {
        for provider in ["apple", "google"] {
            var bodies: [[String: String]] = []
            network { request in
                if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
                XCTAssertEqual(request.url?.path, "/api/social/complete")
                bodies.append(Self.formBody(request))
                if bodies.count == 1 {
                    return (200, ["username_required": true, "ticket": "choose-username-ticket"])
                }
                return (400, ["code": -1, "link_required": true, "can_choose_username": true, "ticket": "retry-link-ticket",
                              "message": "Incorrect NewsBlur password."])
            }
            let model = OnboardingAccountModel()
            _ = try await model.prepareSocial(provider)
            try await model.complete(ticket: "provider-ticket")
            XCTAssertTrue(model.needsUsername)
            XCTAssertFalse(model.needsLink)
            model.username = "existing-reader"
            model.password = "stale-password"
            model.message = "That username is already taken."

            model.connectExistingAccount()

            XCTAssertFalse(model.needsUsername)
            XCTAssertTrue(model.needsLink)
            XCTAssertTrue(model.canChooseUsername)
            XCTAssertEqual(model.username, "existing-reader")
            XCTAssertEqual(model.password, "")
            XCTAssertNil(model.message)
            XCTAssertEqual(bodies.count, 1, "Switching modes must not consume the continuation ticket.")

            model.password = "wrong-password"
            await submitAccount(model)
            XCTAssertEqual(model.message, "Incorrect NewsBlur password.")
            XCTAssertEqual(model.password, "")
            XCTAssertTrue(model.needsLink)
            XCTAssertTrue(model.canChooseUsername)
            XCTAssertEqual(model.username, "existing-reader")
            model.username = "reader+news@example.net"
            model.password = "corrected+password"
            await submitAccount(model)

            XCTAssertEqual(bodies.count, 3)
            guard bodies.count == 3 else { continue }
            XCTAssertNil(bodies[0]["action"], "The initial provider completion must preserve default signup behavior.")
            XCTAssertEqual(bodies[1]["action"], "link")
            XCTAssertEqual(bodies[1]["ticket"], "choose-username-ticket")
            XCTAssertEqual(bodies[1]["username"], "existing-reader")
            XCTAssertEqual(bodies[1]["password"], "wrong-password")
            XCTAssertEqual(bodies[2]["action"], "link")
            XCTAssertEqual(bodies[2]["ticket"], "retry-link-ticket")
            XCTAssertEqual(bodies[2]["username"], "reader+news@example.net")
            XCTAssertEqual(bodies[2]["password"], "corrected+password")
            let verifier = try XCTUnwrap(bodies[0]["verifier"])
            XCTAssertFalse(verifier.isEmpty)
            XCTAssertEqual(bodies[1]["verifier"], verifier)
            XCTAssertEqual(bodies[2]["verifier"], verifier)
        }
    }

    func test_socialSameEmailLinkCannotReturnToSignup() async throws {
        for provider in ["apple", "google"] {
            for includesPermission in [true, false] {
                var bodies: [[String: String]] = []
                network { request in
                    if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
                    XCTAssertEqual(request.url?.path, "/api/social/complete")
                    bodies.append(Self.formBody(request))
                    var response: [String: Any] = ["code": -1, "link_required": true,
                                                  "ticket": "same-email-ticket", "message": "Connect your existing account."]
                    if includesPermission { response["can_choose_username"] = false }
                    return (400, response)
                }
                let model = OnboardingAccountModel()
                _ = try await model.prepareSocial(provider)
                try await model.complete(ticket: "provider-ticket")
                model.username = "existing-reader"
                model.password = "newsblur-password"

                model.createNewAccountInstead()

                XCTAssertTrue(model.needsLink, "A same-email link must not enter a signup loop.")
                XCTAssertFalse(model.needsUsername)
                XCTAssertFalse(model.canChooseUsername)
                XCTAssertEqual(model.username, "existing-reader")
                XCTAssertEqual(model.password, "newsblur-password")
                XCTAssertEqual(model.message, "Connect your existing account.")
                XCTAssertEqual(bodies.count, 1)
                await submitAccount(model)
                XCTAssertEqual(bodies.count, 2)
                XCTAssertEqual(bodies.last?["action"], "link")
                XCTAssertEqual(bodies.last?["ticket"], "same-email-ticket")
                XCTAssertEqual(bodies.last?["username"], "existing-reader")
                XCTAssertEqual(bodies.last?["password"], "newsblur-password")
            }
        }
    }

    func test_socialExplicitUsernameChoiceResetsAfterReturnCancelAndRestart() async throws {
        network { request in
            if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
            return (400, ["code": -1, "username_required": true, "ticket": "choose-username-ticket"])
        }
        let model = OnboardingAccountModel()
        _ = try await model.prepareSocial("google")
        try await model.complete(ticket: "provider-ticket")
        model.connectExistingAccount()
        XCTAssertTrue(model.canChooseUsername)
        model.createNewAccountInstead()
        XCTAssertTrue(model.needsUsername, "Explicit linking must allow a local return before submitting credentials.")
        XCTAssertFalse(model.needsLink)
        XCTAssertFalse(model.canChooseUsername)
        model.connectExistingAccount()
        XCTAssertTrue(model.canChooseUsername)
        model.cancelContinuation()
        XCTAssertFalse(model.canChooseUsername)

        _ = try await model.prepareSocial("apple")
        try await model.complete(ticket: "another-provider-ticket")
        model.connectExistingAccount()
        XCTAssertTrue(model.canChooseUsername)
        _ = try await model.prepareSocial("google")
        XCTAssertFalse(model.canChooseUsername)
    }

    func test_socialLinkRetryCanRevokeUsernameChoice() async throws {
        var completions = 0
        network { request in
            if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
            completions += 1
            if completions == 1 { return (400, ["username_required": true, "ticket": "choose-username-ticket"]) }
            XCTAssertEqual(Self.formBody(request)["action"], "link")
            return (400, ["link_required": true, "can_choose_username": false, "ticket": "same-email-ticket"])
        }
        let model = OnboardingAccountModel()
        _ = try await model.prepareSocial("apple")
        try await model.complete(ticket: "provider-ticket")
        model.connectExistingAccount()
        XCTAssertTrue(model.canChooseUsername)
        model.username = "existing-reader"
        model.password = "wrong-password"
        await submitAccount(model)
        XCTAssertFalse(model.canChooseUsername, "The server response must replace any previous local permission.")
        model.createNewAccountInstead()
        XCTAssertTrue(model.needsLink)
        XCTAssertFalse(model.needsUsername)
        XCTAssertEqual(model.username, "existing-reader")
    }

    func test_socialSameEmailLinkSendsExplicitAction() async throws {
        for provider in ["apple", "google"] {
            var bodies: [[String: String]] = []
            network { request in
                if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
                bodies.append(Self.formBody(request))
                return (400, ["code": -1, "link_required": true, "ticket": "same-email-ticket"])
            }
            let model = OnboardingAccountModel()
            _ = try await model.prepareSocial(provider)
            try await model.complete(ticket: "provider-ticket")
            XCTAssertTrue(model.needsLink)
            XCTAssertFalse(model.needsUsername)
            model.username = "reader@example.com"
            model.password = "newsblur-password"
            await submitAccount(model)
            XCTAssertEqual(bodies.count, 2)
            XCTAssertEqual(bodies.last?["action"], "link")
            XCTAssertEqual(bodies.last?["ticket"], "same-email-ticket")
            XCTAssertEqual(bodies.last?["username"], "reader@example.com")
            XCTAssertEqual(bodies.last?["password"], "newsblur-password")
        }
    }

    func test_socialUsernameCollisionCanReturnToSignupWithRetainedTicket() async throws {
        for provider in ["apple", "google"] {
            var bodies: [[String: String]] = []
            network { request in
                if request.url?.path == "/api/social/start" { return (200, ["state": "provider-state"]) }
                XCTAssertEqual(request.url?.path, "/api/social/complete")
                bodies.append(Self.formBody(request))
                switch bodies.count {
                case 1:
                    return (400, ["code": -1, "username_required": true, "ticket": "choose-username-ticket"])
                case 2:
                    return (400, ["code": -1, "link_required": true, "can_choose_username": true, "ticket": "collision-link-ticket",
                                  "message": "Sign in to your existing NewsBlur account to connect this provider."])
                default:
                    // OnboardingTests.swift observes signup submission without authenticating the shared app.
                    return (503, ["code": -1, "message": "Signup fixture stopped after request."])
                }
            }
            let model = OnboardingAccountModel()
            _ = try await model.prepareSocial(provider)
            try await model.complete(ticket: "provider-ticket")
            model.username = "someone-elses-username"
            await submitAccount(model)
            XCTAssertTrue(model.needsLink)
            XCTAssertFalse(model.needsUsername)
            XCTAssertTrue(model.canChooseUsername)
            XCTAssertEqual(model.username, "someone-elses-username")
            XCTAssertNotNil(model.message)
            model.password = "stale-link-password"

            model.createNewAccountInstead()

            XCTAssertTrue(model.needsUsername)
            XCTAssertFalse(model.needsLink)
            XCTAssertEqual(model.username, "")
            XCTAssertEqual(model.password, "")
            XCTAssertNil(model.message)
            XCTAssertEqual(bodies.count, 2, "Returning to username selection must not consume the ticket.")
            model.username = "available-new-reader"
            await submitAccount(model)

            XCTAssertEqual(bodies.count, 3)
            guard bodies.count == 3 else { continue }
            XCTAssertEqual(bodies[1]["username"], "someone-elses-username")
            XCTAssertEqual(bodies[1]["ticket"], "choose-username-ticket")
            XCTAssertEqual(bodies[2]["username"], "available-new-reader")
            XCTAssertEqual(bodies[2]["ticket"], "collision-link-ticket")
            XCTAssertEqual(bodies[2]["password"], "")
            XCTAssertNil(bodies[2]["action"], "Choosing a new username must return to the default signup action.")
            let verifier = try XCTUnwrap(bodies[0]["verifier"])
            XCTAssertFalse(verifier.isEmpty)
            XCTAssertEqual(bodies[1]["verifier"], verifier)
            XCTAssertEqual(bodies[2]["verifier"], verifier)
            XCTAssertEqual(model.message, "Signup fixture stopped after request.")
        }
    }

    private func submitAccount(_ model: OnboardingAccountModel) async {
        let finished = expectation(description: "Account submission finished")
        let observation = model.$busy.dropFirst().filter { !$0 }.prefix(1).sink { _ in finished.fulfill() }
        model.emailSignIn()
        await fulfillment(of: [finished], timeout: 3)
        observation.cancel()
    }

    nonisolated private static func formBody(_ request: URLRequest) -> [String: String] {
        let items = URLComponents(string: "https://fixture.invalid/?" + body(request))?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func test_providerDeletionRequiresVerificationAndTypedConfirmation() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        var paths: [String] = []
        var deleted = 0
        network { request in
            paths.append(request.url!.path)
            switch request.url!.path {
            case "/api/social/account": return (200, ["code": 1, "providers": ["google"], "has_password": false])
            case "/api/social/start":
                XCTAssertTrue(Self.body(request).contains("purpose=delete_account"))
                return (200, ["state": "delete-state", "url": "https://accounts.google.com/test"])
            case "/api/social/complete": return (200, ["code": 1, "delete_token": "verified-token"])
            case "/api/social/delete_account":
                XCTAssertTrue(Self.body(request).contains("delete_token=verified-token"))
                XCTAssertTrue(Self.body(request).contains("confirm=Delete"))
                return (200, ["code": 1])
            default: XCTFail("Unexpected request"); return (500, [:])
            }
        }
        let model = AccountDeletionModel(onDeleted: { _ in deleted += 1 })
        await model.load()
        XCTAssertEqual(model.providers, ["google"])
        await model.deleteAccount()
        XCTAssertFalse(paths.contains("/api/social/delete_account"))
        _ = try await model.authentication.prepareSocial("google")
        try await model.authentication.complete(ticket: "provider-ticket")
        XCTAssertTrue(model.isVerified)
        XCTAssertEqual(app.activeUsername, "delete-fixture", "Provider verification must never finish normal sign-in.")
        model.confirmation = "delete"
        await model.deleteAccount()
        XCTAssertFalse(paths.contains("/api/social/delete_account"))
        model.confirmation = "Delete"
        await model.deleteAccount()
        XCTAssertEqual(paths.filter { $0 == "/api/social/delete_account" }.count, 1)
        XCTAssertEqual(deleted, 1)
    }

    func test_appleDeletionSendsRevocationCodeWithoutChangingOrdinarySignIn() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        for deleting in [true, false] {
            var appleRequests = 0
            network { request in
                switch request.url?.path {
                case "/api/social/start": return (200, ["state": "apple-state", "nonce": "fixture-nonce"])
                case "/api/social/apple":
                    appleRequests += 1
                    let body = Self.body(request)
                    let fields = URLComponents(string: "https://fixture.invalid/?" + body)?.queryItems ?? []
                    XCTAssertEqual(fields.first { $0.name == "state" }?.value, "apple-state")
                    XCTAssertEqual(fields.first { $0.name == "id_token" }?.value, "fixture-identity-token")
                    XCTAssertEqual(fields.first { $0.name == "authorization_code" }?.value,
                                   deleting ? "fixture-code+for/revocation" : nil)
                    return (200, ["ticket": "apple-ticket"])
                case "/api/social/complete": return (200, ["code": 1, "delete_token": "deletion-proof"])
                default: XCTFail("Unexpected request"); return (500, [:])
                }
            }
            let deletion = AccountDeletionModel(onDeleted: { _ in XCTFail("Verification must not delete the account") })
            let authentication = deleting ? deletion.authentication : OnboardingAccountModel()
            _ = try await authentication.prepareSocial("apple")
            let ticket = try await authentication.exchangeAppleCredential(identityToken: Data("fixture-identity-token".utf8),
                                                                          authorizationCode: Data("fixture-code+for/revocation".utf8))
            XCTAssertEqual(ticket, "apple-ticket")
            XCTAssertEqual(appleRequests, 1)
            if deleting {
                try await authentication.complete(ticket: ticket)
                XCTAssertTrue(deletion.isVerified)
            }
            XCTAssertEqual(app.activeUsername, "delete-fixture")
        }
    }

    func test_appleLinkedDeletionUsesAppleAndStillFinishesWhenManualRevocationIsRequired() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        network { request in
            switch request.url?.path {
            case "/api/social/account": return (200, ["code": 1, "providers": ["apple", "google"], "has_password": false])
            case "/api/social/start": return (200, ["state": "apple-state"])
            case "/api/social/complete": return (200, ["code": 1, "delete_token": "deletion-proof"])
            case "/api/social/delete_account": return (200, ["code": 1, "apple_revocation_required": true])
            default: XCTFail("Unexpected request"); return (500, [:])
            }
        }
        var deletionNotices: [Bool] = []
        let model = AccountDeletionModel(onDeleted: { deletionNotices.append($0) })
        await model.load()
        XCTAssertEqual(model.providers, ["apple"], "An Apple-linked account needs Apple's fresh revocation code.")
        _ = try await model.authentication.prepareSocial("apple")
        try await model.authentication.complete(ticket: "apple-ticket")
        model.confirmation = "Delete"
        await model.deleteAccount()
        XCTAssertEqual(deletionNotices, [true], "Unavailable revocation must not prevent deletion from finishing and showing the instructions.")
        XCTAssertNil(model.message)
    }

    func test_providerDeletionCancellationAndAccountSwitchCannotWrite() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        defer { app.activeUsername = username }
        for cancel in [true, false] {
            app.activeUsername = "delete-fixture"
            var mutations: [String] = []
            network { request in
                mutations.append(request.url!.path)
                return (200, ["state": "delete-state", "delete_token": "verified-token"])
            }
            let model = AccountDeletionModel(onDeleted: { _ in XCTFail("Must not delete") })
            _ = try await model.authentication.prepareSocial("google")
            if cancel { model.cancel() } else { app.activeUsername = "another-account" }
            do { try await model.authentication.complete(ticket: "provider-ticket"); XCTFail("Expected stale verification rejection") }
            catch {}
            model.confirmation = "Delete"
            await model.deleteAccount()
            XCTAssertEqual(mutations, ["/api/social/start"])
        }
    }

    func test_passwordAccountAndOldServerRetainLegacyDeletion() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        for response in [["code": 1, "providers": [], "has_password": true], ["_test_html": "<html>NewsBlur</html>"]] as [[String: Any]] {
            network { _ in (200, response) }
            let model = AccountDeletionModel(onDeleted: { _ in})
            await model.load()
            XCTAssertTrue(model.useLegacyDeletion)
        }
    }

    func test_staleAccountCannotUseVerifiedDeletionProof() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        var deletes = 0
        network { request in
            if request.url?.path == "/api/social/delete_account" { deletes += 1 }
            return (200, ["state": "delete-state", "delete_token": "verified-token"])
        }
        let model = AccountDeletionModel(onDeleted: { _ in XCTFail("Wrong account must not be deleted") })
        _ = try await model.authentication.prepareSocial("google")
        try await model.authentication.complete(ticket: "provider-ticket")
        app.activeUsername = "another-account"
        model.confirmation = "Delete"
        await model.deleteAccount()
        XCTAssertEqual(deletes, 0)
        XCTAssertFalse(model.isVerified)
        XCTAssertNotNil(model.message)
    }

    func test_expiredDeletionProofReturnsToProviderVerificationWithoutRetrying() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let username = app.activeUsername
        app.activeUsername = "delete-fixture"
        defer { app.activeUsername = username }
        var deletes = 0
        network { request in
            if request.url?.path == "/api/social/account" { return (200, ["code": 1, "providers": ["google"], "has_password": false]) }
            if request.url?.path == "/api/social/delete_account" {
                deletes += 1
                return (400, ["code": -1, "message": "Please verify your identity again."])
            }
            return (200, ["state": "delete-state", "delete_token": "verified-token"])
        }
        let model = AccountDeletionModel(onDeleted: { _ in XCTFail("Expired proof cannot delete") })
        await model.load()
        _ = try await model.authentication.prepareSocial("google")
        try await model.authentication.complete(ticket: "provider-ticket")
        model.confirmation = "Delete"
        await model.deleteAccount()
        XCTAssertFalse(model.isVerified)
        XCTAssertEqual(model.providers, ["google"])
        XCTAssertEqual(model.confirmation, "")
        XCTAssertEqual(model.message, "Please verify your identity again.")
        model.confirmation = "Delete"
        await model.deleteAccount()
        XCTAssertEqual(deletes, 1, "A failed proof must never be posted a second time.")
    }

    func test_bundleSourcesStartTogetherAndPreserveChoicesAsResultsArrive() async throws {
        let sources = ["rss", "newsletter", "youtube", "reddit", "podcast"]
        let fixtures = Dictionary(uniqueKeysWithValues: sources.map { source in
            (source, (0..<5).map { index in
                ["feed_url": "https://example.com/\(source)/\(index)", "title": "\(source) \(index)",
                 "feed_type": source, "favicon": Self.fixtureIcon(index),
                 "last_story_date": Date().ISO8601Format(), "stories": Self.englishStories] as [String: Any]
            })
        })
        network { request in
            let source = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems?.first { $0.name == "type" }?.value ?? "rss"
            return (200, ["feeds": fixtures[source] ?? []])
        }
        let held = OnboardingHeldRequests()
        let started = expectation(description: "All five sources start before any response completes")
        started.expectedFulfillmentCount = 5
        OnboardingURLProtocol.deferredHandler = { request, completion in
            let source = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems?.first { $0.name == "type" }?.value ?? "rss"
            held.hold(source, completion: completion)
            started.fulfill()
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        let loading = Task { await bundles.load("food & cooking") }
        await fulfillment(of: [started], timeout: 2)
        // OnboardingTests.swift releases the serial implementation after the failing assertion so the regression cannot hang.
        if held.count < 5 {
            OnboardingURLProtocol.deferredHandler = nil
            for source in sources { held.respond(source, json: ["feeds": fixtures[source] ?? []]) }
            await loading.value
            return
        }
        let visible = expectation(description: "A completed source becomes visible while the others are pending")
        let observation = bundles.$feeds.sink { if !$0.isEmpty { visible.fulfill() } }
        held.respond("rss", json: ["feeds": fixtures["rss"]!])
        await fulfillment(of: [visible], timeout: 2)
        observation.cancel()
        XCTAssertTrue(bundles.busy)
        let first = bundles.feeds.first?.url
        if let first { bundles.selection.remove(first) }
        bundles.folder = "My Cooking"
        for source in sources.dropFirst() { held.respond(source, json: ["feeds": fixtures[source]!]) }
        await loading.value
        XCTAssertFalse(bundles.busy)
        XCTAssertEqual(bundles.folder, "My Cooking")
        XCTAssertNotNil(first)
        if let first {
            XCTAssertTrue(bundles.feeds.contains { $0.url == first }, "Later sources must not remove a visible feed.")
            XCTAssertFalse(bundles.selection.contains(first), "Later results must not undo a deselection.")
        }
        XCTAssertGreaterThanOrEqual(Set(bundles.feeds.map(\.source)).count, 4)
    }

    func test_cancelledBundleCannotReplaceNewInterestWhenOldSourcesFinish() async {
        network { _ in (200, [:]) }
        let held = OnboardingHeldRequests()
        let started = expectation(description: "Old bundle starts all requests")
        started.expectedFulfillmentCount = 5
        func fixtures(_ category: String, source: String) -> [[String: Any]] {
            (0..<5).map { index in
                ["feed_url": "https://example.com/\(category)/\(source)/\(index)", "title": "Example",
                 "feed_type": source, "favicon": Self.fixtureIcon(index),
                 "last_story_date": Date().ISO8601Format(), "stories": Self.englishStories]
            }
        }
        OnboardingURLProtocol.deferredHandler = { request, completion in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            let source = items.first { $0.name == "type" }!.value!
            if items.first(where: { $0.name == "category" })?.value == "science" {
                held.hold(source, completion: completion)
                started.fulfill()
            } else { completion(200, ["feeds": fixtures("new", source: source)]) }
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        let old = Task { await bundles.load("science") }
        await fulfillment(of: [started], timeout: 2)
        old.cancel()
        await bundles.load("food & cooking")
        bundles.folder = "My New Folder"
        let chosen = bundles.selection
        for source in ["rss", "newsletter", "youtube", "reddit", "podcast"] {
            held.respond(source, json: ["feeds": fixtures("old", source: source)])
        }
        await old.value
        XCTAssertEqual(bundles.folder, "My New Folder")
        XCTAssertEqual(bundles.selection, chosen)
        XCTAssertFalse(bundles.feeds.isEmpty)
        XCTAssertTrue(bundles.feeds.allSatisfy { $0.url.contains("/new/") })
        XCTAssertFalse(bundles.busy)
    }

    func test_bundlesFillFiveIconsWhenOnlyOneSourceHasUsableFeeds() async throws {
        var requests = 0
        var iconRequests = 0
        network { request in
            if request.url?.path == "/reader/favicons" {
                iconRequests += 1
                return (200, Self.iconResponse(request))
            }
            requests += 1
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            let source = items.first { $0.name == "type" }?.value ?? "all"
            if source == "newsletter" { return (503, ["message": "Temporary source failure"]) }
            let limit = Int(items.first { $0.name == "limit" }?.value ?? "50") ?? 50
            let entries: [[String: Any]] = (0..<8).map { index in
                ["title": "Cooking site \(index)", "feed_url": "https://example.com/cooking/\(index)",
                 "feed_type": "rss", "description": "Simple recipes and practical cooking advice for your kitchen.",
                 "favicon": Self.fixtureIcon(index), "last_story_date": Date().ISO8601Format(),
                 "stories": Self.englishStories]
            }
            return (200, ["categories": ["food & cooking"], "feeds": source == "rss" || source == "all" ? Array(entries.prefix(limit)) : []])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        await bundles.loadIcons("food & cooking")
        XCTAssertGreaterThanOrEqual(bundles.icons["food & cooking"]?.count ?? 0, 5)
        await bundles.load("food & cooking")
        XCTAssertGreaterThanOrEqual(bundles.feeds.count, 5)
        XCTAssertGreaterThanOrEqual(bundles.icons["food & cooking"]?.count ?? 0, 5,
                                    "Opening a bundle must not collapse its icons to one per source.")
        XCTAssertEqual(requests, 5, "Only opening the bundle may fetch story previews.")
        XCTAssertGreaterThan(iconRequests, 0)
        XCTAssertEqual(bundles.folder, "Cooking & Food")
        await bundles.load("food & cooking")
        XCTAssertEqual(requests, 5, "Reopening within the presentation reuses the validated story pool.")
    }

    func test_categoryIconsPublishOneAtATimeBeforeRemainingResponses() async {
        network { request in (200, Self.iconResponse(request)) }
        let ids = OnboardingIconCatalog.categories["food & cooking"]!.prefix(5).map(\.id)
        let held = OnboardingHeldRequests()
        let started = expectation(description: "Five icon requests")
        started.expectedFulfillmentCount = 5
        OnboardingURLProtocol.deferredHandler = { request, completion in
            let values = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            XCTAssertEqual(values.count, 1)
            held.hold(values.first!.value!, completion: completion)
            started.fulfill()
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        let loading = Task { await bundles.loadIcons("food & cooking") }
        await fulfillment(of: [started], timeout: 3)
        let first = expectation(description: "First icon visible without the other four")
        let observation = bundles.$icons.sink { icons in
            if icons["food & cooking"]?.count == 1 { first.fulfill() }
        }
        held.respond(ids[0], json: [ids[0]: Self.fixtureIcon(1)])
        await fulfillment(of: [first], timeout: 2)
        observation.cancel()
        XCTAssertEqual(bundles.icons["food & cooking"]?.map(\.id), [ids[0]])
        XCTAssertEqual(held.count, 4)
        for (index, id) in ids.dropFirst().enumerated() { held.respond(id, json: [id: Self.fixtureIcon(index + 2)]) }
        await loading.value
        XCTAssertEqual(bundles.icons["food & cooking"]?.count, 5)
        XCTAssertEqual(bundles.icons["food & cooking"]?.first?.id, ids[0], "Later icons must not reorder the first arrival.")
    }

    func test_cardIconRequestsCoalesceButNewPresentationFetchesFreshImages() async {
        var requests = 0
        var generation = 0
        network { request in
            XCTAssertEqual(request.url?.path, "/reader/favicons")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            requests += 1
            return (200, Self.iconResponse(request, generation: generation))
        }
        let first = OnboardingBundles(onSubscriptionsChanged: {})
        async let cooking: Void = first.loadIcons("food & cooking")
        async let science: Void = first.loadIcons("science")
        async let all: Void = first.loadIcons(nil)
        _ = await (cooking, science, all)
        XCTAssertEqual(first.icons["food & cooking"]?.count, 5)
        XCTAssertEqual(first.icons["science"]?.count, 5)
        XCTAssertEqual(first.icons[""]?.count, 5)
        XCTAssertLessThanOrEqual(requests, 15)
        let before = requests
        await first.loadIcons("food & cooking")
        XCTAssertEqual(requests, before)
        generation = 1
        let reopened = OnboardingBundles(onSubscriptionsChanged: {})
        await reopened.loadIcons("food & cooking")
        XCTAssertGreaterThan(requests, before)
        XCTAssertNotEqual(first.icons["food & cooking"]?.first?.faviconData, reopened.icons["food & cooking"]?.first(where: { $0.id == first.icons["food & cooking"]?.first?.id })?.faviconData)
    }

    func test_missingCardIconUsesFreshAuditedSpareWithoutLoadingStories() async {
        let missingID = OnboardingIconCatalog.categories["food & cooking"]!.first!.id
        var requests = 0
        network { request in
            XCTAssertEqual(request.url?.path, "/reader/favicons")
            requests += 1
            var response = Self.iconResponse(request)
            response[missingID] = Data("not an image".utf8).base64EncodedString()
            return (200, response)
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        await bundles.loadIcons("food & cooking")
        XCTAssertEqual(bundles.icons["food & cooking"]?.count, 5)
        XCTAssertFalse(bundles.icons["food & cooking"]?.contains { $0.id == missingID } ?? true)
        XCTAssertLessThanOrEqual(requests, 6)
    }

    func test_failedIconBatchCanRetryWithoutAStoryRequestStorm() async {
        var fail = true
        var requests = 0
        network { request in
            XCTAssertEqual(request.url?.path, "/reader/favicons")
            requests += 1
            return fail ? (503, [:]) : (200, Self.iconResponse(request))
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        bundles.interests = ["food & cooking"]
        await bundles.loadIcons("food & cooking")
        XCTAssertTrue(bundles.iconLoadFailed)
        XCTAssertLessThanOrEqual(requests, 10)
        fail = false
        await bundles.retryIcons()
        XCTAssertFalse(bundles.iconLoadFailed)
        XCTAssertEqual(bundles.icons["food & cooking"]?.count, 5)
        XCTAssertLessThanOrEqual(requests, 15)
    }

    func test_categoryIconsDoNotDownloadStoryPreviews() async {
        var previewRequests = 0
        var iconRequests = 0
        network { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            if request.url?.path == "/reader/favicons" {
                iconRequests += 1
                XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
                var response: [String: Any] = [:]
                for item in items where item.name == "feed_ids" || item.name == "feed_ids[]" {
                    if let id = item.value { response[id] = Self.fixtureIcon(Int(id) ?? 0) }
                }
                return (200, response)
            }
            if items.contains(where: { $0.name == "include_stories" && $0.value == "true" }) { previewRequests += 1 }
            return (200, ["feeds": (0..<5).map { index in
                ["title": "Cooking site \(index)", "feed_url": "https://example.com/cooking/\(index)",
                 "feed_type": "rss", "favicon": Self.fixtureIcon(index),
                 "last_story_date": Date().ISO8601Format(), "stories": Self.englishStories] as [String: Any]
            }])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        await bundles.loadIcons("food & cooking")
        XCTAssertEqual(bundles.icons["food & cooking"]?.count, 5)
        XCTAssertEqual(previewRequests, 0, "Rendering a category must not fetch hundreds of stories before its icons appear.")
        XCTAssertGreaterThan(iconRequests, 0, "Icons must be freshly downloaded, not bundled or persisted images.")
        XCTAssertLessThanOrEqual(iconRequests, 6, "A visible category should request only its own icons.")
    }

    func test_catalogRejectsForeignStaleBrokenAndImagelessFeeds() {
        let now = Date()
        func entry(_ index: Int) -> [String: Any] {
            ["feed_url": "https://example.com/\(index)", "feed_type": "rss", "favicon": Self.fixtureIcon(index),
             "last_story_date": now.ISO8601Format(),
             "stories": Self.englishStories]
        }
        var foreign = entry(5)
        foreign["description"] = "The best English cooking website for home cooks."
        foreign["stories"] = Self.englishStories + [["story_title": "Las mejores recetas para preparar una cena deliciosa con toda la familia"]]
        var missing = entry(6)
        missing["favicon"] = nil
        missing["thumbnail_url"] = "https://example.com/unverified.png"
        var broken = entry(7)
        broken["feed"] = ["has_exception": true, "exception_type": "feed"]
        var pageError = entry(8)
        pageError["feed"] = ["has_exception": true, "exception_type": "page", "favicon": Self.fixtureIcon(8),
                             "last_story_date": now.ISO8601Format()]
        var stale = entry(9)
        stale["last_story_date"] = "2019-01-01T00:00:00Z"
        var unknown = entry(10)
        unknown["last_story_date"] = nil
        var corrupt = entry(11)
        corrupt["favicon"] = Data("not an image".utf8).base64EncodedString()
        var insufficient = entry(12)
        insufficient["stories"] = Array(Self.englishStories.prefix(2))
        let result = OnboardingCatalogSelector.select((0..<5).map(entry) + [foreign, missing, broken, pageError, stale, unknown, corrupt, insufficient], now: now)
        XCTAssertEqual(Set(result.feeds.map(OnboardingCatalogSelector.address)), Set((0..<5).map { "https://example.com/\($0)" } + ["https://example.com/8"]))
        XCTAssertEqual(result.icons.count, 5)
        XCTAssertEqual(Set(result.icons.compactMap { OnboardingCatalogSelector.favicon($0).flatMap(OnboardingCatalogSelector.iconFingerprint) }).count, 5)
        XCTAssertEqual(OnboardingCatalogSelector.canonicalInterests(["cooking & food", "food & cooking", "art & design", "design"]), ["food & cooking", "design"])
    }

    func test_bundlesMixSourcesAndRetryOnlyFailedSubscriptions() async throws {
        var attempted: [String] = []
        var failYouTube = true
        network { request in
            if request.url?.path == "/reader/add_url" {
                let body = Self.body(request)
                attempted.append(body)
                if body.contains("youtube"), failYouTube { return (200, ["code": -1, "message": "Temporary failure"]) }
                return (200, ["code": 1])
            }
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let source = items.first { $0.name == "type" }!.value!
            XCTAssertEqual(items.first { $0.name == "include_stories" }?.value, "true")
            return (200, ["categories": ["Science"], "feeds": [["title": source, "feed_url": "https://example.com/\(source)", "feed_type": source,
                "favicon": Self.fixtureIcon(["rss", "newsletter", "youtube", "reddit", "podcast"].firstIndex(of: source) ?? 0), "last_story_date": Date().ISO8601Format(),
                "thumbnail_url": "https://example.com/icon.png", "stories": [["story_hash": source + "-1", "story_title": "A real preview of the latest news and discoveries",
                    "image_urls": ["https://example.com/story.jpg"]]] + Self.englishStories]]])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        await bundles.load("Science")
        XCTAssertEqual(Set(bundles.feeds.map(\.source)), ["rss", "newsletter", "youtube", "reddit", "podcast"])
        XCTAssertEqual(bundles.selection.count, 5)
        XCTAssertEqual(bundles.feeds.first?.preview.stories.first?.title, "A real preview of the latest news and discoveries")
        XCTAssertEqual(bundles.feeds.first?.preview.stories.first?.imageUrls, ["https://example.com/story.jpg"])
        XCTAssertEqual(bundles.feeds.first?.preview.faviconUrl, "https://example.com/icon.png")
        let addition = bundles.queueSubscriptions(interest: "Science")
        XCTAssertEqual(bundles.categoryStatus("Science"), "5 feeds selected")
        XCTAssertEqual(bundles.folderSummaries.map(\.title), ["Science"])
        XCTAssertEqual(bundles.summaryFeedCount, 5)
        XCTAssertNil(bundles.categoryStatus("Technology"))
        await addition?.value
        XCTAssertEqual(bundles.added.count, 4)
        XCTAssertEqual(bundles.categoryStatus("Science"), "4 feeds added", "Failed requests must not count as added.")
        XCTAssertEqual(bundles.summaryFeedCount, 4)
        XCTAssertEqual(bundles.selection, ["https://example.com/youtube"])
        XCTAssertTrue(attempted.allSatisfy { $0.contains("new_folder=Science") && $0.removingPercentEncoding!.contains("folder_path=[]") })
        failYouTube = false
        await bundles.queueSubscriptions(interest: "Science")?.value
        XCTAssertEqual(attempted.count, 6)
        XCTAssertEqual(bundles.added.count, 5)
        XCTAssertEqual(bundles.categoryStatus("Science"), "5 feeds added")
        XCTAssertEqual(bundles.folderSummaries.first?.feeds.count, 5)
        XCTAssertTrue(bundles.selection.isEmpty)
    }

    func test_knownFeedBatchRetriesOnlyFailedIDsAndKeepsFolder() async throws {
        var bodies: [String] = []
        network { request in
            XCTAssertEqual(request.url?.path, "/reader/add_feeds")
            if request.httpMethod == "GET" { return (200, ["batch_add_supported": true, "max_feeds": 100]) }
            bodies.append(Self.body(request).removingPercentEncoding ?? "")
            let results: [[String: Any]] = bodies.count == 1
                ? [["feed_id": 101, "code": 1], ["feed_id": 102, "code": -1, "message": "Try again"]]
                : [["feed_id": 102, "code": 1, "created": false]]
            return (200, ["code": bodies.count == 1 ? 0 : 1, "results": results])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        bundles.feeds = [101, 102].map { OnboardingFeed(preview: DiscoverPopularFeed(feedId: String($0), feedDict: ["feed_address": "https://example.com/\($0)"])) }
        bundles.selection = Set(bundles.feeds.map(\.url))
        bundles.folder = "My Cooking"
        await bundles.subscribe()
        XCTAssertEqual(bundles.added, ["https://example.com/101"])
        let failure = try XCTUnwrap(bundles.failedBundles.first)
        bundles.folder = "Another Folder"
        bundles.retry(failure)
        for _ in 0..<100 where !bundles.queued.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(bundles.added.count, 2)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertTrue(bodies[0].contains("feed_ids=[101,102]"))
        XCTAssertTrue(bodies[1].contains("feed_ids=[102]"))
        XCTAssertTrue(bodies.allSatisfy { $0.contains("new_folder=My Cooking") && $0.contains("folder_path=[]") })
    }

    func test_accountChangeDuringCapabilityProbeCannotSendQueuedSubscriptions() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let originalUsername = app.activeUsername
        let originalServer = app.url
        defer {
            app.activeUsername = originalUsername
            app.setCustomDomainForTesting(originalServer)
        }
        for change in ["username", "server", "session reset"] {
            for supported in [true, false] {
                app.activeUsername = "original-account"
                app.setCustomDomainForTesting("https://original-account.invalid")
                OnboardingFeedLoading.shared.reset()
                var writes: [URLRequest] = []
                network { _ in (200, [:]) }
                let held = OnboardingHeldRequests()
                let probing = expectation(description: "Capability probe is suspended")
                OnboardingURLProtocol.deferredHandler = { request, completion in
                    if request.httpMethod == "GET" {
                        held.hold("probe", completion: completion)
                        probing.fulfill()
                    } else {
                        writes.append(request)
                        completion(200, ["code": 1, "results": [["feed_id": 101, "code": 1]]])
                    }
                }
                var refreshes = 0
                let bundles = OnboardingBundles(onSubscriptionsChanged: { refreshes += 1 })
                let feed = DiscoverPopularFeed(feedId: "101", feedDict: ["feed_address": "https://example.com/101"])
                let task = try XCTUnwrap(bundles.queueSearchResult(feed, folder: "Science"))
                await fulfillment(of: [probing], timeout: 2)
                if change == "username" { app.activeUsername = "another-account" }
                if change == "server" { app.setCustomDomainForTesting("https://another-server.invalid") }
                if change == "session reset" { OnboardingFeedLoading.shared.reset() }
                held.respond("probe", json: ["batch_add_supported": supported])
                await task.value
                XCTAssertTrue(writes.isEmpty, "\(change), batch=\(supported): a stale queue must not send a POST.")
                XCTAssertTrue(bundles.queued.isEmpty)
                XCTAssertTrue(bundles.added.isEmpty)
                XCTAssertTrue(bundles.failedBundles.isEmpty)
                XCTAssertEqual(refreshes, 0)
                XCTAssertFalse(OnboardingFeedLoading.shared.isLoading)
            }
        }
    }

    func test_batchFallsBackOnlyForMissingEndpointNotAmbiguousTransport() async {
        for missingEndpoint in [true, false] {
            var paths: [String] = []
            network { request in
                if request.httpMethod == "GET" { return (200, ["batch_add_supported": true, "max_feeds": 100]) }
                paths.append(request.url!.path)
                if request.url!.path == "/reader/add_feeds" {
                    if missingEndpoint { return (404, [:]) }
                    throw URLError(.timedOut)
                }
                return (200, ["code": 1])
            }
            let bundles = OnboardingBundles(onSubscriptionsChanged: {})
            bundles.feeds = [OnboardingFeed(preview: DiscoverPopularFeed(feedId: "101", feedDict: ["feed_address": "https://example.com/101"]))]
            bundles.selection = Set(bundles.feeds.map(\.url))
            bundles.folder = "Science"
            await bundles.subscribe()
            XCTAssertEqual(paths, missingEndpoint ? ["/reader/add_feeds", "/reader/add_url"] : ["/reader/add_feeds"])
            XCTAssertEqual(bundles.added.count, missingEndpoint ? 1 : 0)
            XCTAssertEqual(bundles.failedBundles.count, missingEndpoint ? 0 : 1)
        }
    }

    func test_oldServerHTMLCapabilityFallsBackBeforeAnyBatchWrite() async {
        var methods: [String] = []
        network { request in
            methods.append("\(request.httpMethod!) \(request.url!.path)")
            if request.httpMethod == "GET" { return (200, ["_test_html": "<!doctype html><html>NewsBlur</html>"]) }
            return (200, ["code": 1])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        bundles.feeds = [OnboardingFeed(preview: DiscoverPopularFeed(feedId: "101", feedDict: ["feed_address": "https://example.com/101"]))]
        bundles.selection = Set(bundles.feeds.map(\.url))
        bundles.folder = "Science"
        await bundles.subscribe()
        XCTAssertEqual(methods, ["GET /reader/add_feeds", "POST /reader/add_url"])
        XCTAssertEqual(bundles.added.count, 1)
    }

    func test_searchAdditionAndRetryPreserveExistingNestedFolder() async throws {
        var attempts: [String] = []
        var shouldFail = true
        network { request in
            attempts.append(Self.body(request).removingPercentEncoding ?? "")
            return shouldFail ? (503, ["message": "Unavailable"]) : (200, ["code": 1])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        let feed = DiscoverPopularFeed(feedId: "search", feedDict: ["feed_address": "https://example.com/science.xml"])
        let queued = try XCTUnwrap(bundles.queueSearchResult(feed, folder: "Reading ▸ Science"))
        XCTAssertTrue(bundles.queued.contains(feed.feedAddress))
        await queued.value
        shouldFail = false
        let failure = try XCTUnwrap(bundles.failedBundles.first)
        bundles.retry(failure)
        // OnboardingTests.swift waits for the retained background retry, not a second submission.
        for _ in 0..<100 where !bundles.queued.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(bundles.added.contains(feed.feedAddress))
        XCTAssertEqual(attempts.count, 2)
        XCTAssertTrue(attempts.allSatisfy { $0.contains("folder_path=[\"Reading\",\"Science\"]") && !$0.contains("new_folder") })
        XCTAssertNil(bundles.queueSearchResult(feed, folder: ""), "An added search result must not be queued twice.")
    }

    func test_queueReturnsImmediatelyKeepsFolderAndRefreshesAfterCompletion() async throws {
        var attempted: [String] = []
        var refreshes = 0
        network { request in
            if request.url?.path == "/reader/add_url" {
                attempted.append(Self.body(request))
                return (200, ["code": 1])
            }
            let source = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "type" }!.value!
            return (200, ["feeds": [["title": source, "feed_url": "https://example.com/\(source)", "feed_type": source,
                                    "favicon": Self.fixtureIcon(["rss", "newsletter", "youtube", "reddit", "podcast"].firstIndex(of: source) ?? 0), "last_story_date": Date().ISO8601Format(),
                                    "stories": Self.englishStories]]])
        }
        let bundles = OnboardingBundles(onSubscriptionsChanged: { refreshes += 1 })
        await bundles.load("Science")
        let task = try XCTUnwrap(bundles.queueSubscriptions())
        XCTAssertEqual(bundles.queued.count, 5)
        XCTAssertFalse(bundles.busy, "Queued additions must not block navigation or new previews.")
        bundles.folder = "Another folder"
        bundles.prepareToRead()
        XCTAssertEqual(refreshes, 1, "Entering completion refreshes immediately while additions are pending.")
        OnboardingFeedLoading.shared.refreshDidFinish()
        XCTAssertTrue(OnboardingFeedLoading.shared.isLoading, "An early partial refresh must not clear progress while additions are pending.")
        await task.value
        XCTAssertTrue(bundles.queued.isEmpty)
        XCTAssertEqual(attempted.count, 5)
        XCTAssertTrue(attempted.allSatisfy { $0.contains("new_folder=Science") })
        XCTAssertEqual(refreshes, 2, "Finishing the queue refreshes the newly added feeds.")
        XCTAssertTrue(OnboardingFeedLoading.shared.isLoading, "The spinner must survive the final add response until the feed list is rendered.")
        OnboardingFeedLoading.shared.refreshDidFinish()
        XCTAssertFalse(OnboardingFeedLoading.shared.isLoading)
        bundles.prepareToRead()
        XCTAssertEqual(refreshes, 3, "Start Reading refreshes again.")
    }

    func test_failedAdditionsStillRefreshAndStopLoading() async {
        network { request in
            if request.url?.path == "/reader/add_url" { return (503, ["message": "Unavailable"]) }
            return (200, ["feeds": (0..<5).map { index in
                ["feed_url": "https://example.com/rss\(index)", "title": "Example", "favicon": Self.fixtureIcon(index), "last_story_date": Date().ISO8601Format(),
                 "stories": Self.englishStories] as [String: Any]
            }])
        }
        var refreshes = 0
        let bundles = OnboardingBundles(onSubscriptionsChanged: {
            refreshes += 1
            OnboardingFeedLoading.shared.refreshDidFinish()
        })
        await bundles.load("Science")
        await bundles.subscribe()
        XCTAssertEqual(refreshes, 1)
        XCTAssertFalse(OnboardingFeedLoading.shared.isLoading)
        XCTAssertEqual(bundles.failedBundles.count, 1)
    }

    nonisolated private static var englishStories: [[String: Any]] {
        ["How to make a delicious vegetable soup for dinner",
         "The best recipes for a delicious dinner with your family",
         "Simple cooking techniques that make your favorite meals taste better"].map { ["story_title": $0] }
    }

    func test_opmlUploadPreservesDocumentAndHandlesQueuedResponse() async throws {
        let xml = "<?xml version=\"1.0\"?><opml version=\"2.0\"><body><outline text=\"Science\"><outline text=\"Space\"><outline text=\"Orbit\" xmlUrl=\"https://example.com/rss\"/></outline></outline><outline text=\"Daily\" xmlUrl=\"https://example.com/daily\"/></body></opml>"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".opml")
        try Data(xml.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        network { request in
            XCTAssertEqual(request.url?.path, "/import/opml_upload")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = Self.body(request)
            XCTAssertTrue(body.contains("name=\"file\""))
            XCTAssertTrue(body.contains(xml))
            return (200, ["code": 2, "payload": ["delayed": true, "feed_count": 2]])
        }
        let receipt = try await OnboardingAPI.importOPML(url)
        XCTAssertEqual(receipt.count, 2)
        let bundles = OnboardingBundles(onSubscriptionsChanged: {})
        bundles.recordImport(receipt)
        XCTAssertEqual(bundles.folderSummaries.map(\.title), ["All Site Stories", "Science ▸ Space"])
        XCTAssertEqual(bundles.folderSummaries.last?.feeds.first?.feedTitle, "Orbit")
        XCTAssertEqual(bundles.summaryFeedCount, 2)
        bundles.recordImport(receipt)
        XCTAssertEqual(bundles.summaryFeedCount, 2, "Importing the same export again must not duplicate its recap.")
    }

    func test_invalidOPMLNeverUploads() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xml")
        try Data("<html>Not an export</html>".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        network { _ in XCTFail("Invalid files must not be uploaded"); return (200, [:]) }
        do { _ = try await OnboardingAPI.importOPML(url); XCTFail("Expected rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("OPML")) }
    }

    func test_authenticationContinuationRetainsTicketButOtherErrorsThrow() async throws {
        network { _ in (400, ["code": -1, "link_required": true, "ticket": "replacement-ticket"]) }
        let result = try await OnboardingAPI.request("/api/social/complete", body: [:])
        XCTAssertEqual(result["ticket"] as? String, "replacement-ticket")
        network { _ in (503, ["code": -1, "message": "Unavailable"]) }
        do { _ = try await OnboardingAPI.request("/api/social/start", body: [:]); XCTFail("Expected server error") }
        catch { XCTAssertEqual(error.localizedDescription, "Unavailable") }
    }

    nonisolated private static func fixtureIcon(_ index: Int) -> String {
        let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: CGFloat((index * 37) % 251) / 255,
                                    green: CGFloat((index * 97) % 241) / 255, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 3 + index % 5, y: 4, width: 5, height: 8))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return (data as Data).base64EncodedString()
    }

    nonisolated private static func iconResponse(_ request: URLRequest, generation: Int = 0) -> [String: Any] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
        return items.filter { $0.name == "feed_ids" }.reduce(into: [:]) { response, item in
            if let id = item.value { response[id] = fixtureIcon((Int(id) ?? 0) + generation * 173) }
        }
    }

    nonisolated private static func body(_ request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private final class OnboardingURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: Any]))?
    static var deferredHandler: ((URLRequest, @escaping (Int, [String: Any]) -> Void) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let deferred = Self.deferredHandler {
            deferred(request) { [self] status, json in finish(status, json: json) }
            return
        }
        do {
            let (status, json) = try Self.handler!(request)
            finish(status, json: json)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    private func finish(_ status: Int, json: [String: Any]) {
        do {
            let html = json["_test_html"] as? String
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": html == nil ? "application/json" : "text/html"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try html.map { Data($0.utf8) } ?? JSONSerialization.data(withJSONObject: json))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class OnboardingHeldRequests {
    private let lock = NSLock()
    private var pending: [String: (Int, [String: Any]) -> Void] = [:]
    var count: Int { lock.lock(); defer { lock.unlock() }; return pending.count }
    func hold(_ source: String, completion: @escaping (Int, [String: Any]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        pending[source] = completion
    }
    func respond(_ source: String, json: [String: Any]) {
        lock.lock()
        let completion = pending.removeValue(forKey: source)
        lock.unlock()
        completion?(200, json)
    }
}

private final class OnboardingRefreshAppDelegate: NewsBlurAppDelegate {
    var responses: [(URLSessionDataTask?, Any?) -> Void] = []
    var failures: [(URLSessionDataTask?, Error?) -> Void] = []
    override func cancelOfflineQueue() {}
    override var url: String! { "https://onboarding-refresh.invalid" }
    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        responses.append(success)
        failures.append(failure)
    }
}

private final class OnboardingRefreshFeedsController: FeedsObjCViewController {
    var appliedMarkers: [String] = []
    var loadingWhenShowingError: [Bool] = []
    @objc(finishedWithError:statusCode:) func finishedWithError(_ error: NSError, statusCode: Int) {
        loadingWhenShowingError.append(OnboardingFeedLoading.shared.isLoading)
    }
    // OnboardingTests.swift observes the real fetchFeedList callback without unrelated feed rendering setup.
    @objc func finishLoadingFeedList(_ results: NSDictionary) {
        appliedMarkers.append(results["marker"] as! String)
    }
}
