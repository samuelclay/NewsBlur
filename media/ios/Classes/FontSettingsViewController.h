//
//  FontPopover.h
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FontSettingsViewController : UIViewController
<UITableViewDelegate,
UITableViewDataSource>  {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UILabel *smallFontSizeLabel;
    IBOutlet UILabel *largeFontSizeLabel;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property ( nonatomic) IBOutlet UISegmentedControl *fontStyleSegment;
@property ( nonatomic) IBOutlet UISegmentedControl *fontSizeSegment;
@property (nonatomic) IBOutlet UITableView *menuTableView;

- (IBAction)changeFontStyle:(id)sender;
- (IBAction)changeFontSize:(id)sender;
- (void)setSanSerif;
- (void)setSerif;
- (UITableViewCell *)makeFontSelectionTableCell;
- (UITableViewCell *)makeFontSizeTableCell;

@end
