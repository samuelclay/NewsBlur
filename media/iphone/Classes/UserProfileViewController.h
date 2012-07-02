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

@interface UserProfileViewController : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UIImageView *UserAvatar;
    UILabel *username;
    UILabel *userLocation;
    UILabel *userDescription;
    UILabel *userStats;
    UIButton *followButton;
    
    UILabel *followingCount;
    UILabel *followersCount;
}

@property (retain, nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) IBOutlet UIImageView *userAvatar;
@property (retain, nonatomic) IBOutlet UILabel *username;
@property (retain, nonatomic) IBOutlet UILabel *userLocation;
@property (retain, nonatomic) IBOutlet UILabel *userDescription;
@property (retain, nonatomic) IBOutlet UILabel *userStats;
@property (retain, nonatomic) IBOutlet UIButton *followButton;

@property (retain, nonatomic) IBOutlet UILabel *followingCount;
@property (retain, nonatomic) IBOutlet UILabel *followersCount;

- (IBAction)doFollowButton:(id)sender;
- (void)getUserProfile;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setupModal;
- (void)doCancelButton;
    
@end
