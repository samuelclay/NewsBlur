//
//  FirstTimeUserViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FirstTimeUserViewController : UIViewController

- (IBAction)tapGoogleReaderButton;
- (IBAction)tapAddSitesButton;
- (IBAction)tapCategoriesButton:(id)sender;

@property (retain, nonatomic) IBOutlet UIView *categoriesView;
@property (retain, nonatomic) IBOutlet UIButton *browseCategoriesButton;
@property (retain, nonatomic) IBOutlet UIButton *googleReaderButton;
@property (retain, nonatomic) IBOutlet UIButton *addSitesButton;

@end
