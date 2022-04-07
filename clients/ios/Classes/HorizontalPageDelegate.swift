//
//  HorizontalPageDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-09-24.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit


// NOTE: This isn't currently used, but may be for #1351 (gestures in vertical scrolling).


//#warning("hack: this function is just for testing")
//func storyViewController() -> OriginalStoryViewController {
//    let viewController = OriginalStoryViewController()
//
//    if let appDelegate = UIApplication.shared.delegate as? NewsBlurAppDelegate {
//        let urls = ["https://dejal.com/", "https://dejus.com/", "https://yellowcottagehomestead.com/", "https://apple.com", "https://amazon.com"]
//
//        appDelegate.activeOriginalStoryURL = URL(string: urls.randomElement() ?? "https://dejal.com/")
//    }
//
//    _ = viewController.view
//    viewController.loadInitialStory()
//
//    return viewController
//}

///// Delegate and data source of the story horizontal page view controller.
//class HorizontalPageDelegate: NSObject {
//}
//
//extension HorizontalPageDelegate: UIPageViewControllerDataSource {
//    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
//        guard let pageViewController = pageViewController as? HorizontalPageViewController, let currentViewController = viewController as? VerticalPageViewController, let detailViewController = pageViewController.detailViewController else {
//            return nil
//        }
//
//        let pageIndex = (currentViewController.pageIndex ?? -1) - 1
//        let previousViewController = detailViewController.pageIndexIsValid(pageIndex) ? Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController : nil
//
//        pageViewController.previousController = previousViewController
//        previousViewController?.horizontalPageViewController = pageViewController
//        previousViewController?.currentController = detailViewController.makeStoryController(for: pageIndex)
//
//        return previousViewController
//    }
//
//    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
//        guard let pageViewController = pageViewController as? HorizontalPageViewController, let currentViewController = viewController as? VerticalPageViewController, let detailViewController = pageViewController.detailViewController else {
//            return nil
//        }
//
//        var pageIndex = (currentViewController.pageIndex ?? -1) + 1
//
//        if pageIndex == -1 {
//            pageIndex = 0
//        }
//
//        let nextViewController = detailViewController.pageIndexIsValid(pageIndex) ? Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController : nil
//
//        pageViewController.nextController = nextViewController
//        nextViewController?.horizontalPageViewController = pageViewController
//        nextViewController?.currentController = detailViewController.makeStoryController(for: pageIndex)
//
//        return nextViewController
//    }
//}
//
//extension HorizontalPageDelegate: UIPageViewControllerDelegate {
//    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
//        guard let pageViewController = pageViewController as? HorizontalPageViewController, let detailViewController = pageViewController.detailViewController else {
//            return
//        }
//
//        detailViewController.setStoryFromScroll(false)
//    }
//}
