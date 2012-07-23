//
//  StoryDetailContainerViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/23/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface StoryDetailContainerViewController : UIViewController <UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    UIBarButtonItem *toggleViewButton;
    UIPopoverController *popoverController;    
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *toggleViewButton;
@property (nonatomic) UIPopoverController *popoverController;

- (void)toggleView;
- (IBAction)toggleFontSize:(id)sender;

@end
