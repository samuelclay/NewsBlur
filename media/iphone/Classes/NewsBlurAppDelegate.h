//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

@class FeedsViewController;
@class FeedDetailViewController;
@class FeedsMenuViewController;
@class FirstTimeUserViewController;
@class FontSettingsViewController;
@class GoogleReaderViewController;
@class StoryDetailViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class OriginalStoryViewController;
@class SplitStoryDetailViewController;


@interface NewsBlurAppDelegate : BaseViewController <UIApplicationDelegate> {
    UIWindow *window;
    UISplitViewController *splitStoryController;
    UINavigationController *navigationController;
    UINavigationController *splitStoryDetailNavigationController;

    FeedsViewController *feedsViewController;
    FeedsMenuViewController *feedsMenuViewController;
    FontSettingsViewController *fontSettingsViewController;
    FeedDetailViewController *feedDetailViewController;
    FirstTimeUserViewController *firstTimeUserViewController;
    GoogleReaderViewController *googleReaderViewController;
    StoryDetailViewController *storyDetailViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    OriginalStoryViewController *originalStoryViewController;
    SplitStoryDetailViewController *splitStoryDetailViewController;

    
    NSString * activeUsername;
    BOOL isRiverView;
    NSDictionary * activeFeed;
    NSString * activeFolder;
    NSArray * activeFolderFeeds;
    NSArray * activeFeedStories;
    NSMutableArray * activeFeedStoryLocations;
    NSMutableArray * activeFeedStoryLocationIds;
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    
    int storyCount;
    int originalStoryCount;
    NSInteger selectedIntelligence;
    int visibleUnreadCount;
    NSMutableArray * recentlyReadStories;
    NSMutableSet * recentlyReadFeeds;
    NSMutableArray * readStories;
    
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableArray * dictFoldersArray;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UISplitViewController *splitStoryController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *splitStoryDetailNavigationController;
@property (nonatomic, retain) IBOutlet FeedsViewController *feedsViewController;
@property (nonatomic, retain) IBOutlet FeedsMenuViewController *feedsMenuViewController;
@property (nonatomic, retain) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic, retain) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic, retain) IBOutlet GoogleReaderViewController *googleReaderViewController;
@property (nonatomic, retain) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic, retain) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic, retain) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic, retain) IBOutlet SplitStoryDetailViewController *splitStoryDetailViewController;
@property (nonatomic, retain) IBOutlet FontSettingsViewController *fontSettingsViewController;

@property (readwrite, retain) NSString * activeUsername;
@property (nonatomic, readwrite) BOOL isRiverView;
@property (readwrite, retain) NSDictionary * activeFeed;
@property (readwrite, retain) NSString * activeFolder;
@property (readwrite, retain) NSArray * activeFolderFeeds;
@property (readwrite, retain) NSArray * activeFeedStories;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocations;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocationIds;
@property (readwrite, retain) NSDictionary * activeStory;
@property (readwrite, retain) NSURL * activeOriginalStoryURL;
@property (readwrite) int storyCount;
@property (readwrite) int originalStoryCount;
@property (readwrite) int visibleUnreadCount;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite, retain) NSMutableArray * recentlyReadStories;
@property (readwrite, retain) NSMutableSet * recentlyReadFeeds;
@property (readwrite, retain) NSMutableArray * readStories;

@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;

+ (NewsBlurAppDelegate*) sharedAppDelegate;

- (void)showFirstTimeUser;
- (void)showGoogleReaderAuthentication;
- (void)addedGoogleReader;
- (void)showLogin;
- (void)showFeedsMenu;
- (void)hideFeedsMenu;
- (void)showAdd;
- (void)showPopover;
- (void)showMoveSite;
- (void)loadFeedDetailView;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)hideNavigationBar:(BOOL)animated;
- (void)showNavigationBar:(BOOL)animated;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;
- (void)changeActiveFeedDetailRow:(int)rowIndex;

- (int)indexOfNextStory;
- (int)indexOfPreviousStory;
- (int)indexOfActiveStory;
- (int)locationOfActiveStory;
- (void)pushReadStory:(id)storyId;
- (id)popReadStory;
- (int)locationOfStoryId:(id)storyId;

- (void)setStories:(NSArray *)activeFeedStoriesValue;
- (void)addStories:(NSArray *)stories;
- (int)unreadCount;
- (int)unreadCountForFeed:(NSString *)feedId;
- (int)unreadCountForFolder:(NSString *)folderName;
- (void)markActiveStoryRead;
- (NSDictionary *)markVisibleStoriesRead;
- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed;
- (void)markActiveFeedAllRead;
- (void)markActiveFolderAllRead;
- (void)markFeedAllRead:(id)feedId;
- (void)calculateStoryLocations;
+ (int)computeStoryScore:(NSDictionary *)intelligence;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;
+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end;
- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect;
- (UIView *)makeFeedTitle:(NSDictionary *)feed;

@end

