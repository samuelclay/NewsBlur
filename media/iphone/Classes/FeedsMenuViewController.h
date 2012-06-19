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
    IBOutlet UIToolbar *toolbar;
    IBOutlet UITableView *tableView;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) NSArray *menuOptions;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (retain, nonatomic) IBOutlet UITableView *tableView;

- (IBAction)tapCancelButton:(UIBarButtonItem *)sender;

- (void)finishedWithError:(ASIHTTPRequest *)request;

@end
