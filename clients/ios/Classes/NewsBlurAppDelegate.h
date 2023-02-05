//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import "BaseViewController.h"
#import "FMDatabaseQueue.h"
#import "AFNetworking.h"

#define FEED_DETAIL_VIEW_TAG 1000001
#define STORY_DETAIL_VIEW_TAG 1000002
#define FEED_TITLE_GRADIENT_TAG 100003
#define FEED_DASHBOARD_VIEW_TAG 100004
#define SHARE_MODAL_HEIGHT 120
#define STORY_TITLES_HEIGHT 240
#define DASHBOARD_TITLE @"NewsBlur"

@class SplitViewController;
@class FeedsViewController;
@class DashboardViewController;
@class FeedDetailViewController;
@class MarkReadMenuViewController;
@class FirstTimeUserViewController;
@class FirstTimeUserAddSitesViewController;
@class FirstTimeUserAddFriendsViewController;
@class FirstTimeUserAddNewsBlurViewController;
@class FriendsListViewController;
@class FontSettingsViewController;
@class DetailViewController;
@class StoryPagesViewController;
@class StoryDetailViewController;
@class ShareViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class TrainerViewController;
@class NotificationsViewController;
@class UserTagsViewController;
@class OriginalStoryViewController;
@class UserProfileViewController;
@class FeedChooserViewController;
@class MenuViewController;
@class IASKAppSettingsViewController;
@class UnreadCounts;
@class StoriesCollection;
@class PINCache;
@class PremiumManager;
@class PremiumViewController;
@class WKWebView;

@interface NewsBlurAppDelegate : BaseViewController
<UIApplicationDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate,
SFSafariViewControllerDelegate>  {
    UINavigationController *ftuxNavigationController;
    UINavigationController *feedsNavigationController;
    UINavigationController *modalNavigationController;
    UINavigationController *shareNavigationController;
    UINavigationController *userProfileNavigationController;
    UINavigationController *trainNavigationController;
    UINavigationController *notificationsNavigationController;
    UINavigationController *premiumNavigationController;
    DetailViewController *detailViewController;
    
    FirstTimeUserViewController *firstTimeUserViewController;
    FirstTimeUserAddSitesViewController *firstTimeUserAddSitesViewController;
    FirstTimeUserAddFriendsViewController *firstTimeUserAddFriendsViewController;
    FirstTimeUserAddNewsBlurViewController *firstTimeUserAddNewsBlurViewController;
    
    DashboardViewController *dashboardViewController;
    FeedsViewController *feedsViewController;
    FeedDetailViewController *feedDetailViewController;
    FriendsListViewController *friendsListViewController;
    FontSettingsViewController *fontSettingsViewController;
    
    StoryPagesViewController *storyPagesViewController;
    StoryDetailViewController *storyDetailViewController;
    ShareViewController *shareViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    TrainerViewController *trainerViewController;
    NotificationsViewController *notificationsViewController;
    UserTagsViewController *userTagsViewController;
    OriginalStoryViewController *originalStoryViewController;
    UINavigationController *originalStoryViewNavController;
    UserProfileViewController *userProfileViewController;
    IASKAppSettingsViewController *preferencesViewController;
    PremiumViewController *premiumViewController;

    AFHTTPSessionManager *networkManager;

    NSString * activeUsername;
    NSString * activeUserProfileId;
    NSString * activeUserProfileName;
    BOOL hasNoSites;
    BOOL isTryFeedView;
    BOOL popoverHasFeedView;
    BOOL inFeedDetail;
    BOOL inStoryDetail;
    BOOL inFindingStoryMode;
    BOOL hasLoadedFeedDetail;
    BOOL hasQueuedReadStories;
    NSString *tryFeedStoryId;
    NSString *tryFeedFeedId;
    
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    NSString * activeShareType;
    NSDictionary * activeComment;
    NSInteger feedDetailPortraitYCoordinate;
    NSInteger originalStoryCount;
    NSInteger selectedIntelligence;
    NSInteger savedStoriesCount;
    NSInteger totalUnfetchedStoryCount;
    NSInteger remainingUnfetchedStoryCount;
    NSInteger latestFetchedStoryDate;
    NSInteger latestCachedImageDate;
    NSInteger totalUncachedImagesCount;
    NSInteger remainingUncachedImagesCount;
    NSMutableDictionary * recentlyReadStories;
    NSMutableSet * recentlyReadFeeds;
    NSMutableArray * readStories;
    NSMutableDictionary *folderCountCache;
    NSMutableDictionary *collapsedFolders;
    UIFontDescriptor *fontDescriptorTitleSize;
    
	NSDictionary * dictFolders;
    NSMutableDictionary * dictFeeds;
    NSMutableDictionary * dictActiveFeeds;
    NSDictionary * dictSocialFeeds;
    NSDictionary * dictSocialProfile;
    NSDictionary * dictUserProfile;
    NSDictionary * dictSocialServices;
    NSMutableDictionary * dictUnreadCounts;
    NSMutableDictionary * dictTextFeeds;
    NSArray * userInteractionsArray;
    NSArray * userActivitiesArray;
    NSMutableArray * dictFoldersArray;
    NSArray * notificationFeedIds;
    
    FMDatabaseQueue *database;
    NSOperationQueue *offlineQueue;
    NSOperationQueue *offlineCleaningQueue;
    NSOperationQueue *cacheImagesOperationQueue;
    NSArray *categories;
    NSDictionary *categoryFeeds;
    UIImageView *splashView;
    NSMutableDictionary *activeCachedImages;
    
    PINCache *cachedFavicons;
    PINCache *cachedStoryImages;
}

