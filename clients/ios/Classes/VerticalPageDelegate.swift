//
//  VerticalPageDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-09-24.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Delegate and data source of the story vertical page view controller.
class VerticalPageDelegate: NSObject {
}

extension VerticalPageDelegate: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = pageViewController as? VerticalPageViewController, let currentViewController = viewController as? StoryDetailViewController, let detailViewController = pageViewController.detailViewController else {
            return nil
        }
        
        let pageIndex = currentViewController.pageIndex - 1
        let storyController = detailViewController.pageIndexIsValid(pageIndex) ? detailViewController.makeStoryController(for: pageIndex) : nil
        pageViewController.previousController = storyController
        
        return storyController
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = pageViewController as? VerticalPageViewController, let currentViewController = viewController as? StoryDetailViewController, let detailViewController = pageViewController.detailViewController else {
            return nil
        }
        
        var pageIndex = currentViewController.pageIndex + 1
        
        if pageIndex == -1 {
            pageIndex = 0
        }
        
        let storyController = detailViewController.pageIndexIsValid(pageIndex) ? detailViewController.makeStoryController(for: pageIndex) : nil
        
        pageViewController.nextController = storyController
        
        return storyController
    }
}

extension VerticalPageDelegate: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let pageViewController = pageViewController as? VerticalPageViewController, let detailViewController = pageViewController.detailViewController, let horizontalPageViewController = detailViewController.horizontalPageViewController else {
            return
        }
        
        horizontalPageViewController.setCurrentController(pageViewController)
        horizontalPageViewController.reset()
        
        detailViewController.setStoryFromScroll(false)
    }
}
