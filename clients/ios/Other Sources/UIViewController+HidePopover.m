//
//  UIViewController+Dismiss.m
//  NewsBlur
//
//  Created by Nicholas Riley on 3/19/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "UIViewController+HidePopover.h"
#import "NewsBlurAppDelegate.h"

@implementation UIViewController (HidePopover)

- (void)hidePopover {
    [(NewsBlurAppDelegate *)[UIApplication sharedApplication].delegate hidePopover];
}

@end
