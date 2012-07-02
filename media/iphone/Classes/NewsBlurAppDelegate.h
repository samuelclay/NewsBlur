//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

#define FEED_DETAIL_VIEW_TAG 1000001
#define STORY_DETAIL_VIEW_TAG 1000002
#define FEED_TITLE_GRADIENT_TAG 100003
#define FEED_DASHBOARD_VIEW_TAG 100004
#define SHARE_MODAL_HEIGHT 140
#define DASHBOARD_TITLE @"NewsBlur Dashboard"

@class NewsBlurViewController;
@class FeedDetailViewController;
@class FeedsMenuViewController;
@class FeedDashboardViewController;
@class FirstTimeUserViewController;
@class FriendsListViewController;
@class FontSettingsViewController;
@class GoogleReaderViewController;
@class StoryDetailViewController;
@class ShareViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class OriginalStoryViewController;
@class SplitStoryDetailViewController;
@class MGSplitViewController;
@class UserProfileViewController;


@interface NewsBlurAppDelegate : BaseViewController 
                                <UIApplicationDelegate, UIAlertViewDelegate>  {
    UIWindow *window;
    MGSplitViewController *splitStoryController;
    UINavigationController *navigationController;
    UINavigationController *splitStoryDetailNavigationController;
    UINavigationController *findFriendsNavigationController;

    NewsBlurViewController *feedsViewController;
    FeedsMenuViewController *feedsMenuViewController;
    FeedDashboardViewController *feedDashboardViewController;
    FriendsListViewController *friendsListViewController;
    FontSettingsViewController *fontSettingsViewController;
    FeedDetailViewController *feedDetailViewController;
    FirstTimeUserViewController *firstTimeUserViewController;
    GoogleReaderViewController *googleReaderViewController;
    StoryDetailViewController *storyDetailViewController;
    ShareViewController *shareViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    OriginalStoryViewController *originalStoryViewController;
    SplitStoryDetailViewController *splitStoryDetailViewController;
    UserProfileViewController *userProfileViewController;

    NSString * activeUsername;
    NSString * activeUserProfile;
    BOOL isRiverView;
    BOOL isSocialView;
    BOOL isShowingShare;
    BOOL popoverHasFeedView;
    BOOL inStoryDetail;
    BOOL inFeedDetail;
    NSDictionary * activeFeed;
    NSString * activeFolder;
    NSDictionary * activeComment;
    NSArray * activeFolderFeeds;
    NSArray * activeFeedStories;
    NSArray * activeFeedUserProfiles;
    NSMutableArray * activeFeedStoryLocations;
    NSMutableArray * activeFeedStoryLocationIds;
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    
    int feedDetailPortraitYCoordinate;
    int storyCount;
    int originalStoryCount;
    NSInteger selectedIntelligence;
    int visibleUnreadCount;
    NSMutableArray * recentlyReadStories;
    NSMutableSet * recentlyReadFeeds;
    NSMutableArray * readStories;
    
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableDictionary * dictActiveFeeds;
    NSDictionary * dictSocialFeeds;
    NSDictionary * dictUserProfile;
    NSMutableArray * dictFoldersArray;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MGSplitViewController *splitStoryController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *findFriendsNavigationController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *splitStoryDetailNavigationController;
@property (nonatomic, retain) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic, retain) IBOutlet FeedsMenuViewController *feedsMenuViewController;
@property (nonatomic, retain) IBOutlet FeedDashboardViewController *feedDashboardViewController;
@property (nonatomic, retain) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic, retain) IBOutlet FriendsListViewController *friendsListViewController;
@property (nonatomic, retain) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic, retain) IBOutlet GoogleReaderViewController *googleReaderViewController;
@property (nonatomic, retain) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic, retain) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic, retain) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic, retain) IBOutlet SplitStoryDetailViewController *splitStoryDetailViewController;
@property (nonatomic, retain) IBOutlet ShareViewController *shareViewController;
@property (nonatomic, retain) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic, retain) IBOutlet UserProfileViewController *userProfileViewController;

@property (readwrite, retain) NSString * activeUsername;
@property (readwrite, retain) NSString * activeUserProfile;
@property (nonatomic, readwrite) BOOL isRiverView;
@property (nonatomic, readwrite) BOOL isSocialView;
@property (nonatomic, readwrite) BOOL isShowingShare;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (readwrite, retain) NSDictionary * activeFeed;
@property (readwrite, retain) NSString * activeFolder;
@property (readwrite, retain) NSDictionary * activeComment;
@property (readwrite, retain) NSArray * activeFolderFeeds;
@property (readwrite, retain) NSArray * activeFeedStories;
@property (readwrite, retain) NSArray * activeFeedUserProfiles;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocations;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocationIds;
@property (readwrite, retain) NSDictionary * activeStory;
@property (readwrite, retain) NSURL * activeOriginalStoryURL;
@property (readwrite) int feedDetailPortraitYCoordinate;
@property (readwrite) int storyCount;
@property (readwrite) int originalStoryCount;
@property (readwrite) int visibleUnreadCount;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite, retain) NSMutableArray * recentlyReadStories;
@property (readwrite, retain) NSMutableSet * recentlyReadFeeds;
@property (readwrite, retain) NSMutableArray * readStories;

@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic, retain) NSDictionary *dictSocialFeeds;
@property (nonatomic, retain) NSDictionary *dictUserProfile;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;

+ (NewsBlurAppDelegate*) sharedAppDelegate;

- (void)showFirstTimeUser;
- (void)showGoogleReaderAuthentication;
- (void)addedGoogleReader;
- (void)showLogin;
- (void)showFeedsMenu;
- (void)hideFeedsMenu;
- (void)animateHidingMasterView;
- (void)animateShowingMasterView;

// social
- (void)showUserProfile;
- (void)showFindFriends;


- (void)showAddSite;
- (void)showMoveSite;
- (void)loadFeedDetailView;
- (void)showDashboard;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)hideNavigationBar:(BOOL)animated;
- (void)showNavigationBar:(BOOL)animated;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;
- (void)changeActiveFeedDetailRow;
- (void)dragFeedDetailView:(float)y;
- (void)hideStoryDetailView;
- (void)showShareView:(NSString *)userId setUsername:(NSString *)username;
- (void)hideShareView;
- (void)refreshComments;
- (void)resetShareComments;
- (BOOL)isSocialFeed:(NSString *)feedIdStr;
- (BOOL)isPortrait;
- (void)confirmLogout;

- (int)indexOfNextUnreadStory;
- (int)indexOfNextStory;
- (int)indexOfPreviousStory;
- (int)indexOfActiveStory;
- (int)locationOfActiveStory;
- (void)pushReadStory:(id)storyId;
- (id)popReadStory;
- (int)locationOfStoryId:(id)storyId;

- (void)setStories:(NSArray *)activeFeedStoriesValue;
- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
- (void)addStories:(NSArray *)stories;
- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
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