@property (nonatomic) SplitViewController *splitViewController;
@property (nonatomic) IBOutlet UINavigationController *ftuxNavigationController;
@property (nonatomic) IBOutlet UINavigationController *feedsNavigationController;
@property (nonatomic) IBOutlet UINavigationController *feedDetailNavigationController;
@property (nonatomic) IBOutlet UINavigationController *detailNavigationController;
@property (nonatomic) UINavigationController *modalNavigationController;
@property (nonatomic) UINavigationController *shareNavigationController;
@property (nonatomic) UINavigationController *trainNavigationController;
@property (nonatomic) UINavigationController *notificationsNavigationController;
@property (nonatomic) UINavigationController *premiumNavigationController;
@property (nonatomic) UINavigationController *userProfileNavigationController;
@property (nonatomic) UINavigationController *originalStoryViewNavController;
@property (nonatomic) IBOutlet DetailViewController *detailViewController;
@property (nonatomic) IBOutlet DashboardViewController *dashboardViewController;
@property (nonatomic) IBOutlet FeedsViewController *feedsViewController;
@property (nonatomic) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) UINavigationController *feedDetailMenuNavigationController;
@property (nonatomic) IBOutlet FriendsListViewController *friendsListViewController;
@property (nonatomic) IBOutlet StoryPagesViewController *storyPagesViewController;
@property (nonatomic) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, strong) UINavigationController *addSiteNavigationController;
@property (nonatomic) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic) IBOutlet TrainerViewController *trainerViewController;
@property (nonatomic) IBOutlet NotificationsViewController *notificationsViewController;
@property (nonatomic) IBOutlet UserTagsViewController *userTagsViewController;
@property (nonatomic) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic) IBOutlet ShareViewController *shareViewController;
@property (nonatomic) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic) IBOutlet UserProfileViewController *userProfileViewController;
@property (nonatomic) IBOutlet IASKAppSettingsViewController *preferencesViewController;
@property (nonatomic,  strong) PremiumManager *premiumManager;
@property (nonatomic) IBOutlet PremiumViewController *premiumViewController;
@property (nonatomic, strong) UINavigationController *fontSettingsNavigationController;
@property (nonatomic, strong) MarkReadMenuViewController *markReadMenuViewController;
@property (nonatomic, strong) FeedChooserViewController *feedChooserViewController;
@property (nonatomic) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddSitesViewController *firstTimeUserAddSitesViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddFriendsViewController *firstTimeUserAddFriendsViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddNewsBlurViewController *firstTimeUserAddNewsBlurViewController;

