//
//  StoryPagesViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import WidgetKit

/// StoryPagesViewController.swift mirrors horizontal story paging for a right-to-left language, so the next story
/// slides in from the left, beside the "Next" chevron that points left there. StoryPagesObjCViewController.m keeps
/// placing each story at its location from the left edge of the pager's content; flipping the pager's scroll view
/// (and each page back, so its text still reads normally) mirrors what is shown and the direction a swipe pages,
/// without changing any page index, content offset or story location math. Left-to-right paging and vertical
/// paging keep the identity transform.
@objcMembers final class StoryPagerDirection: NSObject {
    static func mirrorsPages(horizontal: Bool, rightToLeft: Bool) -> Bool {
        horizontal && rightToLeft
    }

    static func pagerTransform(horizontal: Bool, rightToLeft: Bool) -> CGAffineTransform {
        mirrorsPages(horizontal: horizontal, rightToLeft: rightToLeft) ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }

    /// StoryPagesViewController.swift moves a page's view only when its transform changes; flipping about the center
    /// keeps the frame StoryPagesObjCViewController.m assigned.
    static func apply(_ transform: CGAffineTransform, to view: UIView?) {
        guard let view, view.transform != transform else { return }
        view.transform = transform
    }

    /// StoryPagesViewController.swift reports which screen edge leads in the interface direction, for the edge swipe
    /// that reveals the story titles beside the reader.
    static func leadingScreenEdge(rightToLeft: Bool) -> UIRectEdge {
        rightToLeft ? .right : .left
    }

    /// StoryPagesViewController.swift measures a swipe's velocity away from the leading edge, so a right-to-left
    /// interface reveals and goes back with a leftward swipe.
    static func velocityAwayFromLeadingEdge(_ velocity: CGPoint, rightToLeft: Bool) -> CGFloat {
        rightToLeft ? -velocity.x : velocity.x
    }
}

/// Manages story pages, containing the previous, current, and next stories.
class StoryPagesViewController: StoryPagesObjCViewController {
    /// Convenience initializer to load a new instance of this class from the XIB.
    convenience init() {
        self.init(nibName: "StoryPagesViewController", bundle: nil)
        
        self.appDelegate = NewsBlurAppDelegate.shared()
    }
    
    /// Reload the widget timeline.
    @objc func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
#if targetEnvironment(macCatalyst)
    @objc func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if [.storyPagesSettings, .storyPagesBrowser].contains(item.itemIdentifier) {
            return self.isStoryShown
        } else {
            return true
        }
    }
#endif
}
