//
//  FontPopover.h
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012-2015 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FontSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UISegmentedControl *fontSizeSegment;
@property (nonatomic) IBOutlet UISegmentedControl *lineSpacingSegment;
@property (nonatomic) IBOutlet UISegmentedControl *themeSegment;
@property (nonatomic) IBOutlet UITableView *menuTableView;

- (IBAction)changeFontSize:(id)sender;
- (IBAction)changeLineSpacing:(id)sender;
- (IBAction)changeTheme:(id)sender;

@end
