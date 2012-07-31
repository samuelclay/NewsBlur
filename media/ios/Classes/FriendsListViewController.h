//
//  FriendsListViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface FriendsListViewController : UITableViewController <UISearchBarDelegate, UISearchDisplayDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UISearchBar *searchBar;
    UISearchDisplayController *searchDisplayController;
    UITableView *friendsTable;
    NSArray *suggestedUserProfiles;
    NSArray *userProfiles;
    NSArray *userProfileIds;

}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UISearchBar *searchBar;
@property (nonatomic) IBOutlet UISearchDisplayController *searchDisplayController;

@property (nonatomic) NSArray *userProfiles;
@property (nonatomic) NSArray *suggestedUserProfiles;

- (void)doCancelButton;
- (void)loadFriendsList:(NSString *)query;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)loadSuggestedFriendsList;
- (void)loadSuggestedFriendsListFinished:(ASIHTTPRequest *)request;
@end
