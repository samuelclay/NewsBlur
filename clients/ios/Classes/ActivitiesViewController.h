//
//  ActivitiesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ActivitiesNavigationBar.h"

@class NewsBlurAppDelegate;
@class InteractionsModule;
@class ActivityModule;
@class FeedbackModule;
@class FeedDetailViewController;

@interface ActivitiesViewController : UIViewController <UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    InteractionsModule *interactionsModule;
    ActivityModule *activitiesModule;
    UIToolbar *toolbar;
    ActivitiesNavigationBar *topToolbar;
    UISegmentedControl *segmentedButton;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet InteractionsModule *interactionsModule;
@property (nonatomic) IBOutlet ActivityModule *activitiesModule;

@property (nonatomic) IBOutlet ActivitiesNavigationBar *topToolbar;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UISegmentedControl *segmentedButton;
@property (nonatomic) IBOutlet UIImageView *logoImageView;

- (IBAction)doLogout:(id)sender;
- (void)refreshInteractions;
- (void)refreshActivity;
- (IBAction)tapSegmentedButton:(id)sender;
- (void)updateTheme;

@end
