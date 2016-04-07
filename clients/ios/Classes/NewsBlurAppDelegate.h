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
#import "EventWindow.h"

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
@class MarkReadMenuViewController;
@class FirstTimeUserViewController;
@class FirstTimeUserAddSitesViewController;
@class FirstTimeUserAddFriendsViewController;
@class FirstTimeUserAddNewsBlurViewController;
@class FriendsListViewController;
@class FontSettingsViewController;
@class StoryDetailViewController;
@class StoryPageControl;
@class ShareViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class TrainerViewController;
@class UserTagsViewController;
@class OriginalStoryViewController;
@class UserProfileViewController;
@class NBContainerViewController;
@class FeedChooserViewController;
@class MenuViewController;
@class IASKAppSettingsViewController;
@class UnreadCounts;
@class StoriesCollection;
@class TMCache;

@interface NewsBlurAppDelegate : BaseViewController
<UIApplicationDelegate, UIAlertViewDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate,
SFSafariViewControllerDelegate>  {
    EventWindow *window;
    UINavigationController *ftuxNavigationController;
    UINavigationController *navigationController;
    UINavigationController *modalNavigationController;
    UINavigationController *shareNavigationController;
    UINavigationController *userProfileNavigationController;
    UINavigationController *trainNavigationController;
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
    FriendsListViewController *friendsListViewController;
    FontSettingsViewController *fontSettingsViewController;
    
    StoryDetailViewController *storyDetailViewController;
    StoryPageControl *storyPageControl;
    ShareViewController *shareViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    TrainerViewController *trainerViewController;
    UserTagsViewController *userTagsViewController;
    OriginalStoryViewController *originalStoryViewController;
    UINavigationController *originalStoryViewNavController;
    UserProfileViewController *userProfileViewController;
    IASKAppSettingsViewController *preferencesViewController;

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
    
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    NSString * activeShareType;
    NSDictionary * activeComment;
    int feedDetailPortraitYCoordinate;
    int originalStoryCount;
    NSInteger selectedIntelligence;
    int savedStoriesCount;
    int totalUnfetchedStoryCount;
    int remainingUnfetchedStoryCount;
    int latestFetchedStoryDate;
    int latestCachedImageDate;
    int totalUncachedImagesCount;
    int remainingUncachedImagesCount;
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
    
    FMDatabaseQueue *database;
    NSOperationQueue *offlineQueue;
    NSOperationQueue *offlineCleaningQueue;
    NSOperationQueue *cacheImagesOperationQueue;
    NSArray *categories;
    NSDictionary *categoryFeeds;
    UIImageView *splashView;
    NSMutableDictionary *activeCachedImages;
    
    TMCache *cachedFavicons;
    TMCache *cachedStoryImages;
}

@property (nonatomic) IBOutlet EventWindow *window;
@property (nonatomic) IBOutlet UINavigationController *ftuxNavigationController;
@property (nonatomic) IBOutlet UINavigationController *navigationController;
@property (nonatomic) UINavigationController *modalNavigationController;
@property (nonatomic) UINavigationController *shareNavigationController;
@property (nonatomic) UINavigationController *trainNavigationController;
@property (nonatomic) UINavigationController *userProfileNavigationController;
@property (nonatomic) UINavigationController *originalStoryViewNavController;
@property (nonatomic) IBOutlet NBContainerViewController *masterContainerViewController;
@property (nonatomic) IBOutlet DashboardViewController *dashboardViewController;
@property (nonatomic) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic) IBOutlet FeedsMenuViewController *feedsMenuViewController;
@property (nonatomic) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic) IBOutlet FeedDetailMenuViewController *feedDetailMenuViewController;
@property (nonatomic, strong) UINavigationController *feedDetailMenuNavigationController;
@property (nonatomic) IBOutlet FriendsListViewController *friendsListViewController;
@property (nonatomic) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic) IBOutlet StoryPageControl *storyPageControl;
@property (nonatomic) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, strong) UINavigationController *addSiteNavigationController;
@property (nonatomic) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic) IBOutlet TrainerViewController *trainerViewController;
@property (nonatomic) IBOutlet UserTagsViewController *userTagsViewController;
@property (nonatomic) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic) IBOutlet ShareViewController *shareViewController;
@property (nonatomic) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic) IBOutlet UserProfileViewController *userProfileViewController;
@property (nonatomic) IBOutlet IASKAppSettingsViewController *preferencesViewController;
@property (nonatomic, strong) UINavigationController *fontSettingsNavigationController;
@property (nonatomic, strong) MarkReadMenuViewController *markReadMenuViewController;
@property (nonatomic, strong) FeedChooserViewController *feedChooserViewController;
@property (nonatomic) IBOutlet FirstTimeUserViewController *firstTimeUserViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddSitesViewController *firstTimeUserAddSitesViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddFriendsViewController *firstTimeUserAddFriendsViewController;
@property (nonatomic) IBOutlet FirstTimeUserAddNewsBlurViewController *firstTimeUserAddNewsBlurViewController;

