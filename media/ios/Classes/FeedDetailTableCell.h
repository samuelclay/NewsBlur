//
//  FeedDetailTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ABTableViewCell.h"

@interface FeedDetailTableCell : ABTableViewCell {
    NewsBlurAppDelegate *appDelegate;
    
    // All views
    NSString *storyTitle;
    NSString *storyAuthor;
    NSString *storyDate;
    int storyScore;
    
    // River view    
    NSString *siteTitle;
    UIImage *siteFavicon;
    BOOL isRead;
    BOOL isShort;
    BOOL isRiverOrSocial;
    BOOL hasAlpha;

    UIColor *feedColorBar;
    UIColor *feedColorBarTopBorder;
}

@property (nonatomic) NSString *siteTitle;
@property (nonatomic) UIImage *siteFavicon;

@property (readwrite) int storyScore;

@property (nonatomic) NSString *storyTitle;
@property (nonatomic) NSString *storyAuthor;
@property (nonatomic) NSString *storyDate;

@property (nonatomic) UIColor *feedColorBar;
@property (nonatomic) UIColor *feedColorBarTopBorder;

@property (readwrite) BOOL isRead;
@property (readwrite) BOOL isShort;
@property (readwrite) BOOL isRiverOrSocial;
@property (readwrite) BOOL hasAlpha;

- (UIImage *)imageByApplyingAlpha:(UIImage *)image withAlpha:(CGFloat) alpha;
    
@end
