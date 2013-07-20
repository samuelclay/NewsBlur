//
//  UIActivitiesControl.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/19/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIActivitiesControl : NSObject

@property (nonatomic, retain) UIPopoverController *popover;

+ (void)showActivitiesInView:(UIViewController *)vc;
+ (void)showActivitiesInView:(UIViewController *)vc withUrl:(NSURL *)url;

@end
