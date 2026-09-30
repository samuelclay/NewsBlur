//
//  StoryDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import WebKit

/// StoryDetailObjCViewController.m installs this bridge without retaining its page through WebKit.
@objc(StoryReadyMessageHandler)
final class StoryReadyMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var page: StoryDetailObjCViewController?

    @objc(initWithPage:)
    init(page: StoryDetailObjCViewController) {
        self.page = page
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "newsblurStoryImage" {
            (page as? StoryDetailViewController)?.receiveImageMessage(message)
        } else {
            page?.receiveStoryReadyMessage(message)
        }
    }
}

/// An individual story.
class StoryDetailViewController: StoryDetailObjCViewController {
    var openingImage = false
    private var imageLongPressStartedDuringScroll = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressImage(_:)))
        longPress.delegate = self
        longPress.cancelsTouchesInView = false
        // StoryDetailViewController.swift preserves WebKit text selection while giving images their own preview.
        for case let tap as UITapGestureRecognizer in webView.gestureRecognizers ?? [] where tap.numberOfTapsRequired == 1 {
            tap.require(toFail: longPress)
        }
        webView.addGestureRecognizer(longPress)
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer {
            imageLongPressStartedDuringScroll = webView.scrollView.isDragging || webView.scrollView.isDecelerating
        }
        return super.gestureRecognizer(gestureRecognizer, shouldReceive: touch)
    }

    @objc func longPressImage(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, !imageLongPressStartedDuringScroll,
              canOpenStoryImage(accessibility: true), presentedViewController == nil else { return }
        let point = gesture.location(in: webView)
        let offset = webView.scrollView.contentOffset
        webView.evaluateJavaScript("newsblurOpenImageAt(\(point.x), \(point.y), \(offset.x), \(offset.y), \(webView.bounds.width), true)")
    }
    /// Convenience initializer to load a new instance of this class from the XIB.
    ///
    /// - Parameter pageIndex: The page index of the story.
    convenience init(pageIndex: Int) {
        self.init(nibName: "StoryDetailViewController", bundle: nil)
        
        self.appDelegate = NewsBlurAppDelegate.shared()
        self.pageIndex = pageIndex
    }
}
