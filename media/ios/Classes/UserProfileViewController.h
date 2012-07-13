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

@interface UserProfileViewController : UIViewController 
 <UITableViewDataSource, UITableViewDelegate, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UILabel *followingCount;
    UILabel *followersCount;
    ProfileBadge *profileBadge;
    UITableView *profileTable;
    NSArray *activitiesArray;
    NSString *activitiesUsername;
}

@property (retain, nonatomic) NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) ProfileBadge *profileBadge;
@property (retain, nonatomic) UITableView *profileTable;
@property (retain, nonatomic) NSArray *activitiesArray;
@property (retain, nonatomic) NSString *activitiesUsername;

- (void)getUserProfile;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)doCancelButton;
    
@end
