//
//  NewsBlurUITestHarness.swift
//  NewsBlur
//
//  Created by Codex on 2026-04-05.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 16.0, *)
@MainActor
final class NewsBlurUITestHarness {
    private enum LaunchArgument {
        static let enabled = "-newsblur-ui-testing"
        static let screen = "-newsblur-ui-test-screen"
    }

    private static var didScheduleScenario = false

    static func configureIfNeeded(appDelegate: NewsBlurAppDelegate) {
        guard isEnabled, !didScheduleScenario else { return }

        UIView.setAnimationsEnabled(false)

        switch requestedScreen {
        case "add-site":
            didScheduleScenario = true
            AddSiteSheetViewController.viewModelFactory = { makeAddSiteViewModel() }
            presentAddSite(on: appDelegate, remainingRetries: 20)
        default:
            break
        }
    }

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(LaunchArgument.enabled)
    }

    private static var requestedScreen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: LaunchArgument.screen) else { return nil }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }

        return arguments[valueIndex]
    }

    private static func presentAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            retryPresentingAddSite(on: appDelegate, remainingRetries: remainingRetries)
            return
        }
        guard feedsNavigationController.presentedViewController == nil else {
            retryPresentingAddSite(on: appDelegate, remainingRetries: remainingRetries)
            return
        }

        let addSiteViewController = AddSiteSheetViewController()
        addSiteViewController.shouldReloadFeedsOnSuccess = false

        let navigationController = UINavigationController(rootViewController: addSiteViewController)
        navigationController.modalPresentationStyle = .pageSheet
        navigationController.navigationBar.isHidden = true

        if let sheet = navigationController.sheetPresentationController {
            let smallDetent = UISheetPresentationController.Detent.custom(identifier: .init("addSiteSmall")) { _ in
                200.0
            }
            sheet.detents = [smallDetent, .medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.preferredCornerRadius = 12.0
            addSiteViewController.setSheetController(sheet)
        }

        feedsNavigationController.present(navigationController, animated: false)
    }

    private static func retryPresentingAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentAddSite(on: appDelegate, remainingRetries: remainingRetries - 1)
        }
    }

    private static func makeAddSiteViewModel() -> AddSiteViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AddSiteUITestURLProtocol.self]

        return AddSiteViewModel(
            appEnvironment: AddSiteUITestEnvironment(),
            session: URLSession(configuration: configuration)
        )
    }
}

private final class AddSiteUITestEnvironment: AddSiteViewModelAppEnvironment {
    let url: String? = "https://ui-test.newsblur.example"
    let dictFoldersArray: Any? = [
        "Tech",
        "Tech \u{25B8} Swift"
    ]
}

private final class AddSiteUITestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try mockedResponse(for: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func mockedResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

        switch url.path {
        case "/rss_feeds/feed_autocomplete":
            let term = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "term" })?
                .value ?? ""
            let payload: [String: Any] = [
                "term": term,
                "feeds": [
                    [
                        "feed_title": "Swift UI Test Feed",
                        "feed_address": "https://ui-test.newsblur.example/swift.xml",
                        "num_subscribers": 42,
                        "last_story_seconds_ago": 3600
                    ],
                    [
                        "feed_title": "Engineering UI Test Feed",
                        "feed_address": "https://ui-test.newsblur.example/engineering.xml",
                        "num_subscribers": 17,
                        "last_story_seconds_ago": 7200
                    ]
                ]
            ]
            return (response, try JSONSerialization.data(withJSONObject: payload))
        case "/reader/add_url":
            let payload: [String: Any] = ["code": 1]
            return (response, try JSONSerialization.data(withJSONObject: payload))
        default:
            throw URLError(.unsupportedURL)
        }
    }
}
