//
//  DetailViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/9/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;


@end
