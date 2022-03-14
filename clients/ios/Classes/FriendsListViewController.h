//
//  FriendsListViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@class NewsBlurAppDelegate;

@interface FriendsListViewController : BaseViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate> {
    NewsBlurAppDelegate *appDelegate;
    UISearchBar *friendSearchBar;
    UITableView *friendsTable;
    NSArray *suggestedUserProfiles;
    NSArray *userProfiles;
    NSArray *userProfileIds;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UISearchBar *friendSearchBar;
@property (nonatomic) IBOutlet UITableView *friendsTable;

@property (nonatomic) NSArray *userProfiles;
@property (nonatomic) NSArray *suggestedUserProfiles;

- (void)doCancelButton;
- (void)loadFriendsList:(NSString *)query;
- (void)loadSuggestedFriendsList;
- (void)hideUserProfileModal;
@end