@property (nonatomic) AFHTTPSessionManager *networkManager;
@property (nonatomic, readwrite) StoriesCollection *storiesCollection;
@property (nonatomic, readwrite) PINCache *cachedFavicons;
@property (nonatomic, readwrite) PINCache *cachedStoryImages;

@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *host;

@property (nonatomic, readonly) NSHTTPCookie *sessionIdCookie;
@property (readwrite) NSString * activeUsername;
@property (readwrite) NSString * activeUserProfileId;
@property (readwrite) NSString * activeUserProfileName;
@property (nonatomic, readwrite) BOOL hasNoSites;
@property (nonatomic, readwrite) BOOL isTryFeedView;
@property (nonatomic, readwrite) BOOL inFindingStoryMode;
@property (nonatomic, readwrite) BOOL hasLoadedFeedDetail;
@property (nonatomic, readwrite) NSDate *findingStoryStartDate;
@property (nonatomic) NSString *tryFeedStoryId;
@property (nonatomic) NSString *tryFeedFeedId;
@property (nonatomic) NSString *tryFeedCategory;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (nonatomic, readwrite) BOOL isPresentingActivities;
@property (readwrite) NSDictionary * activeStory;
@property (readwrite) NSURL * activeOriginalStoryURL;
@property (readwrite) NSDictionary * activeComment;
@property (readwrite) NSString * activeShareType;
@property (readwrite) NSInteger feedDetailPortraitYCoordinate;
@property (readwrite) NSInteger originalStoryCount;
@property (readwrite) NSInteger savedSearchesCount;
@property (readwrite) NSInteger savedStoriesCount;
@property (readwrite) NSInteger totalUnfetchedStoryCount;
@property (readwrite) NSInteger remainingUnfetchedStoryCount;
@property (readwrite) NSInteger totalUncachedTextCount;
@property (readwrite) NSInteger remainingUncachedTextCount;
@property (readwrite) NSInteger totalUncachedImagesCount;
@property (readwrite) NSInteger remainingUncachedImagesCount;
@property (readwrite) NSInteger latestFetchedStoryDate;
@property (readwrite) NSInteger latestCachedTextDate;
@property (readwrite) NSInteger latestCachedImageDate;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite) NSMutableDictionary * recentlyReadStories;
@property (readwrite) NSMutableSet * recentlyReadFeeds;
@property (readwrite) NSMutableArray * readStories;
@property (readwrite) NSMutableDictionary *unreadStoryHashes;
@property (readwrite) NSMutableDictionary *unsavedStoryHashes;
@property (nonatomic) NSMutableDictionary *folderCountCache;
@property (nonatomic) NSMutableDictionary *collapsedFolders;
@property (nonatomic) UIFontDescriptor *fontDescriptorTitleSize;


@property (nonatomic) NSDictionary *dictFolders;
@property (nonatomic, strong) NSMutableDictionary *dictFeeds;
@property (nonatomic, strong) NSMutableDictionary *dictInactiveFeeds;
@property (nonatomic) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic, strong) NSDictionary *dictSubfolders;
@property (nonatomic) NSDictionary *dictSocialFeeds;
@property (nonatomic) NSDictionary *dictSavedStoryTags;
@property (nonatomic, strong) NSDictionary *dictSavedStoryFeedCounts;
@property (nonatomic) NSDictionary *dictSocialProfile;
@property (nonatomic) NSDictionary *dictUserProfile;
@property (nonatomic) NSDictionary *dictSocialServices;
@property (nonatomic) BOOL isPremium;
@property (nonatomic) BOOL isPremiumArchive;
@property (nonatomic) NSInteger premiumExpire;
@property (nonatomic, strong) NSMutableDictionary *dictUnreadCounts;
@property (nonatomic, strong) NSMutableDictionary *dictTextFeeds;
@property (nonatomic) NSArray *userInteractionsArray;
@property (nonatomic) NSArray *userActivitiesArray;
@property (nonatomic) NSMutableArray *dictFoldersArray;
@property (nonatomic) NSArray *notificationFeedIds;

