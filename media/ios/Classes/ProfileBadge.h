//
//  ProfileBadge.h
//  NewsBlur
//
//  Created by Roy Yang on 7/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface ProfileBadge : UIView {
    NewsBlurAppDelegate *appDelegate;
    
    UIImageView *UserAvatar;
    UILabel *username;
    UILabel *userLocation;
    UILabel *userDescription;
    UILabel *userStats;
    UIButton *followButton;
    NSDictionary *activeProfile;
    
    UIActivityIndicatorView *activityIndicator;
}

@property (nonatomic, retain) NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) UIImageView *userAvatar;
@property (retain, nonatomic) UILabel *username;
@property (retain, nonatomic) UILabel *userLocation;
@property (retain, nonatomic) UILabel *userDescription;
@property (retain, nonatomic) UILabel *userStats;
@property (retain, nonatomic) UIButton *followButton;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

@property (retain, nonatomic) NSDictionary *activeProfile;


- (void)refreshWithProfile:(NSDictionary *)profile;

- (IBAction)doFollowButton:(id)sender;
- (void)finishFollowing:(ASIHTTPRequest *)request;
- (void)finishUnfollowing:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)initProfile;

@end
