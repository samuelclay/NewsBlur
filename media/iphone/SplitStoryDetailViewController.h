//
//  DetailViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/9/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface SplitStoryDetailViewController : UIViewController <UISplitViewControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;

- (void)showPopover;

@end
