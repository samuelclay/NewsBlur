//
//  FTUXAddFriendsViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NewsBlurAppDelegate.h"

@class ASIHTTPRequest;

@interface FirstTimeUserAddFriendsViewController  : UIViewController <ASIHTTPRequestDelegate, UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *facebookButton;
@property (weak, nonatomic) IBOutlet UIButton *twitterButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *facebookActivityIndicator;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *twitterActivityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *friendsLabel;

- (IBAction)tapNextButton;
- (IBAction)tapTwitterButton;
- (IBAction)tapFacebookButton;
- (void)selectTwitterButton;
- (void)selectFacebookButton;
- (IBAction)toggleAutoFollowFriends:(id)sender;

- (void)connectToSocial;
- (void)finishConnectFromSocial:(ASIHTTPRequest *)request;

- (void)finishTwitterConnect;
- (void)finishFacebookConnect;

- (void)finishedWithError:(ASIHTTPRequest *)request;
- (void)finishToggleAutoFollowFriends:(ASIHTTPRequest *)request;

- (void)changeMessaging:(NSString *)msg;

@end