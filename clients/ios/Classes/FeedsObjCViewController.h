//
//  FeedsObjCViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "FolderTitleView.h"
#import "BaseViewController.h"
#import "NBNotifier.h"
#import "IASKAppSettingsViewController.h"
#import "MCSwipeTableViewCell.h"

// indices in appDelegate.dictFoldersArray and button tags
// keep in sync with NewsBlurTopSectionNames
static enum {
    NewsBlurTopSectionInfrequentSiteStories = 0,
    NewsBlurTopSectionAllStories = 1
} NewsBlurTopSection;

@class NewsBlurAppDelegate;

@interface FeedsObjCViewController : BaseViewController
<UITableViewDelegate, UITableViewDataSource,
NSCacheDelegate,
UIPopoverControllerDelegate,
IASKSettingsDelegate,
MCSwipeTableViewCellDelegate,
UIGestureRecognizerDelegate, UISearchBarDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSMutableDictionary * activeFeedLocations;
    NSMutableDictionary *stillVisibleFeeds;
    NSMutableDictionary *visibleFolders;
    NSMutableDictionary *indexPathsForFeedIds;
    
    BOOL isOffline;
    BOOL viewShowingAllFeeds;
    BOOL interactiveFeedDetailTransition;
    NSCache *imageCache;
    
	UITableView * feedTitlesTable;
	UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    UIBarButtonItem * homeButton;
    UIBarButtonItem * addBarButton;
    UIBarButtonItem * settingsBarButton;
    UIBarButtonItem * activitiesButton;
    UISegmentedControl * intelligenceControl;
    NBNotifier *notifier;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet UITableView *feedTitlesTable;
@property (nonatomic) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic) IBOutlet UIBarButtonItem * homeButton;
@property (nonatomic) IBOutlet UIBarButtonItem * addBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * settingsBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * activitiesButton;
@property (nonatomic) IBOutlet UIButton *userAvatarButton;
@property (nonatomic) IBOutlet UILabel *neutralCount;
@property (nonatomic) IBOutlet UILabel *positiveCount;
@property (nonatomic) IBOutlet UILabel *userLabel;
@property (nonatomic) IBOutlet UIImageView *yellowIcon;
@property (nonatomic) IBOutlet UIImageView *greenIcon;
@property (nonatomic) NSMutableDictionary *activeFeedLocations;
@property (nonatomic) NSMutableDictionary *stillVisibleFeeds;
@property (nonatomic) NSMutableDictionary *visibleFolders;
@property (nonatomic, readwrite) BOOL viewShowingAllFeeds;
@property (nonatomic, readwrite) BOOL interactiveFeedDetailTransition;
@property (nonatomic, readwrite) BOOL isOffline;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<NSString *> *searchFeedIds;
@property (nonatomic) NSCache *imageCache;
@property (nonatomic) IBOutlet UISegmentedControl * intelligenceControl;
@property (nonatomic) NSIndexPath *currentRowAtIndexPath;
@property (nonatomic) NSInteger currentSection;
@property (strong, nonatomic) IBOutlet UIView *noFocusMessage;
@property (strong, nonatomic) IBOutlet UILabel *noFocusLabel;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *toolbarLeftMargin;
@property (nonatomic, retain) NBNotifier *notifier;
@property (nonatomic, retain) UIImageView *avatarImageView;

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)returnToApp;
- (void)fetchFeedList:(BOOL)showLoader;
- (void)finishLoadingFeedListWithDict:(NSDictionary *)results finished:(BOOL)finished;
- (void)didSelectSectionHeader:(UIButton *)button;
- (void)didSelectSectionHeaderWithTag:(NSInteger)tag;
- (void)selectNextFolderOrFeed;
- (IBAction)selectIntelligence;
- (void)markFeedRead:(NSString *)feedId cutoffDays:(NSInteger)days;
- (void)markFeedsRead:(NSArray *)feedIds cutoffDays:(NSInteger)days;
- (void)markEverythingReadWithDays:(NSInteger)days;
- (void)markVisibleStoriesRead;
- (void)didCollapseFolder:(UIButton *)button;
- (BOOL)isFeedVisible:(id)feedId;
- (void)changeToAllMode;
- (void)calculateFeedLocations;
- (void)updateFeedTitlesTable;
- (IBAction)sectionTapped:(UIButton *)button;
- (IBAction)sectionUntapped:(UIButton *)button;
- (IBAction)sectionUntappedOutside:(UIButton *)button;
- (void)redrawUnreadCounts;
- (void)showExplainerOnEmptyFeedlist;
+ (int)computeMaxScoreForFeed:(NSDictionary *)feed;
- (void)loadFavicons;
- (void)loadAvatars;
- (void)refreshFeedList;
- (void)refreshFeedList:(id)feedId;
- (void)loadOfflineFeeds:(BOOL)failed;
- (void)showUserProfile;
- (IBAction)showSettingsPopover:(id)sender;
- (IBAction)showInteractionsPopover:(id)sender;
- (void)fadeSelectedCell;
- (void)fadeFeed:(NSString *)feedId;
- (IBAction)tapAddSite:(id)sender;

- (void)selectWidgetStories;

- (void)reloadFeedTitlesTable;
- (void)resetToolbar;
- (void)layoutHeaderCounts:(UIInterfaceOrientation)orientation;
- (void)refreshHeaderCounts;
- (void)redrawFeedCounts:(id)feedId;

- (void)resizePreviewSize;
- (void)resizeFontSize;
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender;
- (void)settingDidChange:(NSNotification*)notification;

- (void)showRefreshNotifier;
- (void)showCountingNotifier;
- (void)showSyncingNotifier;
- (void)showSyncingNotifier:(float)progress hoursBack:(NSInteger)hours;
- (void)showCachingNotifier:(NSString *)prefix progress:(float)progress hoursBack:(NSInteger)hours;
- (void)showOfflineNotifier;
- (void)showDoneNotifier;
- (void)hideNotifier;

@end
