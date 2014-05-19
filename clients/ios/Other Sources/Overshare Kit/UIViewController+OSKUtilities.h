//
//  UIViewController+OSKUtilities.h
//  Overshare
//
//  Created by Jared Sinclair on 10/16/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@interface UIViewController (OSKUtilities)

+ (UIViewController *)osk_parentMostViewControllerForPresentingViewController:(UIViewController *)presentingVC;

@end
