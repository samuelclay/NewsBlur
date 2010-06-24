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
    
    NSMutableDictionary * activeFeed;         
    NSArray * stories;
    NSMutableString * jsonString;
               
    UITableView * storyTitlesTable;
    UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
}

- (void)fetchFeedDetail;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *storyTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;

@property (nonatomic, retain) NSArray * stories;
@property (nonatomic, readwrite, copy) NSMutableDictionary * activeFeed;
@property (nonatomic, retain) NSMutableString * jsonString;

@end
