//
//  FeedDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "BaseViewController.h"
#import "Utilities.h"
#import "NBNotifier.h"
#import "MCSwipeTableViewCell.h"

@class NewsBlurAppDelegate;
@class FeedDetailTableCell;
@class MCSwipeTableViewCell;

@interface FeedDetailViewController : BaseViewController 
<UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate,
 UIPopoverControllerDelegate, ASIHTTPRequestDelegate,
 MCSwipeTableViewCellDelegate,
 UIGestureRecognizerDelegate, UISearchBarDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    BOOL pageFetching;
    BOOL pageFinished;
    BOOL finishedAnimatingIn;
    BOOL isOnline;
    BOOL isShowingFetching;
    BOOL isDashboardModule;
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
@property (nonatomic) IBOutlet UIBarButtonItem * settingsBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacerBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacer2BarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * separatorBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * titleImageBarButton;
@property (nonatomic, retain) NBNotifier *notifier;
@property (nonatomic, retain) StoriesCollection *storiesCollection;
@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) IBOutlet UIView *messageView;
@property (nonatomic) IBOutlet UILabel *messageLabel;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (nonatomic, readwrite) BOOL finishedAnimatingIn;
@property (nonatomic, readwrite) BOOL isOnline;
@property (nonatomic, readwrite) BOOL isShowingFetching;
@property (nonatomic, readwrite) BOOL isDashboardModule;
@property (nonatomic, readwrite) BOOL showContentPreview;
@property (nonatomic, readwrite) BOOL showImagePreview;
@property (nonatomic, readwrite) BOOL invalidateFontCache;

- (void)reloadData;
- (void)resetFeedDetail;
- (void)reloadStories;
- (void)fetchNextPage:(void(^)())callback;
- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback;
- (void)loadOfflineStories;
- (void)fetchRiver;
- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback;
- (void)finishedLoadingFeed:(ASIHTTPRequest *)request;
- (void)testForTryFeed;
- (void)cacheStoryImages:(NSArray *)storyImageUrls;
- (void)showStoryImage:(NSString *)imageUrl;

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
- (void)confirmDeleteSite;
- (void)confirmMuteSite;
- (void)deleteSite;
- (void)deleteFolder;
- (void)muteSite;
- (void)openMoveView;
- (void)openTrainSite;
- (void)openRenameSite;
- (void)showUserProfile;
- (void)changeActiveFeedDetailRow;
- (void)instafetchFeed;
- (void)changeActiveStoryTitleCellLayout;
- (void)loadFaviconsFromActiveFeed;
- (void)markFeedsReadFromTimestamp:(NSInteger)cutoffTimestamp andOlder:(BOOL)older;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)finishMarkAsSaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsSaved:(ASIFormDataRequest *)request;
- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsUnsaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsUnread:(ASIFormDataRequest *)request;

@end