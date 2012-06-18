//
//  FontPopover.h
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FontSettingsViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UILabel *smallFontSizeLabel;
    IBOutlet UILabel *largeFontSizeLabel;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UILabel *smallFontSizeLabel;
@property (nonatomic, retain) IBOutlet UILabel *largeFontSizeLabel;

- (IBAction)changeFontStyle:(id)sender;
- (IBAction)changeFontSize:(id)sender;

@end
