//
//  ProfileBadge.h
//  NewsBlur
//
//  Created by Roy Yang on 7/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface ProfileBadge : UITableViewCell {
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

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property ( nonatomic) UIImageView *userAvatar;
@property ( nonatomic) UILabel *username;
@property ( nonatomic) UILabel *userLocation;
@property ( nonatomic) UILabel *userDescription;
@property ( nonatomic) UILabel *userStats;
@property ( nonatomic) UIButton *followButton;
@property (nonatomic) UIActivityIndicatorView *activityIndicator;

@property ( nonatomic) NSDictionary *activeProfile;


- (void)refreshWithProfile:(NSDictionary *)profile showStats:(BOOL)showStats withWidth:(int)newWidth;

- (IBAction)doFollowButton:(id)sender;
- (void)initProfile;

@end
