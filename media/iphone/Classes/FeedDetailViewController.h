//
//  FeedDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FeedDetailViewController : UIViewController 
<UITableViewDelegate, UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    
    NSArray * stories;
    NSMutableData * jsonString;
    int feedPage;
    BOOL pageFetching;
               
    UITableView * storyTitlesTable;
    UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    UIBarButtonItem * feedMarkReadButton;
}

- (void)fetchFeedDetail:(int)page;
- (void)scrollViewDidScroll:(UIScrollView *)scroll;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *storyTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * feedMarkReadButton;

@property (nonatomic, retain) NSArray * stories;
@property (nonatomic, retain) NSMutableData * jsonString;
@property (nonatomic, readwrite) int feedPage;
@property (nonatomic, readwrite) BOOL pageFetching;

@end
