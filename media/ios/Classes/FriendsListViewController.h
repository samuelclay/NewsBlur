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

@interface FriendsListViewController : UIViewController <UISearchDisplayDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UISearchBar *searchBar;
    UISearchDisplayController *searchDisplayController;
    UITableView *friendsTable;
    NSArray *allItems;
    NSArray *allItemIds;
    NSArray *userProfiles;
    NSArray *userProfileIds;

}

@property ( nonatomic) IBOutlet UITableView *friendsTable;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property ( nonatomic) IBOutlet UISearchBar *searchBar;
@property ( nonatomic) IBOutlet UISearchDisplayController *searchDisplayController;

@property (nonatomic, copy) NSArray *userProfiles;
@property (nonatomic, copy) NSArray *allItems;
@property (nonatomic, copy) NSArray *allItemIds;

- (void)doCancelButton;
- (void)loadFriendsList:(NSString *)query;
- (void)requestFinished:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;

@end