@property (nonatomic, readonly) NSString *widgetFolder;
@property (nonatomic, strong) NSString *pendingFolder;

@property (nonatomic) NSArray *categories;
@property (nonatomic) NSDictionary *categoryFeeds;
@property (readwrite) FMDatabaseQueue *database;
@property (nonatomic) NSOperationQueue *offlineQueue;
@property (nonatomic) NSOperationQueue *offlineCleaningQueue;
@property (nonatomic) NSOperationQueue *cacheImagesOperationQueue;
@property (nonatomic) NSMutableDictionary *activeCachedImages;
@property (nonatomic, readwrite) BOOL hasQueuedReadStories;
@property (nonatomic, readwrite) BOOL hasQueuedSavedStories;
@property (nonatomic, readonly) BOOL showingSafariViewController;
@property (nonatomic, readonly) BOOL isCompactWidth;
//@property (nonatomic) CGFloat compactWidth;

@property (nonatomic, strong) void (^backgroundCompletionHandler)(UIBackgroundFetchResult);

+ (instancetype)sharedAppDelegate;

- (void)registerDefaultsFromSettingsBundle;
- (void)finishBackground;

- (void)showFirstTimeUser;
- (void)showLogin;
- (void)setupReachability;
- (void)registerForRemoteNotifications;
- (void)registerForBadgeNotifications;

// social
- (NSDictionary *)getUser:(NSInteger)userId;
- (void)showUserProfileModal:(id)sender;
- (void)pushUserProfile;
- (void)hideUserProfileModal;
- (void)showSendTo:(UIViewController *)vc sender:(id)sender;
- (void)showSendTo:(UIViewController *)vc sender:(id)sender
           withUrl:(NSURL *)url
        authorName:(NSString *)authorName
              text:(NSString *)text
             title:(NSString *)title
         feedTitle:(NSString *)title
            images:(NSArray *)images;
- (void)showFindFriends;
- (void)showMuteSites;
- (void)showOrganizeSites;
- (void)showWidgetSites;
- (void)showPremiumDialog;
- (void)updateSplitBehavior;
- (void)addSplitControlToMenuController:(MenuViewController *)menuViewController;
- (void)showPreferences;
- (void)setHiddenPreferencesAnimated:(BOOL)animated;
- (void)resizePreviewSize;
- (void)resizeFontSize;
- (void)popToRootWithCompletion:(void (^)(void))completion;
- (void)showColumn:(UISplitViewControllerColumn)column debugInfo:(NSString *)debugInfo;

- (void)showMoveSite;
- (void)openTrainSite;
- (void)openNotificationsWithFeed:(NSString *)feedId;
- (void)openNotificationsWithFeed:(NSString *)feedId sender:(id)sender;
- (void)updateNotifications:(NSDictionary *)params feed:(NSString *)feedId;
- (void)checkForFeedNotifications;
- (void)openStatisticsWithFeed:(NSString *)feedId sender:(id)sender;
- (void)openTrainSiteWithFeedLoaded:(BOOL)feedLoaded from:(id)sender;
- (void)openTrainStory:(id)sender;
- (void)openUserTagsStory:(id)sender;
- (void)loadFeedDetailView;
- (void)loadFeedDetailView:(BOOL)transition;
- (void)loadFeed:(NSString *)feedId withStory:(NSString *)contentId animated:(BOOL)animated;
- (void)loadTryFeedDetailView:(NSString *)feedId withStory:(NSString *)contentId isSocial:(BOOL)social withUser:(NSDictionary *)user showFindingStory:(BOOL)showHUD;
- (void)backgroundLoadNotificationStory;
- (void)loadStarredDetailViewWithStory:(NSString *)contentId showFindingStory:(BOOL)showHUD;
- (void)loadRiverFeedDetailView:(FeedDetailViewController *)feedDetailView withFolder:(NSString *)folder;
- (void)openDashboardRiverForStory:(NSString *)contentId
                  showFindingStory:(BOOL)showHUD;

- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)calibrateStoryTitles;
- (void)recalculateIntelligenceScores:(id)feedId;

