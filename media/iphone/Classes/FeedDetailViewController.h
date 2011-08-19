//
//  FeedDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PullToRefreshView.h"

@class NewsBlurAppDelegate;

@interface FeedDetailViewController : UIViewController 
<UITableViewDelegate, UITableViewDataSource, PullToRefreshViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSArray * stories;
    NSMutableData * jsonString;
    int feedPage;
    BOOL pageFetching;
    BOOL pageFinished;
               
    UITableView * storyTitlesTable;
    UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    UIBarButtonItem * feedMarkReadButton;
    UISegmentedControl * intelligenceControl;
    PullToRefreshView *pull;
}

- (void)fetchFeedDetail:(int)page;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;
- (IBAction)markAllRead;
- (IBAction)selectIntelligence;
- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow;
- (void)checkScroll;
- (void)markedAsRead;
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view;
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *storyTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * feedMarkReadButton;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;
@property (nonatomic, retain) PullToRefreshView *pull;

@property (nonatomic, retain) NSArray * stories;
@property (nonatomic, retain) NSMutableData * jsonString;
@property (nonatomic, readwrite) int feedPage;
@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;

@end
