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

@class NewsBlurAppDelegate;

@interface FeedDetailViewController : BaseViewController 
<UITableViewDelegate, UITableViewDataSource, 
 UIActionSheetDelegate, UIAlertViewDelegate> {
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
}

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

- (IBAction)doOpenMarkReadActionSheet:(id)sender;
- (IBAction)doOpenSettingsActionSheet;
- (void)confirmDeleteSite;
- (void)deleteSite;
- (void)deleteFolder;
- (void)openMoveView;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
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

@end