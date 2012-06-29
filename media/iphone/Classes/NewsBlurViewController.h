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
#import "BaseViewController.h"

@class NewsBlurAppDelegate;

@interface NewsBlurViewController : BaseViewController 
		   <UITableViewDelegate, UITableViewDataSource, 
            UIAlertViewDelegate, PullToRefreshViewDelegate,
            ASIHTTPRequestDelegate, NSCacheDelegate,
            UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSMutableDictionary * activeFeedLocations;
    NSMutableDictionary *visibleFeeds;
    NSMutableDictionary *stillVisibleFeeds;
    BOOL viewShowingAllFeeds;
    PullToRefreshView *pull;
    NSDate *lastUpdate;
    NSCache *imageCache;
    
	IBOutlet UITableView * feedTitlesTable;
	IBOutlet UIToolbar * feedViewToolbar;
    IBOutlet UISlider * feedScoreSlider;
    IBOutlet UIBarButtonItem * homeButton;
    IBOutlet UISegmentedControl * intelligenceControl;
    IBOutlet UIBarButtonItem * sitesButton;
    IBOutlet UIPopoverController *popoverController;
}

- (void)returnToApp;
- (void)fetchFeedList:(BOOL)showLoader;
- (void)finishedWithError:(ASIHTTPRequest *)request;
- (void)finishLoadingFeedList:(ASIHTTPRequest *)request;

- (void)dismissFeedsMenu;
- (IBAction)showMenuButton:(id)sender;
- (void)didSelectSectionHeader:(UIButton *)button;
- (IBAction)selectIntelligence;
- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel;
- (void)calculateFeedLocations:(BOOL)markVisible;
- (IBAction)sectionTapped:(UIButton *)button;
- (IBAction)sectionUntapped:(UIButton *)button;
- (IBAction)sectionUntappedOutside:(UIButton *)button;
- (void)redrawUnreadCounts;
+ (int)computeMaxScoreForFeed:(NSDictionary *)feed;
- (IBAction)doSwitchSitesUnread;
- (void)switchSitesUnread;
- (void)loadFavicons;
- (void)loadAvatars;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view;
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *feedTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * homeButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * sitesButton;
@property (nonatomic, retain) NSMutableDictionary *activeFeedLocations;
@property (nonatomic, retain) NSMutableDictionary *visibleFeeds;
@property (nonatomic, retain) NSMutableDictionary *stillVisibleFeeds;
@property (nonatomic, readwrite) BOOL viewShowingAllFeeds;
@property (nonatomic, retain) PullToRefreshView *pull;
@property (nonatomic, retain) NSDate *lastUpdate;
@property (nonatomic, retain) NSCache *imageCache;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;
@property (nonatomic, retain) UIPopoverController *popoverController;

@end
