import UIKit
import WebKit
import XCTest

// NewsBlurTestsObserver.swift is the NewsBlurTests bundle's principal class. It keeps one small rendered WKWebView
// alive for the whole run so WebKit's GPU process never idle-exits between tests. Tests create and release web views
// constantly, so without a lasting client that process exited and relaunched up to 27 times per CI run, and a web
// view that started loading while it exited could wait more than a minute for its bundled fonts.
@objc(NewsBlurTestsObserver)
final class NewsBlurTestsObserver: NSObject, XCTestObservation {
    private var keepAliveWindow: UIWindow?

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        MainActor.assumeIsolated { startWebKitKeepAlive() }
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        MainActor.assumeIsolated {
            keepAliveWindow?.isHidden = true
            keepAliveWindow = nil
        }
    }

    @MainActor private func startWebKitKeepAlive() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        // NewsBlurTestsObserver.swift keeps this window below the app and every fixture window, never key, and too small
        // to receive touches, so tests that look up the key window or snapshot their own windows never see it.
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.isUserInteractionEnabled = false
        let root = UIViewController()
        let web = WKWebView(frame: window.bounds, configuration: WKWebViewConfiguration())
        root.view.addSubview(web)
        window.rootViewController = root
        window.isHidden = false
        web.loadHTMLString("<html><body style=\"margin:0;background:#fff\">.</body></html>", baseURL: nil)
        keepAliveWindow = window
    }
}
