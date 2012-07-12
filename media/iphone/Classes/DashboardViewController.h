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

@interface DashboardViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
    UIToolbar *bottomToolbar;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) IBOutlet UIToolbar *bottomToolbar;

- (IBAction)doLogout:(id)sender;
- (void)refreshInteractions;
- (void)refreshActivity;
- (void)finishLoadInteractions:(ASIHTTPRequest *)request;
- (void)finishLoadActivities:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
@end
