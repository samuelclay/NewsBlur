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
        page?.receiveStoryReadyMessage(message)
    }
}

/// An individual story.
class StoryDetailViewController: StoryDetailObjCViewController {
    /// Convenience initializer to load a new instance of this class from the XIB.
    ///
    /// - Parameter pageIndex: The page index of the story.
    convenience init(pageIndex: Int) {
        self.init(nibName: "StoryDetailViewController", bundle: nil)
        
        self.appDelegate = NewsBlurAppDelegate.shared()
        self.pageIndex = pageIndex
    }
}
