//
//  FTUXaddSitesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface FirstTimeUserAddSitesViewController  : UIViewController <ASIHTTPRequestDelegate, UITableViewDataSource, UITableViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIButton *googleReaderButton;
@property (nonatomic) IBOutlet UIView *googleReaderButtonWrapper;
@property (nonatomic) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic) IBOutlet UILabel *instructionLabel;
@property (nonatomic) IBOutlet UITableView *categoriesTable;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

- (IBAction)tapNextButton;
- (IBAction)tapGoogleReaderButton;
- (IBAction)tapCategoryButton:(id)sender;


- (void)addCategory:(id)sender;
- (void)importFromGoogleReader;
- (void)importFromGoogleReaderFailed:(NSString *)error;
- (void)updateSites;

- (CGFloat)tableViewHeight;
@end