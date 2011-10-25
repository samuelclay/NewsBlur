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
            UIAlertViewDelegate, PullToRefreshViewDelegate,
            ASIHTTPRequestDelegate, NSCacheDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSMutableDictionary * activeFeedLocations;
    NSMutableDictionary *stillVisibleFeeds;
    NSMutableDictionary *visibleFeeds;
    BOOL viewShowingAllFeeds;
    PullToRefreshView *pull;
    NSDate *lastUpdate;
    NSCache *imageCache;
    
	IBOutlet UITableView * feedTitlesTable;
	IBOutlet UIToolbar * feedViewToolbar;
    IBOutlet UISlider * feedScoreSlider;
    IBOutlet UIBarButtonItem * logoutButton;
    IBOutlet UISegmentedControl * intelligenceControl;
    IBOutlet UIBarButtonItem * sitesButton;
    IBOutlet UIBarButtonItem * addButton;
}

- (void)returnToApp;
- (void)fetchFeedList:(BOOL)showLoader;
- (void)finishedWithError:(ASIHTTPRequest *)request;
- (void)finishLoadingFeedList:(ASIHTTPRequest *)request;

- (IBAction)doLogoutButton;
- (void)didSelectSectionHeader;
- (IBAction)selectIntelligence;
- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel;
- (void)calculateFeedLocations:(BOOL)markVisible;
- (void)redrawUnreadCounts;
+ (int)computeMaxScoreForFeed:(NSDictionary *)feed;
- (IBAction)doSwitchSitesUnread;
- (IBAction)doAddButton;
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
@property (nonatomic, retain) IBOutlet UIBarButtonItem * addButton;
@property (nonatomic, retain) NSMutableDictionary *activeFeedLocations;
@property (nonatomic, retain) NSMutableDictionary *stillVisibleFeeds;
@property (nonatomic, retain) NSMutableDictionary *visibleFeeds;
@property (nonatomic, readwrite) BOOL viewShowingAllFeeds;
@property (nonatomic, retain) PullToRefreshView *pull;
@property (nonatomic, retain) NSDate *lastUpdate;
@property (nonatomic, retain) NSCache *imageCache;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;

@end
