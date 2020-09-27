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
        guard let pageViewController = pageViewController as? VerticalPageViewController, let detailViewController = pageViewController.detailViewController else {
            return nil
        }
        
        return detailViewController.previousPage
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = pageViewController as? VerticalPageViewController, let detailViewController = pageViewController.detailViewController else {
            return nil
        }
        
        return detailViewController.nextPage
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

extension VerticalPageDelegate: UIPageViewControllerDelegate {
    
}
