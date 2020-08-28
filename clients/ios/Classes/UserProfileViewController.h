//
//  UserProfileViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@class NewsBlurAppDelegate;
@class ProfileBadge;

@interface UserProfileViewController : BaseViewController
<UITableViewDataSource, UITableViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UILabel *followingCount;
    UILabel *followersCount;
    ProfileBadge *profileBadge;
    UITableView *profileTable;
    NSArray *activitiesArray;
    NSString *activitiesUsername;
    NSDictionary *userProfile;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) ProfileBadge *profileBadge;
@property (nonatomic) UITableView *profileTable;
@property (nonatomic) NSArray *activitiesArray;
@property (nonatomic) NSString *activitiesUsername;
@property (nonatomic) NSDictionary *userProfile;

- (void)getUserProfile;
- (void)doCancelButton;
    
@end