- (void)cancelRequests;
- (NSString *)beginNetworkOperation;
- (void)endNetworkOperation:(NSString *)networkOperationIdentifier;

- (void)GET:(NSString *)urlString parameters:(id)parameters
    success:(void (^)(NSURLSessionDataTask *, id))success
    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;
- (void)GET:(NSString *)urlString parameters:(id)parameters target:(id)target
    success:(SEL)success
    failure:(SEL)failure;
- (void)POST:(NSString *)urlString parameters:(id)parameters
     success:(void (^)(NSURLSessionDataTask *, id))success
     failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;
- (void)POST:(NSString *)urlString parameters:(id)parameters target:(id)target
     success:(SEL)success
     failure:(SEL)failure;

- (void)prepareWebView:(WKWebView *)webView completionHandler:(void (^)(void))completion;

- (void)loadFolder:(NSString *)folder feedID:(NSString *)feedIdStr;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)showOriginalStory:(NSURL *)url sender:(id)sender;
- (void)showInAppBrowser:(NSURL *)url withCustomTitle:(NSString *)customTitle fromSender:(id)sender;
- (void)showSafariViewControllerWithURL:(NSURL *)url useReader:(BOOL)useReader;
- (void)closeOriginalStory;
- (void)hideStoryDetailView;
- (void)showFeedsListAnimated:(BOOL)animated;
- (void)changeActiveFeedDetailRow;
- (void)showShareView:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setReplyId:(NSString *)commentIndex;
- (void)hideShareView:(BOOL)resetComment;
- (void)resetShareComments;
- (BOOL)isSocialFeed:(NSString *)feedIdStr;
- (BOOL)isSavedSearch:(NSString *)feedIdStr;
- (BOOL)isSavedFeed:(NSString *)feedIdStr;
- (NSInteger)savedStoriesCountForFeed:(NSString *)feedIdStr;
- (BOOL)isSavedStoriesIntelligenceMode;
- (NSArray *)allFeedIds;
- (NSArray *)feedIdsForFolderTitle:(NSString *)folderTitle;
- (BOOL)isPortrait;
- (void)confirmLogout;
- (void)showConnectToService:(NSString *)serviceName;
- (void)showAlert:(UIAlertController *)alert withViewController:(UIViewController *)vc;
- (void)refreshUserProfile:(void(^)(void))callback;
- (void)refreshFeedCount:(id)feedId;

- (void)donateRefresh;
- (void)donateFolder;
- (void)donateFeed;

- (void)populateDictTextFeeds;
- (BOOL)isFeedInTextView:(id)feedId;
- (void)toggleFeedTextView:(id)feedId;

- (void)populateDictUnreadCounts;
- (NSInteger)unreadCount;
- (NSInteger)allUnreadCount;
- (NSInteger)unreadCountForFeed:(NSString *)feedId;
- (NSInteger)unreadCountForFolder:(NSString *)folderName;
- (UnreadCounts *)splitUnreadCountForFeed:(NSString *)feedId;
- (UnreadCounts *)splitUnreadCountForFolder:(NSString *)folderName;
- (NSDictionary *)markVisibleStoriesRead;

- (void)markActiveFolderAllRead;
- (void)markFeedAllRead:(id)feedId;
- (void)markFeedReadInCache:(NSArray *)feedIds;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff older:(BOOL)older;
- (void)markStoriesRead:(NSDictionary *)stories inFeeds:(NSArray *)feeds cutoffTimestamp:(NSInteger)cutoff;
- (void)finishMarkAsRead:(NSDictionary *)story;
- (void)finishMarkAsUnread:(NSDictionary *)story;
- (void)failedMarkAsUnread:(NSDictionary *)params;
- (void)finishMarkAsSaved:(NSDictionary *)params;
- (void)failedMarkAsSaved:(NSDictionary *)params;
- (void)finishMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnsaved:(NSDictionary *)params;
- (NSInteger)adjustSavedStoryCount:(NSString *)tagName direction:(NSInteger)direction;
- (NSArray *)updateStarredStoryCounts:(NSDictionary *)results;
- (NSArray *)updateSavedSearches:(NSDictionary *)results;
- (void)renameFeed:(NSString *)newTitle;
- (void)renameFolder:(NSString *)newTitle;

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount barButtonItem:(UIBarButtonItem *)barButtonItem completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkOlderNewerReadMenuWithStoriesCollection:(StoriesCollection *)olderNewerCollection story:(NSDictionary *)olderNewerStory sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect extraItems:(NSArray *)extraItems completionHandler:(void (^)(BOOL marked))completionHandler;

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sender:(id)sender;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize barButtonItem:(UIBarButtonItem *)barButtonItem;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections;
- (void)hidePopoverAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)hidePopoverAnimated:(BOOL)animated;
- (void)hidePopover;