@property (nonatomic, readwrite) StoriesCollection *storiesCollection;
@property (nonatomic, readwrite) TMCache *cachedFavicons;
@property (nonatomic, readwrite) TMCache *cachedStoryImages;

@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *host;

@property (readwrite) NSString * activeUsername;
@property (readwrite) NSString * activeUserProfileId;
@property (readwrite) NSString * activeUserProfileName;
@property (nonatomic, readwrite) BOOL hasNoSites;
@property (nonatomic, readwrite) BOOL isTryFeedView;
@property (nonatomic, readwrite) BOOL inFindingStoryMode;
@property (nonatomic, readwrite) BOOL hasLoadedFeedDetail;
@property (nonatomic) NSString *tryFeedStoryId;
@property (nonatomic) NSString *tryFeedCategory;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (nonatomic, readwrite) BOOL isPresentingActivities;
@property (readwrite) NSDictionary * activeStory;
@property (readwrite) NSURL * activeOriginalStoryURL;
@property (readwrite) NSDictionary * activeComment;
@property (readwrite) NSString * activeShareType;
@property (readwrite) int feedDetailPortraitYCoordinate;
@property (readwrite) int originalStoryCount;
@property (readwrite) int savedStoriesCount;
@property (readwrite) int totalUnfetchedStoryCount;
@property (readwrite) int remainingUnfetchedStoryCount;
@property (readwrite) int totalUncachedImagesCount;
@property (readwrite) int remainingUncachedImagesCount;
@property (readwrite) int latestFetchedStoryDate;
@property (readwrite) int latestCachedImageDate;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite) NSMutableDictionary * recentlyReadStories;
@property (readwrite) NSMutableSet * recentlyReadFeeds;
@property (readwrite) NSMutableArray * readStories;
@property (readwrite) NSMutableDictionary *unreadStoryHashes;
@property (nonatomic) NSMutableDictionary *folderCountCache;
@property (nonatomic) NSMutableDictionary *collapsedFolders;
@property (nonatomic) UIFontDescriptor *fontDescriptorTitleSize;


@property (nonatomic) NSDictionary *dictFolders;
@property (nonatomic, strong) NSMutableDictionary *dictFeeds;
@property (nonatomic) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic) NSDictionary *dictSocialFeeds;
@property (nonatomic) NSDictionary *dictSavedStoryTags;
@property (nonatomic, strong) NSDictionary *dictSavedStoryFeedCounts;
@property (nonatomic) NSDictionary *dictSocialProfile;
@property (nonatomic) NSDictionary *dictUserProfile;
@property (nonatomic) NSDictionary *dictSocialServices;
@property (nonatomic, strong) NSMutableDictionary *dictUnreadCounts;
@property (nonatomic, strong) NSMutableDictionary *dictTextFeeds;
@property (nonatomic) NSArray *userInteractionsArray;
@property (nonatomic) NSArray *userActivitiesArray;
@property (nonatomic) NSMutableArray *dictFoldersArray;

@property (nonatomic) NSArray *categories;
@property (nonatomic) NSDictionary *categoryFeeds;
@property (readwrite) FMDatabaseQueue *database;
@property (nonatomic) NSOperationQueue *offlineQueue;
@property (nonatomic) NSOperationQueue *offlineCleaningQueue;
@property (nonatomic) NSOperationQueue *cacheImagesOperationQueue;
@property (nonatomic) NSMutableDictionary *activeCachedImages;
@property (nonatomic, readwrite) BOOL hasQueuedReadStories;
@property (nonatomic, readonly) BOOL showingSafariViewController;
@property (nonatomic, readonly) BOOL isCompactWidth;
@property (nonatomic) CGFloat compactWidth;

@property (nonatomic, strong) void (^backgroundCompletionHandler)(UIBackgroundFetchResult);

+ (NewsBlurAppDelegate*) sharedAppDelegate;
- (void)registerDefaultsFromSettingsBundle;
- (void)finishBackground;

- (void)showFirstTimeUser;
- (void)showLogin;
- (void)setupReachability;

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
- (void)showPreferences;

- (void)showMoveSite;
- (void)openTrainSite;
- (void)openTrainSiteWithFeedLoaded:(BOOL)feedLoaded from:(id)sender;
- (void)openTrainStory:(id)sender;
- (void)openUserTagsStory:(id)sender;
- (void)loadFeedDetailView;
- (void)loadFeedDetailView:(BOOL)transition;
- (void)loadTryFeedDetailView:(NSString *)feedId withStory:(NSString *)contentId isSocial:(BOOL)social withUser:(NSDictionary *)user showFindingStory:(BOOL)showHUD;
- (void)loadStarredDetailViewWithStory:(NSString *)contentId showFindingStory:(BOOL)showHUD;
- (void)loadRiverFeedDetailView:(FeedDetailViewController *)feedDetailView withFolder:(NSString *)folder;
- (void)openDashboardRiverForStory:(NSString *)contentId
                  showFindingStory:(BOOL)showHUD;

