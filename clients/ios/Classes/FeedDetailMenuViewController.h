//
//  FeedDetailMenuViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FeedDetailMenuViewController : UIViewController
<UITableViewDelegate,
UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic, strong) NSArray *menuOptions;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITableView *menuTableView;
@property (nonatomic) IBOutlet UISegmentedControl *orderSegmentedControl;
@property (nonatomic) IBOutlet UISegmentedControl *readFilterSegmentedControl;
@property (nonatomic) IBOutlet UISegmentedControl *themeSegmentedControl;

- (void)buildMenuOptions;
- (UITableViewCell *)makeOrderCell;
- (UITableViewCell *)makeReadFilterCell;
- (IBAction)changeOrder:(id)sender;
- (IBAction)changeReadFilter:(id)sender;
- (IBAction)changeTheme:(id)sender;

@end
