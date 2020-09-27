//
//  HorizontalPageDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-09-24.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

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

/// Delegate and data source of the story horizontal page view controller.
class HorizontalPageDelegate: NSObject {
}

extension HorizontalPageDelegate: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = pageViewController as? HorizontalPageViewController, let detailViewController = pageViewController.detailViewController, let verticalViewController = Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController else {
            return nil
        }
        
        verticalViewController.setViewControllers([detailViewController.previousPage], direction: .reverse, animated: false, completion: nil)
        
        //TODO: *** TO BE IMPLEMENTED *** CATALYST: set up the page controller
        
        return verticalViewController
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = pageViewController as? HorizontalPageViewController, let detailViewController = pageViewController.detailViewController, let verticalViewController = Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController else {
            return nil
        }
        
        verticalViewController.setViewControllers([detailViewController.nextPage], direction: .forward, animated: false, completion: nil)
        
        //TODO: *** TO BE IMPLEMENTED *** CATALYST: set up the page controller
        
        return verticalViewController
    }
    
    // Don't want the page dots.
//    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
//        //TODO: *** TO BE IMPLEMENTED *** CATALYST
//
//        return 1
//    }
//
//    func presentationCount(for pageViewController: UIPageViewController) -> Int {
//        //TODO: *** TO BE IMPLEMENTED *** CATALYST
//
//        return 10
//    }
}

extension HorizontalPageDelegate: UIPageViewControllerDelegate {
    
}
