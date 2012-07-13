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
@class ProfileBadge;
@class ActivityModule;

@interface UserProfileViewController : UIViewController 
 <UITableViewDataSource, UITableViewDelegate, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UILabel *followingCount;
    UILabel *followersCount;
    ProfileBadge *profileBadge;
    ActivityModule *activityModule;
    UITableView *profileTable;
}

@property (retain, nonatomic) NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) ProfileBadge *profileBadge;
@property (retain, nonatomic) ActivityModule *activityModule;
@property (retain, nonatomic) UITableView *profileTable;

- (void)getUserProfile;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)doCancelButton;
    
@end
