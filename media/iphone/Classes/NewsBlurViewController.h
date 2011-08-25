//
//  NewsBlurViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"

@class NewsBlurAppDelegate;

@interface NewsBlurViewController : UIViewController 
		   <UITableViewDelegate, UITableViewDataSource, 
            UIAlertViewDelegate, PullToRefreshViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
	NSMutableData *responseData;
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableArray * dictFoldersArray;
    NSMutableDictionary * activeFeedLocations;
    NSMutableDictionary *stillVisibleFeeds;
    NSMutableDictionary *visibleFeeds;
    BOOL viewShowingAllFeeds;
    PullToRefreshView *pull;
    NSDate *lastUpdate;
    
	IBOutlet UITableView * feedTitlesTable;
	IBOutlet UIToolbar * feedViewToolbar;
    IBOutlet UISlider * feedScoreSlider;
    IBOutlet UIBarButtonItem * logoutButton;
    IBOutlet UISegmentedControl * intelligenceControl;
    IBOutlet UIBarButtonItem * sitesButton;
}

- (void)returnToApp;
- (void)fetchFeedList:(BOOL)showLoader;
- (IBAction)doLogoutButton;
- (IBAction)selectIntelligence;
- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel;
- (void)calculateFeedLocations:(BOOL)markVisible;
+ (int)computeMaxScoreForFeed:(NSDictionary *)feed;
- (IBAction)doSwitchSitesUnread;
- (void)loadFavicons;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view;
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *feedTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * logoutButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * sitesButton;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;
@property (nonatomic, retain) NSMutableDictionary *activeFeedLocations;
@property (nonatomic, retain) NSMutableDictionary *stillVisibleFeeds;
@property (nonatomic, retain) NSMutableDictionary *visibleFeeds;
@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, readwrite) BOOL viewShowingAllFeeds;
@property (nonatomic, retain) PullToRefreshView *pull;
@property (nonatomic, retain) NSDate *lastUpdate;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;

@end


@interface LogoutDelegate : NSObject {
    NewsBlurAppDelegate *appDelegate;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

@end