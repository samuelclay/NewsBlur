//
//  FirstTimeUserViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface FirstTimeUserViewController : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    NSMutableArray *categories;
    int currentStep;
    int importedGoogle;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) NSMutableArray *categories;
@property (retain, nonatomic) IBOutlet UIButton *googleReaderButton;
@property (retain, nonatomic) IBOutlet UIView *welcomeView;
@property (retain, nonatomic) IBOutlet UIView *addSitesView;
@property (retain, nonatomic) IBOutlet UIView *addFriendsView;
@property (retain, nonatomic) IBOutlet UIView *addNewsBlurView;
@property (retain, nonatomic) IBOutlet UIToolbar *toolbar;
@property (retain, nonatomic) IBOutlet UIButton *toolbarTitle;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *nextButton;

- (IBAction)tapNextButton;
- (IBAction)tapGoogleReaderButton;
- (IBAction)tapCategoryButton:(id)sender;

- (void)addCategories;
- (void)finishAddFolder:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;

@end
