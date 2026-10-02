import UIKit
import WebKit
import XCTest

@MainActor final class Test_StoryURLContrast: XCTestCase, WKNavigationDelegate {
    private var navigationFinished: XCTestExpectation?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationFinished?.fulfill()
        navigationFinished = nil
    }

    func test_grayThemeURLClassifiersRemainReadable() async throws {
        let base = try css("storyDetailView")
        let theme = try css("storyDetailViewMedium")
        let controller = UIViewController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        let web = WKWebView(frame: window.bounds)
        controller.view.addSubview(web)
        web.navigationDelegate = self
        let ready = expectation(description: "URL classifier fixture rendered")
        navigationFinished = ready
        let rows = [1, -1].map { score in
            """
            <div class="NB-story-url-match"><span class="NB-story-url NB-score-\(score)">
            <span class="NB-story-url-label">URL: </span><span class="NB-story-url-before">https://www.tomshardware.com/</span><span class="NB-story-url-matched">pc-components</span><span class="NB-story-url-after">/dram/micron-announces...</span>
            </span></div>
            """
        }.joined()
        web.loadHTMLString("""
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>\(base)</style><style>\(theme)</style></head>
        <body><div class="NB-header"><div class="NB-story-title">Tom's Hardware: Micron announces new memory modules</div>\(rows)</div></body></html>
        """, baseURL: Bundle.main.bundleURL)
        await fulfillment(of: [ready], timeout: 10)
        let styles = try await web.evaluateJavaScript("""
        Array.from(document.querySelectorAll('.NB-story-url')).map(pill => ({
          score: pill.className,
          background: getComputedStyle(pill).backgroundColor,
          colors: Array.from(pill.children).map(child => ({name: child.className, color: getComputedStyle(child).color}))
        }))
        """) as! [[String: Any]]
        try await Task.sleep(nanoseconds: 300_000_000)
        let snapshot = try await web.takeSnapshot(configuration: nil)
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "gray-theme-positive-and-negative-url-matches"
        attachment.lifetime = .keepAlways
        add(attachment)
        for style in styles {
            let fill = try rgba(style["background"] as! String)
            // StoryURLContrastTests.swift checks both ends of storyDetailViewMedium.css's header gradient.
            for gray in [64.0 / 255, 96.0 / 255] {
                let background = (0..<3).map { fill[$0] * fill[3] + gray * (1 - fill[3]) }
                for element in style["colors"] as! [[String: String]] {
                    let foreground = try rgba(element["color"]!)
                    let foregroundLuminance = luminance(Array(foreground.prefix(3)))
                    let backgroundLuminance = luminance(background)
                    let ratio = (max(foregroundLuminance, backgroundLuminance) + 0.05) /
                        (min(foregroundLuminance, backgroundLuminance) + 0.05)
                    XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(style["score"]!): \(element["name"]!) contrast \(ratio)")
                }
            }
        }
    }

    private func css(_ name: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "css"))
        return try String(contentsOf: path)
    }

    private func rgba(_ css: String) throws -> [Double] {
        let pattern = try NSRegularExpression(pattern: #"[\d.]+"#)
        var components = pattern.matches(in: css, range: NSRange(css.startIndex..., in: css)).map {
            Double((css as NSString).substring(with: $0.range))!
        }
        XCTAssertGreaterThanOrEqual(components.count, 3)
        for index in 0..<3 { components[index] /= 255 }
        if components.count == 3 { components.append(1) }
        return components
    }

    private func luminance(_ rgb: [Double]) -> Double {
        let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
