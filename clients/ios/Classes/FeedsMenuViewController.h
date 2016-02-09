//
//  FeedsMenuViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/19/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FeedsMenuViewController : UIViewController 
<UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    UIAlertView *loginAsAlert;
}

@property (nonatomic, strong) NSArray *menuOptions;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITableView *menuTableView;
@property (nonatomic) IBOutlet UIAlertView *loginAsAlert;
@property (nonatomic) IBOutlet UISegmentedControl *themeSegmentedControl;

- (IBAction)changeTheme:(id)sender;

@end
