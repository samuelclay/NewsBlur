import UIKit
import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryJavaScriptReadiness: XCTestCase {
    func test_imageWithoutSourceStillSignalsReadiness() async throws {
        try await checkReadiness(failsVideoSetup: false)
    }

    func test_optionalVideoSetupFailureStillSignalsReadiness() async throws {
        try await checkReadiness(failsVideoSetup: true)
    }

    private func checkReadiness(failsVideoSetup: Bool) async throws {
        let ready = expectation(description: "Production story JavaScript signals native readiness")
        let imageRequested = expectation(description: "Image stays pending through native readiness")
        let observer = StoryJavaScriptReadinessObserver(ready: ready)
        let resource = StoryJavaScriptPendingImage(requested: imageRequested)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(observer, name: "newsblurStoryReady")
        configuration.setURLSchemeHandler(resource, forURLScheme: "nb-readiness")
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: configuration)
        web.navigationDelegate = observer
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(web)
        window.makeKeyAndVisible()
        defer {
            web.stopLoading()
            configuration.userContentController.removeScriptMessageHandler(forName: "newsblurStoryReady")
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }

        let bundle = Bundle(for: NewsBlurAppDelegate.self)
        func script(_ name: String) throws -> String {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "js"))
            return try String(contentsOf: url, encoding: .utf8)
        }
        let optionalFailure = failsVideoSetup ? """
            $.fn.fitVids = function() {
                window.nbTestVideoSetupFailed = true;
                throw new Error('Video fixture failure');
            };
            """ : ""
        // StoryJavaScriptReadinessTests.swift uses production resources and holds an image so didFinish cannot mask missing readiness.
        let html = """
            <!doctype html><html><head>
            <meta name="newsblur-story-load" content="readiness-fixture">
            <script>
            window.nbTestErrors = [];
            window.addEventListener('error', function(event) { window.nbTestErrors.push(event.message); });
            </script></head><body>
            <div class="NB-story" id="NB-story"><p>Readable article.</p>
            <img id="missing-source" alt="Image without a source">
            <img src="nb-readiness://fixture/pending.png" width="30" height="30"></div>
            <script>\(try script("zepto"))</script>
            <script>\(try script("fitvid"))</script>
            <script>\(optionalFailure)</script>
            <script>\(try script("storyDetailView"))</script>
            <script>\(try script("fastTouch"))</script>
            </body></html>
            """
        web.loadHTMLString(html, baseURL: URL(string: "nb-readiness://fixture/"))
        await fulfillment(of: [imageRequested, ready], timeout: 5)

        XCTAssertEqual(observer.tokens, ["readiness-fixture"])
        XCTAssertFalse(observer.finishedNavigation)
        XCTAssertTrue(resource.hasPendingRequest)
        let imageClass = try await web.evaluateJavaScript("document.querySelector('#missing-source').className") as? String
        XCTAssertEqual(imageClass, "NB-small-image")
        let errors = try await web.evaluateJavaScript("window.nbTestErrors") as? [String]
        if failsVideoSetup {
            let attempted = try await web.evaluateJavaScript("window.nbTestVideoSetupFailed === true") as? Bool
            XCTAssertEqual(attempted, true)
            XCTAssertEqual(errors?.count, 1)
            XCTAssertTrue(errors?.first?.contains("Video fixture failure") == true)
        } else {
            XCTAssertEqual(errors, [])
        }
    }
}

@MainActor private final class StoryJavaScriptReadinessObserver: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private let ready: XCTestExpectation
    var tokens: [String] = []
    var finishedNavigation = false

    init(ready: XCTestExpectation) { self.ready = ready }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let token = message.body as? String { tokens.append(token) }
        ready.fulfill()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedNavigation = true
    }
}

@MainActor private final class StoryJavaScriptPendingImage: NSObject, WKURLSchemeHandler {
    private let requested: XCTestExpectation
    private var task: WKURLSchemeTask?
    var hasPendingRequest: Bool { task != nil }

    init(requested: XCTestExpectation) { self.requested = requested }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        task = urlSchemeTask
        requested.fulfill()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        task = nil
    }
}
