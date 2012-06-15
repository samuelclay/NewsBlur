//
//  FirstTimeUserViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface FirstTimeUserViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
    
    int currentStep;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) IBOutlet UIButton *googleReaderButton;
@property (retain, nonatomic) IBOutlet UIView *welcomeView;
@property (retain, nonatomic) IBOutlet UIView *addSitesView;
@property (retain, nonatomic) IBOutlet UIView *addFriendsView;
@property (retain, nonatomic) IBOutlet UIView *addNewsBlurView;

- (IBAction)tapNextButton:(id)sender;
- (IBAction)tapGoogleReaderButton;

@end
