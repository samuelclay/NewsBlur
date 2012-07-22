//
//  FTUXAddNewsBlurViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NewsBlurAppDelegate.h"

@interface FirstTimeUserAddNewsBlurViewController  : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    NSMutableArray *categories;
    int currentStep;
    int importedGoogle;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSMutableArray *categories;
@property (nonatomic) IBOutlet UIButton *googleReaderButton;
@property (nonatomic) IBOutlet UIView *welcomeView;
@property (nonatomic) IBOutlet UIView *addSitesView;
@property (nonatomic) IBOutlet UIView *addFriendsView;
@property (nonatomic) IBOutlet UIView *addNewsBlurView;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UIButton *toolbarTitle;
@property (nonatomic) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic) IBOutlet UIImageView *logo;
@property (nonatomic) IBOutlet UIBarButtonItem *previousButton;

- (IBAction)tapNextButton;
- (IBAction)tapGoogleReaderButton;
- (IBAction)tapCategoryButton:(id)sender;
- (IBAction)tapNewsBlurButton:(id)sender;

- (void)addCategories;
- (void)selectGoogleReaderButton;
- (void)finishAddFolder:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)addSite:(NSString *)siteUrl;
- (void)rotateLogo;

@end