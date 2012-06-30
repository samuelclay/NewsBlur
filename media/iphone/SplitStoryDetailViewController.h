//
//  DetailViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/9/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MGSplitViewController.h"

@class NewsBlurAppDelegate;

@interface SplitStoryDetailViewController : UIViewController <MGSplitViewControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet MGSplitViewController *splitController;

}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) UIPopoverController *popoverController;

- (void)onFingerSwipeLeft;
- (void)onFingerSwipeRight;

@end
