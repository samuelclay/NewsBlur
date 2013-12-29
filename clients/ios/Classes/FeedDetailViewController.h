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
#import "WEPopoverController.h"
#import "NBNotifier.h"
#import "MCSwipeTableViewCell.h"

@class NewsBlurAppDelegate;
@class FeedDetailTableCell;
@class MCSwipeTableViewCell;

@interface FeedDetailViewController : BaseViewController 
<UITableViewDelegate, UITableViewDataSource, 
 UIActionSheetDelegate, UIAlertViewDelegate,
 UIPopoverControllerDelegate, ASIHTTPRequestDelegate,
 WEPopoverControllerDelegate, MCSwipeTableViewCellDelegate,
 UIGestureRecognizerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    int feedPage;
    BOOL pageFetching;
    BOOL pageFinished;
    BOOL finishedAnimatingIn;
    BOOL isOffline;
    BOOL isShowingOffline;
     
    UITableView * storyTitlesTable;
    UIBarButtonItem * feedMarkReadButton;
    WEPopoverController *popoverController;
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
@property (nonatomic, retain) WEPopoverController *popoverController;
@property (nonatomic, retain) NBNotifier *notifier;

@property (nonatomic, readwrite) int feedPage;
@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (nonatomic, readwrite) BOOL finishedAnimatingIn;
@property (nonatomic, readwrite) BOOL isOffline;
@property (nonatomic, readwrite) BOOL isShowingOffline;

- (void)resetFeedDetail;
- (void)reloadPage;
- (void)fetchNextPage:(void(^)())callback;
- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback;
- (void)loadOfflineStories;
- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback;
- (void)finishedLoadingFeed:(ASIHTTPRequest *)request;
- (void)testForTryFeed;

- (void)renderStories:(NSArray *)newStories;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;
- (void)changeIntelligence:(NSInteger)newLevel;
- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow;
- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle;
- (void)checkScroll;
- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation;

- (void)fadeSelectedCell;
- (void)loadStory:(FeedDetailTableCell *)cell atRow:(NSInteger)row;
- (void)redrawUnreadStory;
- (IBAction)doOpenMarkReadActionSheet:(id)sender;
- (IBAction)doOpenSettingsActionSheet:(id)sender;
- (void)confirmDeleteSite;
- (void)deleteSite;
- (void)deleteFolder;
- (void)openMoveView;
- (void)openTrainSite;
- (void)showUserProfile;
- (void)changeActiveFeedDetailRow;
- (void)instafetchFeed;
- (void)changeActiveStoryTitleCellLayout;
- (void)loadFaviconsFromActiveFeed;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request;
- (void)finishMarkAllAsRead:(ASIHTTPRequest *)request;
@end