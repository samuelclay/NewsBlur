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

@class NewsBlurAppDelegate;
@class MCSwipeTableViewCell;

@interface FeedDetailObjCViewController : BaseViewController
<UITableViewDelegate, UITableViewDataSource,
 UIPopoverControllerDelegate,
 MCSwipeTableViewCellDelegate,
 UIGestureRecognizerDelegate, UISearchBarDelegate,
 UITableViewDragDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
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

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
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
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) IBOutlet UIView *messageView;
@property (nonatomic) IBOutlet UILabel *messageLabel;
@property (nonatomic, strong) id standardInteractivePopGestureDelegate;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (nonatomic, readwrite) BOOL finishedAnimatingIn;
@property (nonatomic, readwrite) BOOL isOnline;
@property (nonatomic, readwrite) BOOL isShowingFetching;
@property (nonatomic) FeedDetailTextSize textSize;
@property (nonatomic, readwrite) BOOL showImagePreview;
@property (nonatomic, readwrite) BOOL invalidateFontCache;
@property (nonatomic, readwrite) BOOL cameFromFeedsList;

- (void)reloadData;
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

- (void)renderStories:(NSArray *)newStories;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;
- (void)changeIntelligence:(NSInteger)newLevel;
- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow;
- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle;
- (void)checkScroll;
- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation;

- (void)fadeSelectedCell;
- (void)fadeSelectedCell:(BOOL)deselect;
- (void)loadStory:(FeedDetailTableCell *)cell atRow:(NSInteger)row;
- (void)redrawUnreadStory;
- (IBAction)doOpenMarkReadMenu:(id)sender;
- (IBAction)doOpenSettingsMenu:(id)sender;
- (void)deleteSite;
- (void)deleteFolder;
- (void)muteSite;
- (void)openTrainSite;
- (void)openNotificationsWithFeed:(NSString *)feedId;
- (void)openRenameSite;
- (void)showUserProfile;
- (void)changeActiveFeedDetailRow;
- (void)instafetchFeed;
- (void)changeActiveStoryTitleCellLayout;
- (void)loadFaviconsFromActiveFeed;
- (void)markFeedsReadFromTimestamp:(NSInteger)cutoffTimestamp andOlder:(BOOL)older;
- (void)finishMarkAsSaved:(NSDictionary *)params;
- (void)failedMarkAsSaved:(NSDictionary *)params;
- (void)finishMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnread:(NSDictionary *)params;

@end
