//
//  FeedDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASIHTTPRequest.h"
#import "BaseViewController.h"
#import "Utilities.h"

@class NewsBlurAppDelegate;

@interface FeedDetailViewController : BaseViewController 
<UITableViewDelegate, UITableViewDataSource, 
 UIActionSheetDelegate, UIAlertViewDelegate,
 UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSArray * stories;
    int feedPage;
    BOOL pageFetching;
    BOOL pageFinished;
               
    UITableView * storyTitlesTable;
    UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    UIBarButtonItem * feedMarkReadButton;
    UISegmentedControl * intelligenceControl;
    UIPopoverController *popoverController;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) UIPopoverController *popoverController;
@property (nonatomic, retain) IBOutlet UITableView *storyTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * feedMarkReadButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * settingsButton;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;

@property (nonatomic, retain) NSArray * stories;
@property (nonatomic, readwrite) int feedPage;
@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;


- (void)resetFeedDetail;
- (void)fetchNextPage:(void(^)())callback;
- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback;
- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback;
- (void)finishedLoadingFeed:(ASIHTTPRequest *)request;

- (void)renderStories:(NSArray *)newStories;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;
- (IBAction)selectIntelligence;
- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow;
- (void)checkScroll;
- (UIView *)makeFeedTitleBar:(NSDictionary *)feed cell:(UITableViewCell *)cell makeRect:(CGRect)rect;

- (IBAction)doOpenMarkReadActionSheet:(id)sender;
- (IBAction)doOpenSettingsActionSheet;
- (void)confirmDeleteSite;
- (void)deleteSite;
- (void)deleteFolder;
- (void)openMoveView;
- (void)showUserProfilePopover;
- (void)changeActiveFeedDetailRow;
- (void)changeRowStyleToRead:(UITableViewCell *)cell;
- (void)instafetchFeed;

- (void)loadFaviconsFromActiveFeed;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;

@end