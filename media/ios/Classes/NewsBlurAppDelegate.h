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
#define STORY_TITLES_HEIGHT 240
#define DASHBOARD_TITLE @"NewsBlur"

@class NewsBlurViewController;
@class DashboardViewController;
@class FeedsMenuViewController;
@class FeedDetailViewController;
@class FeedDetailMenuViewController;
@class FeedDashboardViewController;
@class FirstTimeUserViewController;
@class FirstTimeUserAddSitesViewController;
@class FirstTimeUserAddFriendsViewController;
@class FirstTimeUserAddNewsBlurViewController;
@class FriendsListViewController;
@class FontSettingsViewController;
@class StoryDetailViewController;
@class ShareViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class OriginalStoryViewController;
@class UserProfileViewController;
@class NBContainerViewController;
@class FindSitesViewController;
@class UnreadCounts;

@interface NewsBlurAppDelegate : BaseViewController <UIApplicationDelegate, UIAlertViewDelegate>  {
    UIWindow *window;
    UINavigationController *ftuxNavigationController;
    UINavigationController *navigationController;
    UINavigationController *modalNavigationController;
    UINavigationController *shareNavigationController;
    UINavigationController *userProfileNavigationController;
    NBContainerViewController *masterContainerViewController;

    FirstTimeUserViewController *firstTimeUserViewController;
    FirstTimeUserAddSitesViewController *firstTimeUserAddSitesViewController;
    FirstTimeUserAddFriendsViewController *firstTimeUserAddFriendsViewController;
    FirstTimeUserAddNewsBlurViewController *firstTimeUserAddNewsBlurViewController;
                                    
    DashboardViewController *dashboardViewController;
    NewsBlurViewController *feedsViewController;
    FeedsMenuViewController *feedsMenuViewController;
    FeedDetailViewController *feedDetailViewController;
    FeedDetailMenuViewController *feedDetailMenuViewController;
    FeedDashboardViewController *feedDashboardViewController;
    FriendsListViewController *friendsListViewController;
    FontSettingsViewController *fontSettingsViewController;
    
    StoryDetailViewController *storyDetailViewController;
    ShareViewController *shareViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    FindSitesViewController *findSitesViewController;
    MoveSiteViewController *moveSiteViewController;
    OriginalStoryViewController *originalStoryViewController;
    UserProfileViewController *userProfileViewController;

    NSString * activeUsername;
    NSString * activeUserProfileId;
    NSString * activeUserProfileName;
    BOOL hasNoSites;
    BOOL isRiverView;
    BOOL isSocialView;
    BOOL isSocialRiverView;
    BOOL isTryFeedView;
    BOOL popoverHasFeedView;
    BOOL inFeedDetail;
    BOOL inStoryDetail;
    BOOL inFindingStoryMode;
    NSString *tryFeedStoryId;
    NSDictionary * activeFeed;
    NSString * activeFolder;
    NSDictionary * activeComment;
    NSString * activeShareType;
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
    NSMutableDictionary *folderCountCache;
    
	NSDictionary * dictFolders;
    NSMutableDictionary * dictFeeds;
    NSMutableDictionary * dictActiveFeeds;
    NSDictionary * dictSocialFeeds;
    NSDictionary * dictUserProfile;
    NSArray * userInteractionsArray;
    NSArray * userActivitiesArray;
    NSMutableArray * dictFoldersArray;
    
    NSArray *categories;
    NSDictionary *categoryFeeds;
}

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet UINavigationController *ftuxNavigationController;
@property (nonatomic) IBOutlet UINavigationController *navigationController;
@property (nonatomic) UINavigationController *modalNavigationController;
@property (nonatomic) UINavigationController *shareNavigationController;
@property (nonatomic) UINavigationController *userProfileNavigationController;
@property (nonatomic) IBOutlet NBContainerViewController *masterContainerViewController;
@property (nonatomic) IBOutlet DashboardViewController *dashboardViewController;
@property (nonatomic) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic) IBOutlet FeedsMenuViewController *feedsMenuViewController;
@property (nonatomic) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic) IBOutlet FeedDetailMenuViewController *feedDetailMenuViewController;
@property (nonatomic) IBOutlet FeedDashboardViewController *feedDashboardViewController;
@property (nonatomic) IBOutlet FriendsListViewController *friendsListViewController;
@property (nonatomic) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic) IBOutlet LoginViewController *loginViewController;
@property (nonatomic) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic) IBOutlet FindSitesViewController *findSitesViewController;
@property (nonatomic) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic) IBOutlet ShareViewController *shareViewController;
@property (nonatomic) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic) IBOutlet UserProfileViewController *userProfileViewController;

