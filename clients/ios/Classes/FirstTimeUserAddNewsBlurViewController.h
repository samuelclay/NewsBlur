//
//  FTUXAddNewsBlurViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface FirstTimeUserAddNewsBlurViewController  : BaseViewController {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *nextButton;
@property (strong, nonatomic) IBOutlet UILabel *instructionsLabel;

- (IBAction)tapNextButton;
- (IBAction)tapNewsBlurButton:(id)sender;
- (IBAction)tapPopularButton:(id)sender;

- (void)addSite:(NSString *)siteUrl;
- (void)addPopular;
@end