+ (int)computeStoryScore:(NSDictionary *)intelligence;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;
- (BOOL)hasParentFolder:(NSString *)folderName;
- (BOOL)isFolderCollapsed:(NSString *)folderName;
- (BOOL)isFolderOrParentCollapsed:(NSString *)folderName;
- (NSArray *)parentFoldersForFeed:(NSString *)feedId;
- (NSString *)feedIdWithoutSearchQuery:(NSString *)feedId;
- (NSString *)searchQueryForFeedId:(NSString *)feedId;
- (NSString *)searchFolderForFeedId:(NSString *)feedId;
- (NSDictionary *)getFeedWithId:(id)feedId;
- (NSDictionary *)getFeed:(NSString *)feedId;
- (NSDictionary *)getStory:(NSString *)storyHash;

+ (void)fillGradient:(CGRect)r startColor:(UIColor *)startColor endColor:(UIColor *)endColor;
+ (UIView *)makeSimpleGradientView:(CGRect)rect startColor:(UIColor *)startColor endColor:(UIColor *)endColor;
+ (UIColor *)faviconColor:(NSString *)colorString;
+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end borderColor:(NSString *)borderColor;
- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect;
- (UIView *)makeFeedTitle:(NSDictionary *)feed;
- (NSString *)folderTitle:(NSString *)folder;
- (UIImage *)folderIcon:(NSString *)folder;
- (void)saveFavicon:(UIImage *)image feedId:(NSString *)filename;
- (UIImage *)getFavicon:(NSString *)filename;
- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial;
- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial isSaved:(BOOL)isSaved;

- (void)toggleAuthorClassifier:(NSString *)author feedId:(NSString *)feedId;
- (void)toggleTagClassifier:(NSString *)tag feedId:(NSString *)feedId;
- (void)toggleTitleClassifier:(NSString *)title feedId:(NSString *)feedId score:(NSInteger)score;
- (void)toggleFeedClassifier:(NSString *)feedId;

- (NSInteger)databaseSchemaVersion:(FMDatabase *)db;
- (void)createDatabaseConnection;
- (void)setupDatabase:(FMDatabase *)db force:(BOOL)force;
- (void)cancelOfflineQueue;
- (void)startOfflineQueue;
- (void)startOfflineFetchStories;
- (void)startOfflineFetchText;
- (void)startOfflineFetchImages;
- (BOOL)isReachableForOffline;
- (void)storeUserProfiles:(NSArray *)userProfiles;
- (void)markScrollPosition:(NSInteger)position inStory:(NSDictionary *)story;
- (void)queueReadStories:(NSDictionary *)feedsStories;
- (BOOL)dequeueReadStoryHash:(NSString *)storyHash inFeed:(NSString *)storyFeedId;
- (void)flushQueuedReadStories:(BOOL)forceCheck withCallback:(void(^)(void))callback;
- (void)syncQueuedReadStories:(FMDatabase *)db withStories:(NSDictionary *)hashes withCallback:(void(^)(void))callback;
- (void)queueSavedStory:(NSDictionary *)story;
- (void)fetchTextForStory:(NSString *)storyHash inFeed:(NSString *)feedId checkCache:(BOOL)checkCache withCallback:(void(^)(NSString *))callback;
- (void)prepareActiveCachedImages:(FMDatabase *)db;
- (void)cleanImageCache;
- (void)deleteAllCachedImages;

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