@property (nonatomic) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddSitesViewController *firstTimeUserAddSitesViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddFriendsViewController *firstTimeUserAddFriendsViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddNewsBlurViewController *firstTimeUserAddNewsBlurViewController;

@property (readwrite) NSString * activeUsername;
@property (readwrite) NSString * activeUserProfileId;
@property (readwrite) NSString * activeUserProfileName;
@property (nonatomic, readwrite) BOOL hasNoSites;
@property (nonatomic, readwrite) BOOL isRiverView;
@property (nonatomic, readwrite) BOOL isSocialView;
@property (nonatomic, readwrite) BOOL isSocialRiverView;
@property (nonatomic, readwrite) BOOL isTryFeedView;
@property (nonatomic, readwrite) BOOL inFindingStoryMode;
@property (nonatomic) NSString *tryFeedStoryId;
@property (nonatomic) NSString *tryFeedCategory;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (readwrite) NSDictionary * activeFeed;
@property (readwrite) NSString * activeFolder;
@property (readwrite) NSDictionary * activeComment;
@property (readwrite) NSString * activeShareType;
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
@property (nonatomic) NSMutableDictionary *folderCountCache;

@property (nonatomic) NSDictionary *dictFolders;
@property (nonatomic, strong) NSMutableDictionary *dictFeeds;
@property (nonatomic) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic) NSDictionary *dictSocialFeeds;
@property (nonatomic) NSDictionary *dictUserProfile;
@property (nonatomic) NSArray *userInteractionsArray;
@property (nonatomic) NSArray *userActivitiesArray;
@property (nonatomic) NSMutableArray *dictFoldersArray;

@property (nonatomic) NSArray *categories;
@property (nonatomic) NSDictionary *categoryFeeds;

+ (NewsBlurAppDelegate*) sharedAppDelegate;

- (void)showFirstTimeUser;
- (void)showLogin;

// social
- (void)showUserProfileModal:(id)sender;
- (void)pushUserProfile;
- (void)hideUserProfileModal;
- (void)showFindFriends;

- (void)showAddSiteModal:(id)sender;
- (void)showMoveSite;
- (void)loadFeedDetailView;
- (void)loadTryFeedDetailView:(NSString *)feedId withStory:(NSString *)contentId isSocial:(BOOL)social withUser:(NSDictionary *)user showFindingStory:(BOOL)showHUD;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)calibrateStoryTitles;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;
- (void)hideStoryDetailView;
- (void)changeActiveFeedDetailRow;
- (void)dragFeedDetailView:(float)y;
- (void)showShareView:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setReplyId:(NSString *)commentIndex;
- (void)hideShareView:(BOOL)resetComment;
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
- (int)allUnreadCount;
- (int)unreadCountForFeed:(NSString *)feedId;
- (int)unreadCountForFolder:(NSString *)folderName;
- (UnreadCounts *)splitUnreadCountForFeed:(NSString *)feedId;
- (UnreadCounts *)splitUnreadCountForFolder:(NSString *)folderName;
- (void)markActiveStoryRead;
- (void)markActiveStoryUnread;
- (NSDictionary *)markVisibleStoriesRead;
- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed;
- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed;
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

@interface UnreadCounts : NSObject {
    int ps;
    int nt;
    int ng;
}

@property (readwrite) int ps;
@property (readwrite) int nt;
@property (readwrite) int ng;

- (void)addCounts:(UnreadCounts *)counts;

@end

