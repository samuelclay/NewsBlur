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
    
    MGSplitViewController *splitController;
    UIToolbar *bottomToolbar;
    UIScrollView *scrollView;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) UIPopoverController *popoverController;

@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
@property (retain, nonatomic) IBOutlet UIToolbar *bottomToolbar;


- (void)onFingerSwipeLeft;
- (void)onFingerSwipeRight;
- (IBAction)doLogoutButton:(id)sender;

@end
