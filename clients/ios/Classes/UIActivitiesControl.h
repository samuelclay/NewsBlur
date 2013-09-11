//
//  UIActivitiesControl.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/19/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UIActivityViewController;

@interface UIActivitiesControl : NSObject

@property (nonatomic, retain) UIPopoverController *popover;

+ (UIActivityViewController *)activityViewControllerForView:(UIViewController *)vc;
+ (UIActivityViewController *)activityViewControllerForView:(UIViewController *)vc withUrl:(NSURL *)url;

@end
