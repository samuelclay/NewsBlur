//
//  FeedDetailTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NBSwipeableCell.h"

@interface FeedDetailTableCell : NBSwipeableCell {
    NewsBlurAppDelegate *appDelegate;
    
    // All views
    NSString *storyTitle;
    NSString *storyAuthor;
    NSString *storyDate;
    NSString *storyContent;
    NSString *storyImageUrl;
    UIImage *storyImage;
    NSInteger storyTimestamp;
    int storyScore;
    BOOL isSaved;
    BOOL isShared;
    BOOL inDashboard;
    
    // River view    
    NSString *siteTitle;
    UIImage *siteFavicon;
    BOOL isRead;
    BOOL isShort;
    BOOL isRiverOrSocial;
    BOOL hasAlpha;

    UIColor *feedColorBar;
    UIColor *feedColorBarTopBorder;
    UIView *cellContent;
}

@property (nonatomic) NSString *siteTitle;
@property (nonatomic) UIImage *siteFavicon;

@property (readwrite) int storyScore;
@property (nonatomic, readwrite) BOOL isSaved;
@property (readwrite) BOOL isShared;

@property (nonatomic) NSString *storyTitle;
@property (nonatomic) NSString *storyAuthor;
@property (nonatomic) NSString *storyDate;
@property (nonatomic) NSString *storyContent;
@property (nonatomic) NSString *storyImageUrl;
@property (nonatomic) UIImage *storyImage;
@property (nonatomic) NSInteger storyTimestamp;

@property (nonatomic) UIColor *feedColorBar;
@property (nonatomic) UIColor *feedColorBarTopBorder;

@property (readwrite) BOOL isRead;
@property (readwrite) BOOL isReadAvailable;
@property (readwrite) BOOL isShort;
@property (readwrite) BOOL isRiverOrSocial;
@property (readwrite) BOOL hasAlpha;
@property (readwrite) BOOL inDashboard;

- (void)setupGestures;

@end

@interface FeedDetailTableCellView : UIView {
    UIImage *storyImage;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) FeedDetailTableCell *cell;
@property (nonatomic) UIImage *storyImage;

@end