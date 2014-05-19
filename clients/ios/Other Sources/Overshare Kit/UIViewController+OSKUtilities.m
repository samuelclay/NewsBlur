//
//  UIViewController+OSKUtilities.m
//  Overshare
//
//  Created by Jared Sinclair on 10/16/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "UIViewController+OSKUtilities.h"

@implementation UIViewController (OSKUtilities)

+ (UIViewController *)osk_parentMostViewControllerForPresentingViewController:(UIViewController *)presentingVC {
    UIViewController *parentMostVC = presentingVC;
    UIViewController *nextViewController = presentingVC;
    while (nextViewController.parentViewController != nil) {
        nextViewController = nextViewController.parentViewController;
        if (nextViewController) {
            parentMostVC = nextViewController;
        }
    }
    return parentMostVC;
}

@end
