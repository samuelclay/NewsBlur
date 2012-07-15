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
#define SHARE_MODAL_HEIGHT 120
#define DASHBOARD_TITLE @"NewsBlur Dashboard"

@class NewsBlurViewController;
@class DashboardViewController;
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
@class MGSplitViewController;
@class UserProfileViewController;


@interface NewsBlurAppDelegate : BaseViewController 
                                <UIApplicationDelegate, UIAlertViewDelegate>  {
    UIWindow *window;
    MGSplitViewController *splitStoryController;
    UINavigationController *navigationController;
    UINavigationController *splitStoryDetailNavigationController;
    UINavigationController *findFriendsNavigationController;

    DashboardViewController *dashboardViewController;
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
    UserProfileViewController *userProfileViewController;

    NSString * activeUsername;
    NSString * activeUserProfileId;
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
    NSMutableArray * dictUserInteractions;
    NSDictionary * dictUserActivities;
    NSMutableArray * dictFoldersArray;
}

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet MGSplitViewController *splitStoryController;
@property (nonatomic, readonly) IBOutlet UINavigationController *navigationController;
@property (nonatomic, readonly) IBOutlet UINavigationController *findFriendsNavigationController;
@property (nonatomic, readonly) IBOutlet UINavigationController *splitStoryDetailNavigationController;
@property (nonatomic) IBOutlet DashboardViewController *dashboardViewController;
@property (nonatomic) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic) IBOutlet FeedsMenuViewController *feedsMenuViewController;
@property (nonatomic) IBOutlet FeedDashboardViewController *feedDashboardViewController;
@property (nonatomic) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic) IBOutlet FriendsListViewController *friendsListViewController;
@property (nonatomic) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic) IBOutlet GoogleReaderViewController *googleReaderViewController;
@property (nonatomic) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic) IBOutlet LoginViewController *loginViewController;
@property (nonatomic) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic) IBOutlet ShareViewController *shareViewController;
@property (nonatomic) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic) IBOutlet UserProfileViewController *userProfileViewController;

@property (readwrite) NSString * activeUsername;
@property (readwrite) NSString * activeUserProfileId;
@property (nonatomic, readwrite) BOOL isRiverView;
@property (nonatomic, readwrite) BOOL isSocialView;
@property (nonatomic, readwrite) BOOL isShowingShare;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (readwrite) NSDictionary * activeFeed;
@property (readwrite) NSString * activeFolder;
@property (readwrite) NSDictionary * activeComment;
@property (readwrite) NSArray * activeFolderFeeds;
@property (readwrite) NSArray * activeFeedStories;
@property (readwrite) NSArray * activeFeedUserProfiles;
@property (readwrite) NSMutableArray * activeFeedStoryLocations;
@property (readwrite) NSMutableArray * activeFeedStoryLocationIds;
@property (readwrite) NSDictionary * activeStory;
@property (readwrite) NSURL * activeOriginalStoryURL;
@property (readwrite) int feedDetailPortraitYCoordinate;
@property (readwrite) int storyCount;
@property (readwrite) int originalStoryCount;
@property (readwrite) int visibleUnreadCount;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite) NSMutableArray * recentlyReadStories;
@property (readwrite) NSMutableSet * recentlyReadFeeds;
@property (readwrite) NSMutableArray * readStories;

@property (nonatomic) NSDictionary *dictFolders;
@property (nonatomic) NSDictionary *dictFeeds;
@property (nonatomic) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic) NSDictionary *dictSocialFeeds;
@property (nonatomic) NSDictionary *dictUserProfile;
@property (nonatomic) NSMutableArray *dictUserInteractions;
@property (nonatomic) NSDictionary *dictUserActivities;
@property (nonatomic) NSMutableArray *dictFoldersArray;

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
- (void)showUserProfileModal;
- (void)hideUserProfileModal;
- (void)showFindFriends;


- (void)showAddSite;
- (void)showMoveSite;
- (void)loadFeedDetailView;
- (void)showDashboard;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)adjustShareModal;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)hideNavigationBar:(BOOL)animated;
- (void)showNavigationBar:(BOOL)animated;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;
- (void)hideStoryDetailView;
- (void)changeActiveFeedDetailRow;
- (void)dragFeedDetailView:(float)y;
- (void)showShareView:(NSString *)userId setUsername:(NSString *)username;
- (void)hideShareView:(BOOL)resetComment;
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
- (UIButton *)makeRightFeedTitle:(NSDictionary *)feed;
@end

