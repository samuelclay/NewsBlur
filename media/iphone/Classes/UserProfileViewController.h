//
//  UserProfileViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;
@class SocialBadge;

@interface UserProfileViewController : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UILabel *followingCount;
    UILabel *followersCount;
    SocialBadge *socialBadge;
}

@property (retain, nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) IBOutlet SocialBadge *socialBadge;

@property (retain, nonatomic) IBOutlet UILabel *followingCount;
@property (retain, nonatomic) IBOutlet UILabel *followersCount;

- (IBAction)doFollowButton:(id)sender;
- (void)getUserProfile;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setupModal;
- (void)doCancelButton;
    
@end
