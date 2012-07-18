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
    
    UILabel *interactionsLabel;
    UILabel *activitesLabel;
    InteractionsModule *interactionsModule;
    ActivityModule *activitiesModule;
    UIImageView *header;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UILabel *interactionsLabel;
@property (nonatomic) IBOutlet UILabel *activitesLabel;
@property (nonatomic) IBOutlet InteractionsModule *interactionsModule;
@property (nonatomic) IBOutlet ActivityModule *activitiesModule;
@property (nonatomic) IBOutlet UIImageView *header;

- (IBAction)doLogout:(id)sender;
- (void)refreshInteractions;
- (void)refreshActivity;
- (void)finishLoadInteractions:(ASIHTTPRequest *)request;
- (void)finishLoadActivities:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)repositionDashboard;
@end