- (void)loadStoryDetailView;
- (void)adjustStoryDetailWebView;
- (void)calibrateStoryTitles;
- (void)recalculateIntelligenceScores:(id)feedId;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;
- (void)hideStoryDetailView;
- (void)changeActiveFeedDetailRow;
- (void)showShareView:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setReplyId:(NSString *)commentIndex;
- (void)hideShareView:(BOOL)resetComment;
- (void)resetShareComments;
- (BOOL)isSocialFeed:(NSString *)feedIdStr;
- (BOOL)isSavedFeed:(NSString *)feedIdStr;
- (NSInteger)savedStoriesCountForFeed:(NSString *)feedIdStr;
- (BOOL)isSavedStoriesIntelligenceMode;
- (NSArray *)allFeedIds;
- (NSArray *)feedIdsForFolderTitle:(NSString *)folderTitle;
- (BOOL)isPortrait;
- (void)confirmLogout;
- (void)showConnectToService:(NSString *)serviceName;
- (void)refreshUserProfile:(void(^)())callback;
- (void)refreshFeedCount:(id)feedId;

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
- (BOOL)isFolderCollapsed:(NSString *)folderName;

- (void)markActiveFolderAllRead;
- (void)markFeedAllRead:(id)feedId;
- (void)markFeedReadInCache:(NSArray *)feedIds;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff older:(BOOL)older;
- (void)markStoriesRead:(NSDictionary *)stories inFeeds:(NSArray *)feeds cutoffTimestamp:(NSInteger)cutoff;
- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request;
- (void)finishMarkAllAsRead:(ASIHTTPRequest *)request;
- (void)finishMarkAsRead:(NSDictionary *)story;
- (void)finishMarkAsUnread:(NSDictionary *)story;
- (void)failedMarkAsUnread:(ASIFormDataRequest *)request;
- (void)finishMarkAsSaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsSaved:(ASIFormDataRequest *)request;
- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsUnsaved:(ASIFormDataRequest *)request;
- (NSInteger)adjustSavedStoryCount:(NSString *)tagName direction:(NSInteger)direction;
- (NSArray *)updateStarredStoryCounts:(NSDictionary *)results;
- (void)renameFeed:(NSString *)newTitle;
- (void)renameFolder:(NSString *)newTitle;

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount barButtonItem:(UIBarButtonItem *)barButtonItem completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkOlderNewerReadMenuWithStoriesCollection:(StoriesCollection *)olderNewerCollection story:(NSDictionary *)olderNewerStory sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect extraItems:(NSArray *)extraItems completionHandler:(void (^)(BOOL marked))completionHandler;

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize barButtonItem:(UIBarButtonItem *)barButtonItem;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections;
- (void)hidePopoverAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)hidePopoverAnimated:(BOOL)animated;
- (void)hidePopover;

+ (int)computeStoryScore:(NSDictionary *)intelligence;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;
- (NSArray *)parentFoldersForFeed:(NSString *)feedId;
- (NSDictionary *)getFeed:(NSString *)feedId;
- (NSDictionary *)getStory:(NSString *)storyHash;

+ (void)fillGradient:(CGRect)r startColor:(UIColor *)startColor endColor:(UIColor *)endColor;
+ (UIColor *)faviconColor:(NSString *)colorString;
+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end borderColor:(NSString *)borderColor;
- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect;
- (UIView *)makeFeedTitle:(NSDictionary *)feed;
- (void)saveFavicon:(UIImage *)image feedId:(NSString *)filename;
- (UIImage *)getFavicon:(NSString *)filename;
- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial;
- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial isSaved:(BOOL)isSaved;

- (void)toggleAuthorClassifier:(NSString *)author feedId:(NSString *)feedId;
- (void)toggleTagClassifier:(NSString *)tag feedId:(NSString *)feedId;
- (void)toggleTitleClassifier:(NSString *)title feedId:(NSString *)feedId score:(NSInteger)score;
- (void)toggleFeedClassifier:(NSString *)feedId;
- (void)requestClassifierResponse:(ASIHTTPRequest *)request withFeed:(NSString *)feedId;

- (NSInteger)databaseSchemaVersion:(FMDatabase *)db;
- (void)createDatabaseConnection;
- (void)setupDatabase:(FMDatabase *)db;
- (void)cancelOfflineQueue;
- (void)startOfflineQueue;
- (void)startOfflineFetchStories;
- (void)startOfflineFetchImages;
- (BOOL)isReachableForOffline;
- (void)storeUserProfiles:(NSArray *)userProfiles;
- (void)markScrollPosition:(NSInteger)position inStory:(NSDictionary *)story;
- (void)queueReadStories:(NSDictionary *)feedsStories;
- (BOOL)dequeueReadStoryHash:(NSString *)storyHash inFeed:(NSString *)storyFeedId;
- (void)flushQueuedReadStories:(BOOL)forceCheck withCallback:(void(^)())callback;
- (void)syncQueuedReadStories:(FMDatabase *)db withStories:(NSDictionary *)hashes withCallback:(void(^)())callback;
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

