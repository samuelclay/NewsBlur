//
//  FeedsMenuViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/19/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;

@interface FeedsMenuViewController : UIViewController 
                                    <ASIHTTPRequestDelegate, 
                                    UITableViewDelegate, 
                                    UITableViewDataSource,
                                    UIAlertViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) NSArray *menuOptions;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property ( nonatomic) IBOutlet UITableView *menuTableView;

- (IBAction)tapCancelButton:(UIBarButtonItem *)sender;
- (void)finishedWithError:(ASIHTTPRequest *)request;

@end
