//
//  FTUXaddSitesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface FirstTimeUserAddSitesViewController  : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSMutableArray *categories;
@property (nonatomic) IBOutlet UIButton *googleReaderButton;
@property (nonatomic) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic) IBOutlet UILabel *instructionLabel;

- (IBAction)tapNextButton;
- (IBAction)tapGoogleReaderButton;
- (IBAction)tapCategoryButton:(id)sender;

- (void)addCategories;
- (void)importFromGoogleReader;
- (void)updateSites;
@end