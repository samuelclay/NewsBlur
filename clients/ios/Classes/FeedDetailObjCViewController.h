//
//  FeedDetailObjCViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "BaseViewController.h"
#import "Utilities.h"
#import "NBNotifier.h"
#import "MCSwipeTableViewCell.h"
#import "FeedDetailTableCell.h"

@class MCSwipeTableViewCell;

@interface FeedDetailObjCViewController : BaseViewController
<UITableViewDelegate, UITableViewDataSource,
 UIPopoverControllerDelegate,
 MCSwipeTableViewCellDelegate,
 UIGestureRecognizerDelegate, UISearchBarDelegate,
 UITableViewDragDelegate> {
    BOOL pageFetching;
    BOOL pageFinished;
    BOOL finishedAnimatingIn;
    BOOL isOnline;
    BOOL isShowingFetching;
    BOOL inDoubleTap;
    BOOL invalidateFontCache;
     
    UITableView * storyTitlesTable;
    UIBarButtonItem * feedMarkReadButton;
    Class popoverClass;
    NBNotifier *notifier;
}

@property (nonatomic, strong) IBOutlet UITableView *storyTitlesTable;
@property (nonatomic) IBOutlet UIBarButtonItem * feedMarkReadButton;
@property (nonatomic) IBOutlet UIBarButtonItem * feedsBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * settingsBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacerBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacer2BarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * separatorBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * titleImageBarButton;
@property (nonatomic, retain) NBNotifier *notifier;
@property (nonatomic, retain) StoriesCollection *storiesCollection;
#if !TARGET_OS_MACCATALYST
@property (nonatomic) UIRefreshControl *refreshControl;
#endif
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) IBOutlet UIView *messageView;
@property (nonatomic) IBOutlet UILabel *messageLabel;
@property (nonatomic, strong) id standardInteractivePopGestureDelegate;
//@property (nonatomic, readonly) NSIndexPath *selectedIndexPath;
@property (nonatomic) CGFloat storyHeight;
@property (nonatomic) NSIndexPath *swipingIndexPath;
@property (nonatomic, strong) NSString *swipingStoryHash;

@property (nonatomic, readonly) BOOL canPullToRefresh;
@property (nonatomic, readonly) BOOL isMarkReadOnScroll;
@property (nonatomic, readonly) BOOL isLegacyTable;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (nonatomic, readwrite) BOOL finishedAnimatingIn;
@property (nonatomic, readwrite) BOOL isOnline;
@property (nonatomic, readwrite) BOOL isShowingFetching;
@property (nonatomic) FeedDetailTextSize textSize;
@property (nonatomic, readwrite) BOOL showImagePreview;
@property (nonatomic, readwrite) BOOL invalidateFontCache;
@property (nonatomic, readwrite) BOOL cameFromFeedsList;

//- (void)changedStoryHeight:(CGFloat)storyHeight;
- (void)loadingFeed;
- (void)changedLayout;
- (void)reload;
- (void)reloadImmediately;
- (void)reloadTable;
- (void)reloadIndexPath:(NSIndexPath *)indexPath withRowAnimation:(UITableViewRowAnimation)rowAnimation;
- (void)reloadWithSizing;
- (void)resetFeedDetail;
- (void)reloadStories;
- (void)fetchNextPage:(void(^)(void))callback;
- (void)fetchFeedDetail:(int)page withCallback:(void(^)(void))callback;
- (void)loadOfflineStories;
- (void)fetchRiver;
- (void)fetchRiverPage:(int)page withCallback:(void(^)(void))callback;
- (void)testForTryFeed;
- (void)flashInfrequentStories;
- (void)gotoFolder:(NSString *)folder feedID:(NSString *)feedID;

//- (CGFloat)heightForRowAtIndexPath:(NSIndexPath *)indexPath;

//- (void)prepareFeedCell:(FeedDetailCollectionCell *)cell indexPath:(NSIndexPath *)indexPath;
//- (void)prepareStoryCell:(UICollectionViewCell *)cell indexPath:(NSIndexPath *)indexPath;
//- (void)prepareLoadingCell:(UICollectionViewCell *)cell indexPath:(NSIndexPath *)indexPath;

- (void)renderStories:(NSArray *)newStories;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;
- (void)changeIntelligence:(NSInteger)newLevel;
- (NSDictionary *)getStoryAtLocation:(NSInteger)storyLocation;
- (NSInteger)storyLocationForIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForStoryLocation:(NSInteger)location;

- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle;
- (void)checkScroll;
- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation;

- (void)fadeSelectedCell;
- (void)fadeSelectedCell:(BOOL)deselect;
- (void)loadStoryAtRow:(NSInteger)row;
- (void)redrawUnreadStory;
- (IBAction)doOpenMarkReadMenu:(id)sender;
- (IBAction)doMarkAllRead:(id)sender;
- (IBAction)doOpenSettingsMenu:(id)sender;
- (void)deleteSite;
- (void)deleteFolder;
- (IBAction)muteSite;
- (IBAction)openTrainSite;
- (IBAction)openNotifications:(id)sender;
- (void)openNotificationsWithFeed:(NSString *)feedId;
- (IBAction)openStatistics:(id)sender;
- (IBAction)openRenameSite;
- (void)showUserProfile;
- (void)changeActiveFeedDetailRow;
- (IBAction)instafetchFeed;
- (void)changeActiveStoryTitleCellLayout;
- (void)didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)loadFaviconsFromActiveFeed;
- (void)markFeedsReadFromTimestamp:(NSInteger)cutoffTimestamp andOlder:(BOOL)older;
- (void)finishMarkAsSaved:(NSDictionary *)params;
- (void)failedMarkAsSaved:(NSDictionary *)params;
- (void)finishMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnread:(NSDictionary *)params;

- (void)confirmDeleteSite:(UINavigationController *)menuNavigationController;
- (void)openMoveView:(UINavigationController *)menuNavigationController;

@end
