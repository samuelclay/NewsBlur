//
//  DashboardViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;
@class InteractionsModule;
@class ActivityModule;

@interface DashboardViewController : UIViewController <UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    InteractionsModule *interactionsModule;
    ActivityModule *activitiesModule;
    UIToolbar *toolbar;
    UISegmentedControl *segmentedButton;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet InteractionsModule *interactionsModule;
@property (nonatomic) IBOutlet ActivityModule *activitiesModule;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UISegmentedControl *segmentedButton;

- (IBAction)doLogout:(id)sender;
- (void)refreshInteractions;
- (void)refreshActivity;
- (void)finishLoadActivities:(ASIHTTPRequest *)request;
- (IBAction)tapSegmentedButton:(id)sender;
- (void)requestFailed:(ASIHTTPRequest *)request;
@end
