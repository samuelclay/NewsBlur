//
//  FeedTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "UnreadCountView.h"
#import "NBSwipeableCell.h"

@interface FeedTableCell : NBSwipeableCell {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *feedTitle;
    UIImage *feedFavicon;
    int _positiveCount;
    int _neutralCount;
    int _negativeCount;
    NSString *_negativeCountStr;
    BOOL isSocial;
    BOOL isSaved;
    UIView *cellContent;
    UnreadCountView *unreadCount;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *feedTitle;
@property (nonatomic) UIImage *feedFavicon;
@property (assign, nonatomic) int positiveCount;
@property (assign, nonatomic) int neutralCount;
@property (assign, nonatomic) int negativeCount;
@property (assign, nonatomic) int savedStoriesCount;
@property (assign, nonatomic) BOOL isSocial;
@property (assign, nonatomic) BOOL isSaved;
@property (nonatomic) NSString *negativeCountStr;
@property (nonatomic) UnreadCountView *unreadCount;

- (void)setupGestures;
- (void)redrawUnreadCounts;

@end

@interface FeedTableCellView : UIView

@property (nonatomic, weak) FeedTableCell *cell;

- (void)redrawUnreadCounts;

@end
